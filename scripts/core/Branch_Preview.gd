# Branch_Preview.gd
extends Node2D
class_name BranchPreviewNode

const BranchType = preload("res://scripts/core/branch_types.gd").BranchType

# This dictionary holds the pre-rotated "alive" textures.
# The keys are BranchType enum values.
# The values are Arrays of 4 Textures, corresponding to rotation_idx 0, 1, 2, 3.
# Rotation_idx 0 = 0 degrees, 1 = 90 deg clockwise, 2 = 180, 3 = 270.
var branch_textures = {
	BranchType.BEND: {
		"alive": [
			preload("res://sprites/branches/BEND/bend_live_1.png"),
			preload("res://sprites/branches/BEND/bend_live_2.png"),
			preload("res://sprites/branches/BEND/bend_live_3.png"),
			preload("res://sprites/branches/BEND/bend_live_4.png")
		],
		"dead": [
			preload("res://sprites/branches/BEND/bend_dead_1.png"),
			preload("res://sprites/branches/BEND/bend_dead_2.png"),
			preload("res://sprites/branches/BEND/bend_dead_3.png"),
			preload("res://sprites/branches/BEND/bend_dead_4.png")
		]
	},
	BranchType.STRAIGHT: {
		"alive": [
			preload("res://sprites/branches/STRAIGHT/straight_live_1.png"),
			preload("res://sprites/branches/STRAIGHT/straight_live_2.png"),
			preload("res://sprites/branches/STRAIGHT/straight_live_1.png"),
			preload("res://sprites/branches/STRAIGHT/straight_live_2.png")
		],
		"dead": [
			preload("res://sprites/branches/STRAIGHT/straight_dead_1.png"),
			preload("res://sprites/branches/STRAIGHT/straight_dead_2.png"),
			preload("res://sprites/branches/STRAIGHT/straight_dead_1.png"),
			preload("res://sprites/branches/STRAIGHT/straight_dead_2.png")
		]
	},
	BranchType.THREE: {
		"alive": [
			preload("res://sprites/branches/THREE/three_live_1.png"),
			preload("res://sprites/branches/THREE/three_live_2.png"),
			preload("res://sprites/branches/THREE/three_live_3.png"),
			preload("res://sprites/branches/THREE/three_live_4.png")
		],
		"dead": [
			preload("res://sprites/branches/THREE/three_dead_1.png"),
			preload("res://sprites/branches/THREE/three_dead_2.png"),
			preload("res://sprites/branches/THREE/three_dead_3.png"),
			preload("res://sprites/branches/THREE/three_dead_4.png")
		]
	},
	BranchType.TERMINAL: {
		"alive": [
			preload("res://sprites/branches/TERMINAL/terminal_live_1.png"),
			preload("res://sprites/branches/TERMINAL/terminal_live_2.png"),
			preload("res://sprites/branches/TERMINAL/terminal_live_3.png"),
			preload("res://sprites/branches/TERMINAL/terminal_live_4.png")
		],
		"dead": [
			preload("res://sprites/branches/TERMINAL/terminal_dead_1.png"),
			preload("res://sprites/branches/TERMINAL/terminal_dead_2.png"),
			preload("res://sprites/branches/TERMINAL/terminal_dead_3.png"),
			preload("res://sprites/branches/TERMINAL/terminal_dead_4.png")
		]
	},
	BranchType.EMPTY: { # Ensure EMPTY has both states, even if textures are null
		"alive": [null, null, null, null], # Array of 4 for consistent access by rot_idx
		"dead": [null, null, null, null]   # Array of 4
	}
}
# Fill this with ALL your actual preloaded texture paths for each type and rotation.

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	if not sprite:
		printerr("Branch_Preview: Sprite2D node named 'Sprite2D' is missing as a child!")
		return
	sprite.visible = false 
	sprite.rotation_degrees = 0

# Now takes a 'tile_state' parameter ("alive" or "dead")
func set_tile_visuals(branch_type_enum_value: BranchType, rotation_idx: int, tile_state: String = "alive"):
	# print("Branch_Preview: set_tile_visuals called. Type: ", branch_type_enum_value, ", rot_idx: ", rotation_idx, ", State: ", tile_state)
	if not sprite: return

	if branch_type_enum_value == BranchType.EMPTY:
		sprite.texture = null
		sprite.visible = false
		return

	if rotation_idx < 0 or rotation_idx > 3:
		printerr("Branch_Preview: Invalid rotation_idx: ", rotation_idx, " for type ", branch_type_enum_value)
		sprite.texture = null
		sprite.visible = false
		return

	if not (tile_state == "alive" or tile_state == "dead"):
		printerr("Branch_Preview: Invalid tile_state '", tile_state, "'. Defaulting to 'alive'.")
		tile_state = "alive" # Default to alive if an invalid state is passed

	if branch_textures.has(branch_type_enum_value):
		var type_data: Dictionary = branch_textures[branch_type_enum_value]
		if type_data.has(tile_state):
			var state_textures: Array = type_data[tile_state]
			if rotation_idx < state_textures.size():
				var tex: Texture2D = state_textures[rotation_idx]
				sprite.texture = tex
				sprite.visible = (tex != null)
				# if sprite.texture:
					# print("Branch_Preview: Sprite texture set to: ", sprite.texture.resource_path if sprite.texture else "null", " Visible: ", sprite.visible)
				# else:
					# print("Branch_Preview: Sprite texture is null. Visible: ", sprite.visible)
			else:
				printerr("Branch_Preview: rotation_idx ", rotation_idx, " out of bounds for '", tile_state, "' textures of type ", branch_type_enum_value, ". Array size: ", state_textures.size())
				sprite.texture = null
				sprite.visible = false
		else:
			printerr("Branch_Preview: No '", tile_state, "' state textures defined for type ", branch_type_enum_value)
			sprite.texture = null
			sprite.visible = false
	else:
		printerr("Branch_Preview: Unknown branch type for texture: ", branch_type_enum_value)
		sprite.texture = null
		sprite.visible = false
