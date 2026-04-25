## VETKA Todo
### Done previous session
*   Blinking clock screen before splash (PreClock)
    
*   Pitched beep SFX — classic mode scales pitch by tile row
    
*   Removed debug print on every tile rotation
    
*   Cleaned up git (android build dir, stray AI/PDF files, .gitignore)
    
* * *
### Code — ready to implement when you want
*   **Give Up** — solves puzzle from source outward tile by tile with staggered delay, no win animation. Needs one small change to puzzle_generator first: save the solution `rotation_index` per tile before randomizing, so the solver knows where each tile needs to land. **Placement idea: long-press on the source tile** (avoids needing screen space for a button). Show a small confirmation popup to prevent accidental triggers.

*   **Settings screen** — dedicated scene accessible from the main menu with proper pixel art buttons. Could house music toggle (classic/modern), and anything else currently buried in menus. Scoped addition, lower risk than in-game UI changes.
    
*   **Twinkling after win** — you said the star animation is done. Needs a third pass in the win sequence (after blossoms), spawning Star instances on tiles. Same staggered-timer pattern as leaves/blossoms.
    
*   **Difficulty transition animation** — complex. Preview tiles dissolve one by one, replaced randomly by actual puzzle tiles, each with a pitched beep. Requires generating the puzzle before the transition starts (currently happens after scene loads).
    
* * *
### Art — blocked on you drawing things
*   **Fruit animation** — the third win stage after leaves + blossoms. Pixel art, hand-drawn. Not started.
    
*   **Branch rotation animation** — pixel-perfect turn frames for each tile type (~4 frames per rotation per tile variant). Decision pending: authentic 90s feel vs. snappier modern UX.
    
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