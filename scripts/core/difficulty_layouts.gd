# res://data/difficulty_layouts.gd
extends Node

# You MUST use the actual enum values from your BranchType.gd here
const BranchType = preload("res://scripts/core/branch_types.gd").BranchType

# The layouts for each difficulty's visual representation.
# 'pos' is Vector2i grid coordinates (0,0 is top-left of the word/design).
# 'rot_idx' is 0-3, corresponding to your pre-rotated sprites:
#   0: base orientation (e.g., your *_1.png)
#   1: 90 deg clockwise (e.g., your *_2.png)
#   2: 180 deg clockwise (e.g., your *_3.png)
#   3: 270 deg clockwise (e.g., your *_4.png)
const PREVIEW_LAYOUTS = {
	"baby": [
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(1, 7), "rot_idx": 1},
		{"tile_type_enum": BranchType.THREE, "pos": Vector2i(1, 8), "rot_idx": 0},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(1, 9), "rot_idx": 0},
		
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(2, 7), "rot_idx": 3},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(2, 8), "rot_idx": 1},

		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(3, 8), "rot_idx": 1},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(3, 9), "rot_idx": 1},
		
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(4, 7), "rot_idx": 2},
		{"tile_type_enum": BranchType.THREE, "pos": Vector2i(4, 8), "rot_idx": 2},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(4, 9), "rot_idx": 3},

	],
	"intern": [
		# Based on your image, let's approximate.
		# This requires careful mapping from your Aseprite design.
		# Example: The left vertical part of the "F-like" shape
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(1, 7), "rot_idx": 1},
		{"tile_type_enum": BranchType.THREE, "pos": Vector2i(1, 8), "rot_idx": 0},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(1, 9), "rot_idx": 0},
		
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(2, 7), "rot_idx": 3},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(2, 8), "rot_idx": 1},

		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(3, 8), "rot_idx": 1},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(3, 9), "rot_idx": 1},
		
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(4, 7), "rot_idx": 2},
		{"tile_type_enum": BranchType.THREE, "pos": Vector2i(4, 8), "rot_idx": 2},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(4, 9), "rot_idx": 3},

	],
	"profi": [
		# Based on your image, let's approximate.
		# This requires careful mapping from your Aseprite design.
		# Example: The left vertical part of the "F-like" shape
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(0, 1), "rot_idx": 1}, # Opening upwards

	],
	"master": [
		# Based on your image, let's approximate.
		# This requires careful mapping from your Aseprite design.
		# Example: The left vertical part of the "F-like" shape
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(0, 1), "rot_idx": 1}, # Opening upwards
	],
	"expert": [
		# Based on your image, let's approximate.
		# This requires careful mapping from your Aseprite design.
		# Example: The left vertical part of the "F-like" shape
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(0, 1), "rot_idx": 1}, # Opening upwards
		
	],
	"torrero": [
		# Based on your image, let's approximate.
		# This requires careful mapping from your Aseprite design.
		# Example: The left vertical part of the "F-like" shape
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(0, 1), "rot_idx": 1}, # Opening upwards

	],
}
