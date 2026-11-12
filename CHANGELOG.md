# Oasis Engine v0.2

Hi! Over the past four weeks I took some time to expand this project and make it better

To be honest, I'm so glad I made these changes because they're nice and make this engine more *professional*. So, let's see what I've done in this time.

## Added

- Added feature artists field. It displays only in Pause menu
, but IDK some cool util, for example FNF has it in V-Slice too.
- Added two previously forgotten credits

### Changes

- Rebuilt difficulty selector in Free Play menu. It has cool tweenning and design too. Difficulties are now looking like these from Story Mode Menu instead of another Alphabet shit
- Redesigned the song information layout to be less chaotic
- Class `Boyfriend.hx` was merged with `Character.hx`. It was such a useless kind of abstraction
- Now, characters have static repeat animation interval on sustain. Previously higher values of BPM may make this repeat too short. You can also add offset to character by configuring it in the character's JSON file, or also you can turn off these repeats. Character Editor contain that.

### Fixed

- Fixed a critical Freeplay bug where the selected difficulty wasn't passed to PlayState, causing songs to always start on Normal difficulty
- Some letterfucks in credits LMAO

Alright, that's all I guess, maybe I forgot about something, but there's major things for sure

See ya next time!