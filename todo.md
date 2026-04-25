## VETKA Todo
### Done previous session
*   Blinking clock screen before splash (PreClock)

*   Pitched beep SFX — classic mode scales pitch by tile row

*   Removed debug print on every tile rotation

*   Cleaned up git (android build dir, stray AI/PDF files, .gitignore)

* * *
### Done this session
*   **Settings screen** — overlay accessible from main menu and in-game HUD. Houses music type (Classic/Modern/Off), SFX, graphics mode (retro splash), language (EN/RU), and solve animation toggle.

*   **Localization (EN/RU)** — `Locale` autoload with `Locale.t(key)`. Russian difficulty names from the original game (новичок, стажёр, профи, мастер, эксперт, ТОРеро). Language switches instantly everywhere.

*   **Settings persistence** — all settings saved to `user://settings.cfg` via ConfigFile. Loaded on boot.

*   **In-game HUD panel** — swipe up from handle tab to reveal Give Up / Settings buttons. Swipe down to hide. Buttons fade in/out. Blocks branch taps while open. Panel locked during solve animation.

*   **Give Up with solve animation** — solves puzzle from source outward tile by tile (BFS, 0.07s stagger), pitched beep per tile, 3s hold then fade to menu. Tap to skip the delay. Toggle in Settings (Solve Anim on/off). Solution rotation saved in puzzle_generator before scrambling.

*   **Main menu swipe** — difficulty changed by swiping left/right instead of a button. Difficulty label centered between Start and Settings.

*   **Main menu / HUD labels** — Start, Settings, Give Up labels added next to buttons with locale support and pixel-precise spacing.

* * *
### Code — ready to implement when you want
*   **Twinkling after win** — star animation is done. Needs a third pass in the win sequence (after blossoms), spawning Star instances on tiles. Same staggered-timer pattern as leaves/blossoms.

*   **Difficulty transition animation** — complex. Preview tiles dissolve one by one, replaced randomly by actual puzzle tiles, each with a pitched beep. Requires generating the puzzle before the transition starts (currently happens after scene loads).

* * *
### Art — blocked on you drawing things
*   **Fruit animation** — the third win stage after leaves + blossoms. Pixel art, hand-drawn. Not started.

*   **Branch rotation animation** — pixel-perfect turn frames for each tile type (~4 frames per rotation per tile variant). Decision pending: authentic 90s feel vs. snappier modern UX.

*   **Button and HUD artwork** — current buttons are placeholder textures. Settings overlay panel also uses placeholder geometry. User will supply final pixel art.

* * *
### Audio — needs a decision
*   **Music** — you have the Bach MIDI files in `audio/midi/`. Two paths:

    *   **Convert to OGG** (MuseScore or FluidSynth + soundfont, free tools) — simplest, works perfectly in Godot, sounds great with a good piano soundfont

    *   **MIDI GDExtension** — more authentic, more complex, build dependencies. **Preferred for authenticity** given this is a recreation of early 90s abandonware — real MIDI playback matches the source material better than a rendered OGG.

    *   Currently most difficulties share the same `opening.mp3` placeholder

*   **Modern tracks** — `modernA/B/C.mp3` are placeholders, only torrero has its own track

* * *
### Small things to not forget
*   `switch_to_off_sfx` in AudioManager has no audio file assigned (it's an `@export` with nothing set in the Inspector) — this is the sound for when you toggle music Off

*   `SceneChanger.gd` logs a wall of debug text on every scene transition — worth silencing eventually

*   `scenes/Main.tscn` and `scripts/core/Branch_Preview.gd` appear to be unused/legacy — could be deleted from the repo

*   `sprites/BG_old.png`, `sprites/BG2.png`, `icons/app icon_old.png` are still tracked in git — old backup files, safe to remove when you're sure you don't need them
