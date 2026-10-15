> **Archived Oasis Engine development note.** Original wording is preserved below.
> The `v0.29` label, release statement, readiness claims, and known-issues list are
> historical notes, not evidence of a public release or current engine status.
> See [README](../../README.md), [the feature audit](../FEATURE_AUDIT.md), and
> [the release checklist](../RELEASE_CHECKLIST.md) for maintained documentation.

# 🌴 Oasis Engine - Dev Log v0.29
**Released on:** August 4th, 2026 | **Lead Dev:** KosziPL
---

# Mega optimizational update for Engine

### Added
- Fast Week Selector now looks readable! `SELECT WEEK` title is massive (64px) with a thick outline and renders on top of the weeks list.
- Dedicated "Metadata" tab in Charting State! Moved Authors, Game Over Character and Camera Custom Movements there so the Song tab is less cluttered.
- Sexy new `<` and `>` arrows on the sides of the screen in Freeplay to show that you can switch weeks (they hide dynamically if there's only 1 week).

### Changed
- Freeplay's "Press TAB to open faster week selector" hint now smoothly fades in and out only when you're in the actual song list (works exactly like the score text).

### Fixed

- Fixed old Psych Engine audio logic
- Fixed chart jumping
- Fixed Jkb's absolute dumpster fire of a Main Menu layout. Reverted back to the base engine's smooth scrolling but kept the sick left-anchored scaling (0.7 -> 0.85) without bouncy jumpy bullshit.
- Some Asset Handling things too
- Some stress null object fixes

### Known Issues

- (Hopefully nothing for now)

### To do
- Camera edittor stuff (just make UX better)

> WARNING: Engine could have unknown issues because I needed to rebuild a lot of legacy functionalities and add new stuff, so tell me if u find ANY problems (I'll try to fix it quick).

## Engine is kindly ready for the beta publish. I guess I don't have to fix or add something else because I'm done with this project. I want to do whatever else and close this door (of first version of this engine).
