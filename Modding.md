# Modding Oasis Engine

Oasis Engine is a standalone, experimental engine with a modified Psych Engine 0.6.3 content loader. This guide applies to engine builds and source from [the official Oasis Engine repository](https://github.com/kosziPL/oasis-engine). Install custom mods separately under `assets/custom/`.

## Install a mod

In an extracted engine build, create `assets/custom/<folder>/` and place the mod there. Copy its contents, not an extra enclosing archive folder. Installing a mod does not require rebuilding the engine.

```text
assets/custom/my-mod/
├── pack.json
├── weeks/
│   ├── weekList.txt
│   └── my-week.json
├── characters/
│   └── scripts/
├── data/my-song/
│   └── my-song.json
├── songs/my-song/
│   ├── Inst.ogg
│   └── Voices.ogg
├── stages/
├── images/
├── scripts/
├── custom_events/
└── custom_notetypes/
```

Only create directories your mod needs. The Mod menu manages ordering/enabling through `customList.txt` in the game root:

```text
my-mod|1
disabled-mod|0
```

The loader also discovers unlisted directories. Use `|0` to disable a mod. `pack.json` contains display metadata. A minimal example is shown below. The inherited `runsGlobally` flag participates in global asset resolution. Generic song scripts are scoped separately; a global asset override does not guarantee every script runs in every song.

Example `assets/custom/my-mod/pack.json`:

```json
{
  "name": "My Mod",
  "description": "An example mod for Oasis Engine.",
  "restart": false,
  "runsGlobally": false,
  "color": [80, 180, 160]
}
```

Start with this layout and the engine's editors. The archived `docs/modTemplate.zip` is an inherited template, not the current Oasis format reference. [TemplateScript.lua](docs/TemplateScript.lua) lists inherited Lua callbacks; verify callback behavior when migrating scripts.

## Asset resolution

[AssetHandler](source/AssetHandler.hx) resolves keys such as `images/example.png`:

1. In base-game context (no current mod), an existing `assets/fnf/` file wins first.
2. Otherwise, a matching entry in `assets/custom/priority.json` is tried.
3. The current mod is tried, then global mods.
4. Base FNF content and the OpenFL asset library provide fallbacks.

Example override:

```json
{
  "images/example.png": "my-mod"
}
```

This points to `assets/custom/my-mod/images/example.png`. It does not override an existing base-game file in base-game context.

`data/customPrefs.json` controls `load_tutorial`, `load_weeks`, `ignoreModWeekBlocks`, `default_note_asset_name`, and `title_tempo`. Week loading also checks `disable_base_game` in pack metadata, but currently only while adding unlisted mod directories. Do not rely on identical behavior for explicitly ordered mods.

## Chart and character extensions

Use the included Chart Editor to author Oasis charts.

| Field | Meaning |
| --- | --- |
| `song.extraChars` | Performers with `name`, `isPlayer`, `charID`, `isBelow`, `noteSkin`, `x`, and `y`. |
| `song.authors` | Author text shown with the song title. |
| `song.useCameraEditor` | Stored toggle; gameplay currently loads camera tracks without consulting it. |
| `song.gameOverChar` | Stored by the editor; currently not applied by gameplay. |
| Section `camFocus` | Character ID used for camera focus. |
| Character `addScript` | Lua script name resolved under `characters/scripts/`. |

In the runtime note loader, `floor(noteData / 4)` selects the character and `noteData % 4` selects the direction. IDs `0` and `1` refer to Dad and Boyfriend; additional performers start at `2`. This differs from Psych's section-dependent lane ownership. `normalizeOasisChart()` converts legacy lane order when `camFocus` is absent; test migrated charts, especially ones that already contain that field.

`extraChars.noteSkin` is saved by the editor but has no runtime reader. Character ownership is currently based on array order rather than a separately assigned `charID`.

`Bot Note` / `Bot Notes` trigger automatic performer animation. Extra performers still use four directions each; this is not a general configurable-key-count mode.

## Camera tracks and events

Open Camera Editor from the editor menu, select a song, and press **H** for help. Tracks contain a `camera_events` array. Fields include `step`, `target_type`, `target_id`, `is_relative`, `x`, `y`, `zoom`, `ease`, `duration`, `standalone`, and `lock_note_movement`.

**Current limitation:** `getCameraSavePath()` can write to the active mod's `data/<song>/camera.json`, while `getCameraPath()` checks `assets/custom/data/<song>/camera.json` and then `assets/data/<song>/camera.json`. Neither fallback uses `assets/fnf/data/`. Verify the actual load path before shipping a track; the save button alone does not establish that gameplay will load it.

| Built-in event | Values |
| --- | --- |
| `Change Icon` | Target (`bf`, `dad`, `playerX`, `opponentX`); icon name or visibility state. |
| `Show Extra Character` | Character ID; show/hide value. |
| `Toggle Split Screen` | `on` / `off`. |
| `Set Split Position` | Divider ratio (0–1); transition duration in seconds. |
| `Instant Cam Pos` | X and Y, applied immediately. |

`Change Character` uses Oasis targets: `0 = Dad`, `1 = Boyfriend`, `gf`, or an extra-character index. Check scripts using numeric Psych targets when migrating.

`Darken Screen` and `Ghost Trails` appear in the editor's event list but require Lua implementations in your mod's `custom_events/` directory. The engine does not bundle implementations of these events.

## Lua additions

In addition to the inherited Psych API, [FunkinLua](source/FunkinLua.hx) registers:

```lua
getCharacterNames()
setCameraPositionInstant(x, y, zoom)
setSmartCamera(enabled)
getSmartCamera()
setSmartCorners(enabled)
getSmartCorners()
setShaderColor(object, property, color)
```

Character scripts resolve their bound character through `itself` in property access. Reusing one script path for several performers currently rebinds the same loaded script; it does not create independent instances.

Lua's `version` global reports Oasis's version. Inherited HScript facilities should not be confused with a new standalone Oasis HScript mod loader.

## Generated files

The chart loader creates `.bson` caches beside JSON charts, rebuilding them when JSON is newer. Keep JSON as the editable source. Generated BSON files are ignored by Git. A BSON-only mod needs an explicit ignore exception if you intend to track those files.

The [feature audit](docs/FEATURE_AUDIT.md) records further compatibility limits and validation status.
