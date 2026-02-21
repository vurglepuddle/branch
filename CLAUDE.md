# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**VETKA** is a mobile tile-rotation puzzle game built with **Godot 4.3**. Players rotate branch-shaped tiles to connect them into a tree rooted at a source tile. The game targets Android (portrait, 545x1222).

## Engine & Development

This project uses **Godot 4.3**. There is no CLI build system — all builds and exports are done through the Godot Editor GUI or via `godot` CLI:

```bash
# Run the project (from project root)
godot --path . res://scenes/SplashScreen.tscn

# Export for Android (requires export_presets.cfg and Android SDK configured)
godot --headless --export-release "Android" ./build/vetka.apk
```

GDScript files use `.gd` extension. Scenes use `.tscn`. There is no linting or test suite.

## Architecture

### Scene Flow
```
SplashScreen.tscn → main_menu.tscn → Grid.tscn → (win) → main_menu.tscn
```

### Autoload Singletons (always available globally)
| Singleton | Script | Purpose |
|-----------|--------|---------|
| `GlobalSettings` | [scripts/core/GlobalSettings.gd](scripts/core/GlobalSettings.gd) | Stores `current_difficulty` and `last_menu_difficulty_index` |
| `SceneChanger` | [scripts/core/SceneChanger.gd](scripts/core/SceneChanger.gd) | Fade-based scene transitions |
| `FadeOverlay` | [scenes/FadeOverlay.tscn](scenes/FadeOverlay.tscn) | Full-screen fade rectangle |
| `AudioManager` | [scenes/AudioManager.tscn](scenes/AudioManager.tscn) | Music and SFX playback |
| `DifficultyLayouts` | [scripts/core/difficulty_layouts.gd](scripts/core/difficulty_layouts.gd) | Hardcoded tile layouts for difficulty previews |

### Core Game Logic

**Tile types** are defined in [scripts/core/branch_types.gd](scripts/core/branch_types.gd):
- `STRAIGHT` — 2 connections (opposite sides)
- `BEND` — 2 connections (adjacent sides)
- `THREE` — 3 connections (T-junction)
- `TERMINAL` — 1 connection (leaf/endpoint)
- `EMPTY` — no connections

**Connections** are represented as `[UP, RIGHT, DOWN, LEFT]` arrays of 0s and 1s. Rotation cycles the array and updates the tile's sprite.

**[scripts/core/branch.gd](scripts/core/branch.gd)** — Individual tile node. Handles rotation, alive/dead state, texture selection, leaf spawning, and blossom animations.

**[scripts/core/grid.gd](scripts/core/grid.gd)** — Main puzzle controller. Manages the 2D `branches[][]` array, delegates generation to `PuzzleGenerator`, handles click input forwarded from tiles, runs connection propagation, and triggers the win sequence.

**[scripts/core/puzzle_generator.gd](scripts/core/puzzle_generator.gd)** — Procedural puzzle generation via Prim's MST algorithm. Guarantees solvability. Eliminates 4-way junctions, validates connectivity, then randomizes tile rotations.

### Connection Propagation
- `propagate_connection()` — recursively marks tiles as "alive" from the source tile outward
- `disconnect_if_isolated()` — recursively marks unreachable tiles as "dead"
- Both functions are called on every tile rotation; they handle toroidal wrapping via modulo arithmetic when `is_toroidal_grid` is true

### Difficulty System
Difficulties are configured as dictionaries in `puzzle_generator.gd` with these keys:
- `prim_initial_density_factor` / `prim_min_tiles` — Prim's phase target
- `final_target_density_factor` / `final_density_variation_factor` — post-processing target
- `max_gen_attempts` — retries on failure

The `torrero` difficulty enables **toroidal wrapping** (`is_toroidal_grid = true`), where left/right and top/bottom grid edges connect.

### Audio System
Two music libraries: **Classic** (Bach, opening theme) and **Modern** (electronic tracks). Toggled via menu or M key. SFX uses named keys. Implemented in [scripts/core/audio.gd](scripts/core/audio.gd) with tween-based fade in/out.

## Key Files

| File | Role |
|------|------|
| [project.godot](project.godot) | Engine config, autoloads, render settings |
| [export_presets.cfg](export_presets.cfg) | Android export config |
| [scenes/Grid.tscn](scenes/Grid.tscn) | Main gameplay scene |
| [scenes/Branch.tscn](scenes/Branch.tscn) | Tile prefab (Sprite2D + leaf + blossom) |
| [scripts/core/grid.gd](scripts/core/grid.gd) | Puzzle controller |
| [scripts/core/puzzle_generator.gd](scripts/core/puzzle_generator.gd) | Solvable puzzle generation |
| [scripts/core/branch.gd](scripts/core/branch.gd) | Tile behavior |
| [scripts/legacy/leftover.gd](scripts/legacy/leftover.gd) | Unused legacy code |

## Sprite Organization

Branch tile sprites are under [sprites/branches/](sprites/branches/) organized by type (`STRAIGHT/`, `BEND/`, `THREE/`, `TERMINAL/`). Leaf animations are in [sprites/Leaf/](sprites/Leaf/) (Groups 1–4). UI elements are in [sprites/UI/](sprites/UI/).
