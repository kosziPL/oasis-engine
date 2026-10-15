# Building Oasis Engine

Run commands from the Oasis Engine source root. `Project.xml` is the build entry point.
Clone [the official repository](https://github.com/kosziPL/oasis-engine):

```sh
git clone https://github.com/kosziPL/oasis-engine.git
cd oasis-engine
```

To reproduce a release, check out its tag before installing dependencies and
building. Otherwise, the clone uses the repository's default branch.


## Toolchain

Use Haxe **4.2.5**, Neko, Git, and a native C++ toolchain. The project's `.haxerc` selects Haxe 4.2.5 for lix users. Native haxelib installations must select it separately.

| Dependency | Project/CI version |
| --- | --- |
| hxcpp | 4.3.2 |
| Lime | 7.9.0 |
| OpenFL | 9.2.1 |
| HaxeFlixel | 4.11.0 |
| flixel-addons | 2.11.0 |
| flixel-ui | 2.4.0 |
| hscript | 2.5.0 |
| tjson | 1.4.0 |
| hxjsonast | 1.1.0 |
| BSON | 0.1.0 |
| hxCodec | 2.5.1 |
| linc_luajit | Git: `superpowers04/linc_luajit` |
| hscript-ex | Git: `ianharrigan/hscript-ex` |
| discord_rpc | Git: `Aidan63/linc_discord-rpc`, including submodules |

Git dependencies are not pinned to commits. The existing npm lockfile pins the lix installation, but this is **not a fully reproducible Haxe dependency lock**. Preserve the installed Git revisions when recording a release build. GameJolt is no longer an engine dependency.

The engine overrides classes under `source/flixel/`, `source/lime/`, and `source/openfl/`. Arbitrary dependency upgrades can invalidate these overrides.

## Linux setup

Install Node.js/npm, Git, unzip, Neko, a C++ compiler, make, and the native OpenGL/audio libraries required by Lime. The Ubuntu CI additionally installs `libvlc-dev`, `libvlccore-dev`, `libglu1-mesa-dev`, `libgl1-mesa-dev`, `g++-multilib`, and `gcc-multilib`.

Install **zenity** for native save dialogs in the editors. The Linux branches launch it directly; without it, saving from those editors can fail.

The existing setup script installs lix using `npm ci`, selects Haxe, installs the table above, initializes Discord RPC submodules, and patches its bundled RapidJSON header:

```sh
bash install_haxe.sh
npx haxelib run lime build linux -final
```

The script configures global Haxe libraries under `~/haxe/haxelib`. An existing local `.haxelib/` takes precedence. Inspect `npx haxelib list` if the build uses unexpected versions. A fresh checkout does not include a local library archive and does not need one.

`setup_local_libs.sh` is an optional legacy cache helper: it can restore a local `.haxelib.zip` and back up an existing local library directory. It does not install missing dependencies. It is not needed for a fresh global-library setup, and its `sed -i` patch assumes Linux.

If Haxe/haxelib are already on PATH, the `npx` prefix is unnecessary:

```sh
haxelib run lime test linux
haxelib run lime build linux -final
```

## Windows setup

Install Node.js/npm, Git, Neko, and Visual Studio's **Desktop development with C++** workload with a Windows SDK. From Command Prompt in the repository root:

```bat
install_haxe.bat
npx haxelib run lime setup windows
npx haxelib run lime build windows -final
```

The installer uses `%USERPROFILE%\haxe\haxelib`; a local `.haxelib` overrides it. `setup_local_libs.bat` is an optional cache-restore helper, not a prerequisite. The Windows installer retains its historical HTTP haxelib fallback.

## macOS setup

Install the native Apple command-line toolchain, Haxe 4.2.5, and Neko, then install the table's libraries. Follow the macOS dependency commands and Discord patch in [the workflow](../.github/workflows/main.yml); the Linux shell installer is not advertised as a tested macOS installer.

```sh
haxelib run lime build mac -final
```

The CI job uses `macos-14`. Local macOS compilation and runtime behavior were not verified in this audit.

## Engine source and packaged content

Desktop builds copy `assets/fnf/`, `assets/custom/`, and `customList.txt`.
Custom assets remain external files (`embed="false"`) for the filesystem loader.
There is no `-DincludeMods` requirement.

Use a clean source directory and fresh build output for a release. Any mod you
install under `assets/custom/` can be copied into the resulting archive.

When switching revisions, move previous build output aside first: Lime does not
reliably remove previously copied assets. Separate checkouts or worktrees keep
build output isolated. A new worktree needs its own local libraries or access to
configured global libraries.

## Output and troubleshooting

| Target | Release directory |
| --- | --- |
| Linux | `export/release/linux/bin/` |
| Windows | `export/release/windows/bin/` |
| macOS | `export/release/macos/bin/` |

Distribute the whole output directory, not just the executable. Debug builds use `export/debug/`. Libraries, Node modules, and build output are deliberately excluded from source control.

If a build fails with undefined native references after switching toolchains or compiler flags, move the affected target's output aside and rebuild it. In the audit environment, the existing Linux debug output failed to link, while the release target compiled and linked successfully. That failure does not establish a source-level regression.

## Validation status

These are historical local results, not certification of a public release.
The original audit was recorded on **2026-09-10**.

- Linux standalone release build: compiled and linked with the locally installed Haxe 4.2.5 toolchain; output checked for absence of packaged mods and the mod-specific list.
- Existing Linux debug build: Haxe compilation completed, but native linking failed with undefined references. No debug pass is claimed.
- Windows/macOS builds and fresh dependency installation: not executed during the original audit.
- Achievement rules: 52 Haxe-interpreter cases passed using the actual rule function and Friday-night condition with stubbed engine state. The 16 base definitions and unlock predicates match Psych 0.6.3. An additional engine award unlocks when the framerate setting reaches 1000 FPS; all 17 award icons are present.
- Interactive gameplay/editor/audio checks and comparative FPS/RAM benchmarks: not executed during the original audit.
- The audited local build included uncommitted diagnostics/audio changes. Those results did not certify the committed baseline alone.

Additional development verification:

- **2026-09-14:** the Linux release build compiled and linked after the sticker scaling change. Area-sampling calculations were checked against all 30 available development stickers (maximum scale error below 0.1%). Visual verification in the running game remains outstanding; this was a development build, not a tagged release.

Release validation must record the exact commit/tag, platform, toolchain,
and build logs. Results from a different revision or a modified working tree
do not certify the release candidate.

Use the [release checklist](RELEASE_CHECKLIST.md) to track runtime validation separately from compilation.
