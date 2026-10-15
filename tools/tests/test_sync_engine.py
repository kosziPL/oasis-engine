"""Exercise real Git repositories, without accessing the project's Git state."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "sync_engine.py"


class SyncEngineTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = dict(os.environ)
        for key in list(self.env):
            if key.startswith("GIT_") or key == "GITHUB_OUTPUT":
                del self.env[key]
        self.env.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
        self.git("init", "-b", "main")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.invalid")
        self.write("source/Main.hx", "engine v1\n")
        self.write("assets/custom/priority.json", '{"music/menu.ogg":"oasis","image.png":"other"}\n')
        self.write("customList.txt", "oasis|1\nother|1\n")
        self.commit("base")
        self.git("branch", "engine")
        self.write("assets/custom/oasis/song.bin", b"\0oasis\xff")
        self.write("assets/custom/other/song.bin", b"\0other\xff")
        self.commit("add mods")

    def run_command(self, *args, check=True):
        return subprocess.run(args, cwd=self.root, env=self.env, check=check,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    def git(self, *args):
        return self.run_command("git", *args).stdout

    def write(self, name, content):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content.encode() if isinstance(content, str) else content)

    def commit(self, message):
        self.git("add", "-A")
        self.git("commit", "-m", message)

    def sync(self, *args, check=True):
        import sys
        return self.run_command(sys.executable, str(SCRIPT), *args, check=check)

    def test_initial_sync_filters_only_oasis_and_keeps_history(self):
        previous = self.git("rev-parse", "engine").strip()
        main = self.git("rev-parse", "main")
        self.sync("--apply")
        self.assertEqual(self.git("rev-parse", "engine^").strip(), previous)
        self.assertEqual(self.git("rev-parse", "main"), main)
        self.assertEqual(self.git("ls-tree", "-r", "--name-only", "engine", "assets/custom/oasis"), b"")
        self.assertEqual(self.git("show", "engine:assets/custom/other/song.bin"), b"\0other\xff")
        self.assertEqual(self.git("show", "engine:customList.txt"), b"other|1\n")
        self.assertNotIn(b"oasis", self.git("show", "engine:assets/custom/priority.json"))
        self.assertIn(b"other", self.git("show", "engine:assets/custom/priority.json"))

    def test_mod_only_commit_does_not_create_engine_commit(self):
        self.sync("--apply")
        before = self.git("rev-parse", "engine")
        self.write("assets/custom/oasis/song.bin", b"new mod content")
        self.commit("mod only")
        self.sync("--apply")
        self.assertEqual(self.git("rev-parse", "engine"), before)

    def add_engine_overrides(self):
        self.write("assets/fnf/data/characterList.txt", "koszi\nfaslo\n")
        self.write("assets/fnf/data/introText.txt", "private--mod\n")
        self.write("tools/engine_overrides/README.md", "Override documentation\n")
        self.write("tools/engine_overrides/assets/fnf/data/characterList.txt", "bf\ndad\n")
        self.write("tools/engine_overrides/assets/fnf/data/introText.txt", "public--engine\n")
        self.write("example_mods/images/private.png", b"private artwork")
        self.commit("add public engine defaults and private examples")

    def test_examples_are_excluded_and_overrides_leave_main_unchanged(self):
        self.add_engine_overrides()
        self.sync("--apply")
        self.assertEqual(self.git("ls-tree", "-r", "--name-only", "engine", "example_mods"), b"")
        self.assertEqual(self.git("show", "engine:assets/fnf/data/characterList.txt"), b"bf\ndad\n")
        self.assertEqual(self.git("show", "engine:assets/fnf/data/introText.txt"), b"public--engine\n")
        self.assertEqual((self.root / "assets/fnf/data/characterList.txt").read_text(), "koszi\nfaslo\n")
        self.assertEqual((self.root / "assets/fnf/data/introText.txt").read_text(), "private--mod\n")
        self.assertEqual((self.root / "example_mods/images/private.png").read_bytes(), b"private artwork")

    def test_private_data_changes_do_not_create_engine_commit(self):
        self.add_engine_overrides()
        self.sync("--apply")
        before = self.git("rev-parse", "engine")
        self.write("assets/fnf/data/characterList.txt", "new-private-character\n")
        self.write("assets/fnf/data/introText.txt", "different--private\n")
        self.write("example_mods/images/private.png", b"changed artwork")
        self.commit("private data changes")
        self.sync("--apply")
        self.assertEqual(self.git("rev-parse", "engine"), before)

    def test_overrides_use_committed_source_and_support_new_assets(self):
        self.add_engine_overrides()
        self.write("tools/engine_overrides/assets/fnf/data/new-default.txt", "bundled default\n")
        self.commit("new engine asset")
        self.write("tools/engine_overrides/assets/fnf/data/introText.txt", "uncommitted--override\n")
        self.sync("--apply")
        self.assertEqual(self.git("show", "engine:assets/fnf/data/introText.txt"), b"public--engine\n")
        self.assertEqual(self.git("show", "engine:assets/fnf/data/new-default.txt"), b"bundled default\n")

    def test_committed_override_updates_reach_engine(self):
        self.add_engine_overrides()
        self.sync("--apply")
        self.write("tools/engine_overrides/assets/fnf/data/characterList.txt", "bf\ndad\ngf\n")
        self.commit("update public character defaults")
        self.sync("--apply")
        self.assertEqual(self.git("show", "engine:assets/fnf/data/characterList.txt"), b"bf\ndad\ngf\n")

    def test_private_workflow_is_omitted_but_author_note_is_published(self):
        self.write(".github/workflows/sync-engine.yml", "private workflow\n")
        self.write("READ IT OR IDK.md", "important author note\n")
        self.write(".github/workflows/main.yml", "shared build workflow\n")
        self.commit("repository metadata")
        self.sync("--apply")
        files = self.git("ls-tree", "-r", "--name-only", "engine")
        self.assertNotIn(b".github/workflows/sync-engine.yml", files)
        self.assertIn(b"READ IT OR IDK.md", files)
        self.assertEqual(self.git("show", "engine:READ IT OR IDK.md"), b"important author note\n")
        self.assertIn(b".github/workflows/main.yml", files)

    def test_sync_restores_note_from_previously_filtered_snapshot(self):
        self.write("READ IT OR IDK.md", "important author note\n")
        self.commit("author note")
        source = self.git("rev-parse", "main").decode().strip()
        self.sync("--apply")
        self.git("checkout", "engine")
        self.git("rm", "READ IT OR IDK.md")
        self.commit("previous projection without note\n\nOasis-Source: " + source)
        previous = self.git("rev-parse", "engine").strip()
        self.git("checkout", "main")
        self.sync("--apply")
        self.assertEqual(self.git("rev-parse", "engine^").strip(), previous)
        self.assertEqual(self.git("show", "engine:READ IT OR IDK.md"), b"important author note\n")

    def test_reset_history_is_preview_only_without_apply(self):
        self.sync("--apply")
        before = self.git("rev-parse", "engine")
        result = self.sync("--reset-history")
        self.assertEqual(self.git("rev-parse", "engine"), before)
        self.assertIn(b"single root commit", result.stdout)

    def test_reset_history_removes_mod_ancestry_and_preserves_source_and_edits(self):
        self.add_engine_overrides()
        self.git("branch", "-f", "engine", "main")
        self.write("source/Main.hx", "shared engine update\n")
        self.commit("shared update after the old engine branch")
        self.sync("--apply")
        before = self.git("rev-parse", "main")
        self.assertIn(b"assets/custom/oasis/song.bin", self.git("rev-list", "--objects", "engine"))
        self.write("source/Main.hx", "staged edit\n")
        self.git("add", "source/Main.hx")
        self.write("source/Main.hx", "unstaged edit\n")
        status = self.git("status", "--porcelain=v1")
        staged = self.git("diff", "--cached", "--binary")
        self.sync("--reset-history", "--apply")
        self.assertEqual(self.git("rev-list", "--count", "engine").strip(), b"1")
        self.assertEqual(self.git("rev-list", "--parents", "engine").split(), [self.git("rev-parse", "engine").strip()])
        self.assertNotIn(b"assets/custom/oasis/song.bin", self.git("rev-list", "--objects", "engine"))
        self.assertEqual(self.git("rev-parse", "main"), before)
        self.assertEqual(self.git("status", "--porcelain=v1"), status)
        self.assertEqual(self.git("diff", "--cached", "--binary"), staged)
        self.assertEqual(self.git("show", "engine:assets/fnf/data/characterList.txt"), b"bf\ndad\n")

    def test_normal_sync_after_reset_keeps_source_ancestry_private(self):
        self.add_engine_overrides()
        self.sync("--reset-history", "--apply")
        root = self.git("rev-parse", "engine").strip()
        self.write("source/Main.hx", "engine v2\n")
        self.write("assets/custom/oasis/song.bin", b"new private song")
        self.commit("mixed future update")
        self.sync("--apply")
        self.assertEqual(self.git("rev-parse", "engine^").strip(), root)
        self.assertEqual(self.git("rev-list", "--count", "engine").strip(), b"2")
        self.assertNotIn(b"assets/custom/oasis/song.bin", self.git("rev-list", "--objects", "engine"))
        self.assertEqual(self.git("show", "engine:source/Main.hx"), b"engine v2\n")

    def test_reset_history_cannot_move_checked_out_target(self):
        self.git("worktree", "add", str(self.root / "engine-worktree"), "engine")
        before = self.git("rev-parse", "engine")
        result = self.sync("--reset-history", "--apply", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"checked out", result.stderr)
        self.assertEqual(self.git("rev-parse", "engine"), before)

    def test_legacy_projection_migrates_without_rewriting_history(self):
        self.add_engine_overrides()
        source = self.git("rev-parse", "main").decode().strip()
        self.git("checkout", "-B", "engine", "main")
        self.git("rm", "-r", "assets/custom/oasis")
        self.write("customList.txt", "other|1\n")
        self.write("assets/custom/priority.json", '{\n  "image.png": "other"\n}\n')
        self.commit("old synchronization\n\nOasis-Source: " + source)
        previous = self.git("rev-parse", "engine").strip()
        self.git("checkout", "main")
        self.sync("--apply")
        self.assertEqual(self.git("rev-parse", "engine^").strip(), previous)
        self.assertEqual(self.git("ls-tree", "-r", "--name-only", "engine", "example_mods"), b"")
        self.assertEqual(self.git("show", "engine:assets/fnf/data/characterList.txt"), b"bf\ndad\n")

    def test_independent_changes_with_sync_marker_are_rejected(self):
        self.add_engine_overrides()
        self.sync("--apply")
        source = self.git("rev-parse", "main").decode().strip()
        self.git("checkout", "engine")
        self.write("source/Main.hx", "independent engine change\n")
        self.commit("independent edit\n\nOasis-Source: " + source)
        self.git("checkout", "main")
        before = self.git("rev-parse", "engine")
        result = self.sync("--apply", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"independent changes", result.stderr)
        self.assertEqual(self.git("rev-parse", "engine"), before)

    def test_mixed_commit_and_deletions(self):
        self.sync("--apply")
        self.git("mv", "source/Main.hx", "source/Renamed.hx")
        self.write("assets/custom/oasis/another.bin", b"mod only")
        self.git("rm", "assets/custom/other/song.bin")
        self.commit("mixed rename and deletion")
        self.sync("--apply")
        files = self.git("ls-tree", "-r", "--name-only", "engine")
        self.assertIn(b"source/Renamed.hx", files)
        self.assertNotIn(b"source/Main.hx", files)
        self.assertNotIn(b"assets/custom/other/song.bin", files)
        self.assertNotIn(b"assets/custom/oasis", files)

    def test_preview_and_apply_preserve_dirty_worktree_and_index(self):
        self.write("source/Main.hx", "staged edit")
        self.git("add", "source/Main.hx")
        self.write("source/Main.hx", "unstaged edit")
        self.write("untracked.txt", "keep me")
        status = self.git("status", "--porcelain=v1")
        staged = self.git("diff", "--cached", "--binary")
        before = self.git("rev-parse", "engine")
        self.sync()
        self.assertEqual(self.git("rev-parse", "engine"), before)
        self.sync("--apply")
        self.assertEqual(self.git("status", "--porcelain=v1"), status)
        self.assertEqual(self.git("diff", "--cached", "--binary"), staged)
        self.assertEqual((self.root / "source/Main.hx").read_text(), "unstaged edit")
        self.assertEqual(self.git("show", "engine:source/Main.hx"), b"engine v1\n")

    def test_renaming_across_mod_boundary(self):
        self.sync("--apply")
        self.git("mv", "assets/custom/oasis/song.bin", "source/promoted.bin")
        self.git("mv", "source/Main.hx", "assets/custom/oasis/private.hx")
        self.commit("move files across scope boundary")
        self.sync("--apply")
        files = self.git("ls-tree", "-r", "--name-only", "engine")
        self.assertIn(b"source/promoted.bin", files)
        self.assertNotIn(b"source/Main.hx", files)
        self.assertNotIn(b"assets/custom/oasis", files)
        self.assertEqual(self.git("show", "engine:source/promoted.bin"), b"\0oasis\xff")

    def test_independent_engine_edit_is_not_overwritten(self):
        self.sync("--apply")
        self.git("checkout", "engine")
        self.write("source/Main.hx", "engine-only fix")
        self.commit("independent fix")
        self.git("checkout", "main")
        before = self.git("rev-parse", "engine")
        result = self.sync("--apply", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"independent history", result.stderr)
        self.assertEqual(self.git("rev-parse", "engine"), before)

    def test_checked_out_engine_is_not_moved(self):
        self.git("worktree", "add", str(self.root / "engine-worktree"), "engine")
        before = self.git("rev-parse", "engine")
        result = self.sync("--apply", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"checked out", result.stderr)
        self.assertEqual(self.git("rev-parse", "engine"), before)

    def test_stale_source_is_rejected(self):
        self.sync("--apply")
        before = self.git("rev-parse", "engine")
        result = self.sync("--source", "main~1", "--apply", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"older", result.stderr)
        self.assertEqual(self.git("rev-parse", "engine"), before)

    def test_new_target_and_repeated_sync(self):
        self.sync("--target", "engine-new", "--apply")
        before = self.git("rev-parse", "engine-new")
        self.sync("--target", "engine-new", "--apply")
        self.assertEqual(self.git("rev-parse", "engine-new"), before)


if __name__ == "__main__":
    unittest.main()
