# Engine asset overrides

Files below `assets/fnf/` in this directory replace the corresponding engine
assets during `sync_engine.py`. Their paths are relative to the repository root.
The original assets on `main` remain unchanged for the private mod.

Overrides are read from the selected source commit, so commit them before
synchronizing. `characterList.txt` contains only bundled base characters;
`introText.txt` supplies neutral title-screen text.

The projection also excludes `assets/custom/oasis/` and `example_mods/` and
removes Oasis entries from mod activation and priority configuration. The private
sync workflow is omitted. The author's `READ IT OR IDK.md` note is included.

Normal synchronization preserves the target history. To prepare the first public
engine snapshot without any private source history, preview and then apply:

```sh
python3 tools/sync_engine.py --reset-history
python3 tools/sync_engine.py --reset-history --apply
```

This replaces only the local `engine` branch with one root commit. It preserves
`main`, the working files and the index, and never pushes. Existing remote branches
need a separate, intentional replacement. Subsequent normal synchronizations
append engine commits without bringing in the private source ancestry.
