# Oasis Engine release checklist

Use this checklist for each Oasis Engine release in
[kosziPL/oasis-engine](https://github.com/kosziPL/oasis-engine). Validate the exact candidate commit.
Historical results are in [BUILDING.md](BUILDING.md#validation-status).

## Source and release preparation

- [ ] Select and record the candidate commit in the official repository.
- [ ] Review build triggers, permissions, and tag-triggered release behavior.
- [ ] Confirm the intended draft/prerelease policy for this version; tag builds upload directly to a draft and publish a non-prerelease release only after all three platforms succeed.
- [ ] Inspect tracked source, docs, screenshots, examples, and workflows for inclusion in the release.
- [ ] Confirm the source contains no accidentally installed mods or stale activation/priority entries.
- [ ] Check documentation links and all five README screenshots.
- [ ] Preserve engine, upstream, and asset credits and license notices.
- [ ] Align `Project.xml`, the displayed engine version, documentation, and the planned tag.

## Build and package

- [ ] Build the candidate commit in a clean directory with fresh output and no locally installed mods.
- [ ] Verify fresh dependency setup; record Haxe/library versions, Git dependency revisions, and build logs.
- [ ] Build Windows, Linux, and macOS; state explicitly which platforms have passed runtime checks.
- [ ] Inspect extracted archives for the executable, required libraries, base assets, and appropriate launch permissions.
- [ ] Confirm the archive contains no development mod payload or stale assets from an earlier build.
- [ ] Start each archive outside the source tree on a clean machine; check Linux editor dialogs with `zenity` installed.

## Runtime validation

- [ ] Validate standalone base-game weeks; install a separate test mod and check enabling, disabling, and ordering.
- [ ] Start and finish a song, fail/retry, pause/resume, and return to Freeplay repeatedly.
- [ ] Check vocals, preview synchronization, seeking, playback speed, and remembered selection.
- [ ] Check sticker visual sizes, screen coverage, reveal/cover matching, and cleanup, including sparse silhouettes and custom sticker assets.
- [ ] Test extra opponents and players, Bot Notes, sustains, legacy chart normalization, and BPM changes.
- [ ] Save/reload chart edits and camera tracks, then play them in normal gameplay.
- [ ] Check split-screen transitions, camera zoom/tracking, and icon changes.
- [ ] Check character scripts, shared script paths, example events, and asset priority overrides.
- [ ] Test GPU caching off and on across the graphics hardware being supported.
- [ ] Check the 16 base achievements and 1000-FPS setting award, popups, persistence, and reset controls.

## Known limitations and release notes

- [ ] Resolve or clearly document the camera save/load path mismatch for this revision.
- [ ] Resolve or label the editor-only `gameOverChar`, `useCameraEditor`, and per-character `noteSkin` fields.
- [ ] Review [the feature audit](FEATURE_AUDIT.md) against the actual candidate; do not present historical checks as new results.
- [ ] Write engine release notes with changes, tested platforms, known issues, and migration instructions.
- [ ] Select the release tag and intended draft/prerelease status; confirm workflow behavior before pushing it.
- [ ] Publish source and platform archives in [Releases](https://github.com/kosziPL/oasis-engine/releases), then verify its README images, download links, and issue forms.

Release notes should identify the official commit/tag and provide enough
information for users to reproduce and report engine problems.
