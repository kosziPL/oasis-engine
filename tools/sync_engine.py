#!/usr/bin/env python3
"""Project a committed Oasis branch onto engine without touching the worktree.

Preview by default; --apply advances the local branch, never pushes it.
Requires only Python's standard library and Git, not the game toolchain.
"""

import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile


MOD_PREFIX = b"assets/custom/oasis/"
EXCLUDED_PREFIXES = (MOD_PREFIX, b"example_mods/")
EXCLUDED_PATHS = {b"READ IT OR IDK.md", b".github/workflows/sync-engine.yml"}
OVERRIDES_PREFIX = b"tools/engine_overrides/assets/fnf/"
TRAILER = "Oasis-Source: "


def git(*args, data=None, env=None, check=True):
    return subprocess.run(
        ["git", *args], input=data, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, env=env, check=check,
    )


def revision(ref):
    return git("rev-parse", "--verify", ref + "^{commit}").stdout.decode().strip()


def projected_tree(source, legacy=False):
    # A private index leaves staged and unstaged user changes untouched.
    with tempfile.TemporaryDirectory(prefix="oasis-engine-") as directory:
        env = dict(os.environ, GIT_INDEX_FILE=str(Path(directory) / "index"))
        git("read-tree", source, env=env)
        paths = git("ls-files", "-z", env=env).stdout.split(b"\0")
        prefixes = (MOD_PREFIX,) if legacy else EXCLUDED_PREFIXES
        removed = [path for path in paths if
                   (not legacy and path in EXCLUDED_PATHS) or any(
                       path == prefix[:-1] or path.startswith(prefix) for prefix in prefixes)]
        if removed:
            git("update-index", "--force-remove", "-z", "--stdin",
                data=b"\0".join(removed) + b"\0", env=env)

        # Shared configuration can also contain other mods: retain their entries.
        for path in ("customList.txt", "assets/custom/priority.json"):
            if path.encode() not in paths:
                continue
            original = git("show", f"{source}:{path}").stdout
            if path.endswith(".json"):
                values = json.loads(original)
                if not isinstance(values, dict):
                    raise ValueError(f"{path} must contain a JSON object")
                filtered = {key: value for key, value in values.items() if value != "oasis"}
                if filtered == values:
                    continue
                content = (json.dumps(filtered, indent=2, ensure_ascii=False) + "\n").encode()
            else:
                content = b"".join(
                    line for line in original.splitlines(keepends=True)
                    if line.split(b"|", 1)[0].strip() != b"oasis"
                )
                if content == original:
                    continue
            oid = git("hash-object", "-w", "--stdin", data=content).stdout.decode().strip()
            git("update-index", "--add", "--cacheinfo", f"100644,{oid},{path}", env=env)

        if not legacy:
            # Overrides come from the selected commit, never local working files.
            # Mirror the destination path under tools/engine_overrides/.
            for path in paths:
                if not path.startswith(OVERRIDES_PREFIX):
                    continue
                target = "assets/fnf/" + path[len(OVERRIDES_PREFIX):].decode()
                oid = git("rev-parse", f"{source}:{path.decode()}").stdout.decode().strip()
                git("update-index", "--add", "--cacheinfo", f"100644,{oid},{target}", env=env)
        return git("write-tree", env=env).stdout.decode().strip()


def sync(source_ref, target, apply=False, reset_history=False):
    git("check-ref-format", "--branch", target)
    source = revision(source_ref)
    ref = "refs/heads/" + target
    result = git("rev-parse", "--verify", ref, check=False)
    previous = result.stdout.decode().strip() if result.returncode == 0 else None
    if source_ref == target or source_ref == ref or previous == source:
        raise ValueError("Source and target must be separate branches/revisions")

    if previous:
        message = git("show", "-s", "--format=%B", previous).stdout.decode()
        markers = [line[len(TRAILER):] for line in message.splitlines() if line.startswith(TRAILER)]
        if markers:
            last_source = revision(markers[-1])
            if git("merge-base", "--is-ancestor", last_source, source, check=False).returncode:
                raise ValueError("Source history was rewritten or is older than the last sync")
            old_tree = git("rev-parse", previous + "^{tree}").stdout.decode().strip()
            if (old_tree != projected_tree(last_source)
                    and old_tree != projected_tree(last_source, legacy=True)):
                raise ValueError("Engine has independent changes; move them to main before syncing")
        elif git("merge-base", "--is-ancestor", previous, source, check=False).returncode:
            raise ValueError("Engine has independent history; merge its fixes into main first")

    tree = projected_tree(source)
    if (previous and not reset_history
            and git("rev-parse", previous + "^{tree}").stdout.decode().strip() == tree):
        print("Engine is already up to date; no engine commit needed.")
        return False

    if previous:
        print(git("diff", "--stat", previous, tree).stdout.decode(), end="")
    else:
        print(f"Create {target} from {source_ref}, excluding Oasis content and mod examples.")
    if reset_history:
        print(f"Replace {target} history with a single root commit, without source history.")
    if not apply:
        print("Preview only. Use --apply to update the local engine branch.")
        return True

    worktrees = git("worktree", "list", "--porcelain", "-z").stdout.split(b"\0")
    if ("branch " + ref).encode() in worktrees:
        raise ValueError("Engine is checked out in a worktree; refusing to move its branch")
    subject = "initial standalone engine snapshot" if reset_history else f"shared changes from {source[:12]}"
    message = f"sync(engine): {subject}\n\n{TRAILER}{source}\n"
    parents = ["-p", previous] if previous and not reset_history else []
    commit = git("commit-tree", tree, *parents, data=message.encode()).stdout.decode().strip()
    # Compare-and-swap: a concurrent edit can never be overwritten.
    git("update-ref", "-m", "sync engine from Oasis", ref, commit,
        previous or ("0" * len(source)))
    print(f"Updated {target} to {commit[:12]}. Nothing was pushed.")
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default="main")
    parser.add_argument("--target", default="engine")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--reset-history", action="store_true",
                        help="replace the target history with a single root commit (preview unless --apply)")
    args = parser.parse_args()
    try:
        changed = sync(args.source, args.target, args.apply, args.reset_history)
        if os.environ.get("GITHUB_OUTPUT"):
            with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
                output.write(f"changed={str(changed).lower()}\n")
    except (subprocess.CalledProcessError, ValueError) as error:
        detail = error.stderr.decode(errors="replace") if isinstance(error, subprocess.CalledProcessError) else str(error)
        parser.exit(1, f"Sync stopped: {detail}\n")


if __name__ == "__main__":
    main()
