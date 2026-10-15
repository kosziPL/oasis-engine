# Contributing to Oasis Engine

[kosziPL/oasis-engine](https://github.com/kosziPL/oasis-engine) is the official
repository for Oasis Engine source, documentation, releases, and issue tracking.
Use its release tags to identify released versions and its default branch for
the latest available source.

## Get the source

```sh
git clone https://github.com/kosziPL/oasis-engine.git
cd oasis-engine
```

Follow [Building](BUILDING.md) to install dependencies and compile. To reproduce
a release, check out its tag first. Build output and local libraries are excluded
from version control.

## Report a problem

Open an [issue](https://github.com/kosziPL/oasis-engine/issues) using the relevant
form. Include the release tag or commit, operating system, reproduction steps,
expected behavior, and relevant logs. State which mods or source changes you use.
A minimal example helps distinguish an engine problem from a content problem.

Read the [known limitations](FEATURE_AUDIT.md#limitations-and-unfinished-work)
before reporting behavior already documented there. Feature requests should
explain a concrete use case and the desired behavior.

## Propose a change

1. Fork the official repository and create a branch from its current default branch.
2. Keep the change focused on one engine issue or improvement.
3. Update the relevant documentation when behavior, controls, or formats change.
4. Build the affected target and check the behavior you changed. Report what you
   tested and any remaining limitations.
5. Open a pull request against the official repository's default branch. Explain
   the problem, the resulting behavior, and validation results.

Keep generated files, build output, local libraries, and unrelated mod assets out
of the change. Preserve existing credits and license notices.

## Documentation changes

Keep README, [Modding](../Modding.md), [Building](BUILDING.md), and the
[feature audit](FEATURE_AUDIT.md) consistent with engine behavior. Use relative
links for files shipped with the source. Put screenshots in `docs/img/` and check
filename casing so they render on GitHub and case-sensitive systems.

Archive notes under `docs/history/` are historical references. Their version
labels and readiness claims do not replace the current documentation or release
notes.

## Releases and development builds

[Releases](https://github.com/kosziPL/oasis-engine/releases) contain tagged engine
versions and their available platform archives.
[Actions](https://github.com/kosziPL/oasis-engine/actions) shows build results and
available development artifacts. A passing compilation does not establish runtime
stability on every platform.

Maintainers validate each candidate with the [release checklist](RELEASE_CHECKLIST.md).
Release notes identify the tag, tested platforms, changes, known issues, and any
migration steps for existing mods.
