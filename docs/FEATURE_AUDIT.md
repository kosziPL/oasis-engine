# Oasis Engine feature audit against Psych Engine 0.6.3

Source audit recorded on **2026-09-10**. Documentation updated on **2026-09-14**.

Oasis Engine is a standalone experimental engine. Its official source,
documentation, releases, and issue tracker are maintained at
[kosziPL/oasis-engine](https://github.com/kosziPL/oasis-engine). This audit describes engine additions and known
implementation limits compared with Psych Engine 0.6.3.

## Scope and baseline

The upstream baseline is the [official Psych Engine 0.6.3 release](https://github.com/ShadowMario/FNF-PsychEngine/releases/tag/0.6.3).
Relative source links point to the files accompanying this document. Feature
statuses come from source inspection unless a runtime or build check is explicitly
recorded. Review them against the exact engine version you use; they are not a
certification of every release.

## Feature inventory

“Added” means code beyond the chosen upstream tag; “Changed” includes extensions of upstream behavior. “Partial” identifies editor data or unfinished integration. All statuses are **static code verification**, not interactive acceptance-test passes. The rows group related changes and are not a claim that every line difference is a separate feature.

### Menus and navigation

| Feature | Comparison | Implementation and scope |
| --- | --- | --- |
| Main-menu layout and per-entry colors | Changed | [MainMenuState.hx](../source/MainMenuState.hx) — Oasis menu composition and navigation. |
| Freeplay categories | Added | [WeekData.hx](../source/WeekData.hx) — Category metadata and a separate category-selection screen. |
| Quick week selector | Added | [FreeplayWeekSubstate.hx](../source/FreeplayWeekSubstate.hx) — Tab opens direct week selection; Freeplay also supports adjacent-week navigation. |
| Audio preview controls | Changed | [FreeplayState.hx](../source/FreeplayState.hx) — Instrumental/vocal preview, speed changes and five-second seeking; basic preview already existed upstream. |
| Chart-based difficulty discovery | Added | [CoolUtil.hx](../source/CoolUtil.hx) — Discover available song charts instead of offering only fixed difficulty names. |
| Remembered Freeplay selection | Added | [ClientPrefs.hx](../source/ClientPrefs.hx) — Remember week and song selection within the running session; these fields are not persisted by saveSettings(). |
| Sticker transitions | Added | [StickersFadeTransition.hx](../source/StickersFadeTransition.hx) — Custom transition used when returning between gameplay and Freeplay. |
| Pause presentation | Changed | [PauseSubState.hx](../source/PauseSubState.hx) — Different pause music/presentation; pause, retry and practice are inherited. |

### Characters and charting

| Feature | Comparison | Implementation and scope |
| --- | --- | --- |
| Native extra performers | Added | [Song.hx](../source/Song.hx) — Extra-character data, runtime groups, side ownership and positions; four directions per performer. |
| Character lanes and dynamic editor columns | Added | [editors/ChartingState.hx](../source/editors/ChartingState.hx) — Characters tab, dynamic lane count and logical/visual column mapping. |
| Legacy lane conversion | Added | [PlayState.hx](../source/PlayState.hx) — Converts old section-relative lanes when camFocus is absent; current lanes encode character IDs. |
| Bot Notes | Added | [Note.hx](../source/Note.hx) — Automatic/invisible note type for performer animations. |
| Character previews and focus indicator | Added | [editors/ChartingState.hx](../source/editors/ChartingState.hx) — Animated chart-editor previews and section-focus display. |
| Multi-note selection, drag and clipboard | Added | [editors/ChartingState.hx](../source/editors/ChartingState.hx) — Selection rectangles, moving multiple notes, copy/cut/paste. |
| Undo snapshots | Added | [editors/ChartingState.hx](../source/editors/ChartingState.hx) — Note-edit undo history; a declared redos array does not establish functional redo. |
| Selected-character section swapping | Changed | [editors/ChartingState.hx](../source/editors/ChartingState.hx) — Extends upstream section swapping to chosen character lanes; duet/mirror/section copy are inherited. |
| Playtest speed | Changed | [editors/ChartingState.hx](../source/editors/ChartingState.hx) — Editor playtest playback-rate control; general playback rate already existed in Psych. |
| Author metadata | Added | [Song.hx](../source/Song.hx) — Author field is edited in Metadata and displayed alongside the song title. |
| Additional editor-only fields | Partial | [Song.hx](../source/Song.hx) — gameOverChar, useCameraEditor and extraChars.noteSkin are saved, but have no gameplay readers. |
| Character Lua attachment | Added | [Character.hx](../source/Character.hx) — Character editor saves addScript; runtime loads characters/scripts and binds the itself alias. |
| Linux editor save dialogs | Changed | [editors/ChartingState.hx](../source/editors/ChartingState.hx) — Chart, character, week and dialogue editors launch zenity on Linux. |

### Camera and gameplay

| Feature | Comparison | Implementation and scope |
| --- | --- | --- |
| Camera editor and song selector | Added; limited | [editors/CameraEditorState.hx](../source/editors/CameraEditorState.hx) — Timeline/inspector, playback, seeking, dragging, capture, help, save and legacy event import; path mismatch remains. |
| Camera-event schema and playback | Added; limited | [PlayState.hx](../source/PlayState.hx) — Step-based targets, relative/absolute positions, zoom, easing, duration, standalone control and movement locking. |
| Section camera focus | Added | [Section.hx](../source/Section.hx) — Explicit character ID rather than only mustHitSection. |
| Note-reactive camera controls | Added | [ClientPrefs.hx](../source/ClientPrefs.hx) — Configurable hit movement and strength; smart tracking controls are available through Lua. |
| Expanded camera clipping | Added | [SmartCamera.hx](../source/SmartCamera.hx) — Scroll-rectangle handling for zoomed cameras; split cameras disable smart clipping. |
| Split-screen cameras | Added | [PlayState.hx](../source/PlayState.hx) — Separate Dad/Boyfriend views with animated activation and divider position. |
| Instant camera position | Added | [PlayState.hx](../source/PlayState.hx) — Immediate position event plus Lua callback. |
| Icon and performer visibility events | Added | [PlayState.hx](../source/PlayState.hx) — Change Icon and Show Extra Character; Change Character also extends numeric targeting. |
| Marvelous judgement | Added | [PlayState.hx](../source/PlayState.hx) — 20 ms window, 500 points and judgement counter. |
| Oasis HUD and combo placement | Added | [ClientPrefs.hx](../source/ClientPrefs.hx) — Layout selection, rating counters and game/HUD-camera combo positioning. |
| Multiple/winning health icons | Added | [HealthIcon.hx](../source/HealthIcon.hx) — Three-frame icon detection; runtime maintains player/opponent icon arrays. |
| Achievement reset UI | Added | [AchievementResettingSubState.hx](../source/AchievementResettingSubState.hx) — Reset one achievement or all, with confirmation. |
| Base achievements and engine bonus | Changed | [Achievements.hx](../source/Achievements.hx) — The current engine uses the 16 base FNF/Psych awards plus an independent award for selecting 1000 FPS. |
| 1000 FPS option limit | Changed | [options/GraphicsSettingsSubState.hx](../source/options/GraphicsSettingsSubState.hx) — Raises the configurable cap and awards exaggerated when the setting reaches 1000 FPS. This rewards the setting, not measured attainable FPS. |
| Song error recovery screen | Added | [GameCrashState.hx](../source/GameCrashState.hx) — Caught song errors offer Freeplay/Chart Editor recovery; not a universal native-crash recovery system. |

### Content and scripting

| Feature | Comparison | Implementation and scope |
| --- | --- | --- |
| Central asset resolver and priority overrides | Added | [AssetHandler.hx](../source/AssetHandler.hx) — priority.json, current/global mod fallback and assets/fnf; existing base assets win in base context. |
| Custom base-content preferences | Added | [CustomPrefs.hx](../source/CustomPrefs.hx) — Tutorial/weeks, mod week blocking, note asset name and title tempo. |
| Mod-specific window and Discord metadata | Added | [TitleState.hx](../source/TitleState.hx) — pack.json window_name and discord_rpc fields; Discord Rich Presence itself is inherited. |
| Lua source cache | Added | [FunkinLua.hx](../source/FunkinLua.hx) — Caches source text by path and loads it through LuaL.dostring. |
| Seven Lua callbacks | Added | [FunkinLua.hx](../source/FunkinLua.hx) — getCharacterNames, setShaderColor, setCameraPositionInstant, set/getSmartCamera, set/getSmartCorners. |

### Loading and internals

| Feature | Comparison | Implementation and scope |
| --- | --- | --- |
| Background asset preloading | Added | [AsyncAssetPreloader.hx](../source/AsyncAssetPreloader.hx) — Up to four workers read/decode queued sound/graphic jobs; main-thread dispatcher installs results. |
| Incremental note creation | Added | [DynamicStreamLoader.hx](../source/DynamicStreamLoader.hx) — Initially processes up to eight sections; worker schedules chunks of two, looking about fifteen sections ahead. |
| BSON chart cache | Added | [ChartBSONHandler.hx](../source/ChartBSONHandler.hx) — Timestamp-based cache rebuild, JSON fallback, and BSON-only load path. |
| Optional GPU texture caching | Added | [AssetHandler.hx](../source/AssetHandler.hx) — Optional texture upload/bitmap handling; disabled by default, hardware-sensitive. |
| Asset retention and cleanup | Changed | [Paths.hx](../source/Paths.hx) — Core-asset retention list and revised disposal around state changes. |
| Vanilla stage logic extraction | Refactor | [VanillaWeekHandler.hx](../source/VanillaWeekHandler.hx) — Moves base-week behavior out of PlayState; it does not add new official FNF weeks. |
| Dialogue audio reuse | Changed | [TypedAlphabet.hx](../source/TypedAlphabet.hx) — Reuses a sound object for typed dialogue and cleans it up. |

## Inherited features and examples

Lua scripting, HScript `runHaxeCode` facilities, Story Mode, the base FNF weeks, gameplay modifiers, rebinding, shaders, achievements, the core character/week/dialogue editors, waveform previews, metronome, and basic Discord Rich Presence already exist in Psych 0.6.3. Oasis changes some implementations but should not advertise their mere presence as newly invented features.

`Darken Screen` and `Ghost Trails` have dropdown entries but no bundled Lua implementations. They require scripts supplied by the mod and are not new built-in `PlayState` event cases.

## Limitations and unfinished work

These findings come from source inspection unless a build result is explicitly stated.

1. **Camera save/load mismatch.** [PlayState](../source/PlayState.hx), `getCameraSavePath()` and `getCameraPath()`, disagree about active-mod paths. Loading checks `assets/custom/data/<song>/camera.json`, then legacy `assets/data/<song>/camera.json`; saving can select `assets/custom/<current-mod>/data/<song>/camera.json`. The fallback also bypasses `assets/fnf/`. Camera Editor exists and runs through the menu, but saved-track portability is not certified.
2. **Editor fields without runtime consumers.** `song.gameOverChar`, `song.useCameraEditor`, and `extraChars.noteSkin` are serialized by the editor but are not read by gameplay. The camera-track loader does not honor that toggle. Runtime character IDs follow array order rather than the optional stored `charID`.
3. **Shared character scripts.** `characterScripts()` deduplicates by full script path and reassigns the bound character. Two performers using one script do not get independent instances. The property alias is `itself`.
4. **Base-game disabling depends on discovery order.** [WeekData](../source/WeekData.hx) checks `disable_base_game` while adding previously unlisted mod directories. Explicitly ordered mods can bypass that check. Custom base-week preferences are a separate mechanism.
5. **Achievement mismatch resolved in the current tree.** Restored the upstream 16-award list, end-of-song candidates, Friday-night unlock, and retained the upstream week/rating/performance conditions and live oversinging/henchmen hooks. Removed index-based mod-week awards; retained the independent 1000-FPS unlock. Interactive popup/persistence checks remain outstanding.
6. **Platform coverage.** Several source paths directly use `sys` and threads. XML sections for web/mobile/Switch are not evidence of supported release targets. Linux editor saving directly invokes `zenity`. Windows/macOS CI jobs exist but were not run in the historical audit.
7. **Upstream update checker is dormant, not migrated.** `CHECK_FOR_UPDATES` is not enabled in `Project.xml`. Its guarded code still requests upstream Psych's version and references the removed `psychEngineVersion` field. Enabling that flag needs follow-up work; it is not an Oasis updater.
8. **GPU caching is opt-in.** The option itself warns about hardware-dependent flashing. No VRAM/RAM savings or compatibility guarantee was measured.
9. **Stage Editor.** The engine does not ship a Stage Editor. The earlier incomplete stub was removed.
10. **No complete dependency lock.** The Git-sourced Lua/Discord/HScript dependencies remain unpinned. Numeric BSON version is now fixed to the locally installed `0.1.0`; this alone does not make all builds reproducible.

These limitations require review for each release candidate, even when compilation succeeds.

## Performance measurements

No paired runtime benchmarks were performed. FPS, frame-time percentiles, peak RSS, VRAM, loading latency and audio drift are **not measured**, and no speed-up percentage is claimed. Counting source lines or seeing an asynchronous class does not demonstrate a performance improvement.

The following code-level parameters were verified:

| Mechanism | Observed parameter | What remains to measure |
| --- | --- | --- |
| Async asset preloader | Up to 4 workers | Cold/warm load time and peak memory on the same assets. |
| Note streaming | Up to 8 initial sections; chunks of 2; roughly 15-section lookahead | Frame-time spikes, dense-chart memory and seek/BPM correctness. |
| BSON caching | Rebuild when cache is missing or not newer than JSON | First-load conversion cost versus subsequent load latency. |
| GPU caching | Off by default | RSS/VRAM tradeoff, context loss and texture correctness. |
| Frame-rate option | Upper setting 1000 FPS | Delivered frame rate and frame-time stability. |
| Marvelous judgement | 20 ms window; 500 points | Input/audio timing behavior under real playback. |

A useful follow-up benchmark should use the same machine, graphics settings, base charts, audio files and difficulty on both engines. Separate cold and warm runs, repeat runs, record median and tail frame time, and keep Oasis-only feature tests separate from comparable upstream charts. Use the [release checklist](RELEASE_CHECKLIST.md) for functional checks first.

## Validation

The Linux release target compiled and linked with local dependencies; the audited build included local working-tree changes. The pre-existing debug target failed native linking with undefined references after successful Haxe generation. Windows/macOS, fresh dependency installation, GUI behavior and performance remain unverified. See [BUILDING.md](BUILDING.md#validation-status).

Repository checks cover XML parsing, local documentation links, shell syntax, source-version consistency, preservation of user edits, and reproducibility of the source inventory. After restoring the base achievements, 52 Haxe-interpreter cases exercised the actual unlock predicates with stubbed engine state, including Friday-night boundary conditions. The 16 base definitions match upstream; the 1000-FPS bonus uses the base toaster icon under its own asset name. All award icons are present, and the standalone output contains no mod payload or mod-specific activation list. None is a substitute for playing the build.
