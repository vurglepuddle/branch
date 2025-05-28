# Branch_Preview.gd
extends Node2D
class_name BranchPreviewNode

const BranchType = preload("res://scripts/core/branch_types.gd").BranchType

# This dictionary holds the pre-rotated "alive" textures.
# The keys are BranchType enum values.
# The values are Arrays of 4 Textures, corresponding to rotation_idx 0, 1, 2, 3.
# Rotation_idx 0 = 0 degrees, 1 = 90 deg clockwise, 2 = 180, 3 = 270.
var pre_rotated_alive_textures = {
	BranchType.BEND: [
		preload("res://sprites/branches/BEND/bend_live_1.png"), # Corresponds to rot_idx 0
		preload("res://sprites/branches/BEND/bend_live_2.png"), # Corresponds to rot_idx 1
		preload("res://sprites/branches/BEND/bend_live_3.png"), # Corresponds to rot_idx 2
		preload("res://sprites/branches/BEND/bend_live_4.png")  # Corresponds to rot_idx 3
	],
	BranchType.STRAIGHT: [
		preload("res://sprites/branches/STRAIGHT/straight_live_1.png"), # rot_idx 0 (e.g., horizontal)
		preload("res://sprites/branches/STRAIGHT/straight_live_2.png"), # rot_idx 1 (e.g., vertical)
		preload("res://sprites/branches/STRAIGHT/straight_live_1.png"), # rot_idx 2 (horizontal again, or unique if needed)
		preload("res://sprites/branches/STRAIGHT/straight_live_2.png")  # rot_idx 3 (vertical again, or unique if needed)
	],
	BranchType.THREE: [
		preload("res://sprites/branches/THREE/three_live_1.png"),
		preload("res://sprites/branches/THREE/three_live_2.png"),
		preload("res://sprites/branches/THREE/three_live_3.png"),
		preload("res://sprites/branches/THREE/three_live_4.png")
	],
	BranchType.TERMINAL: [
		preload("res://sprites/branches/TERMINAL/terminal_live_1.png"),
		preload("res://sprites/branches/TERMINAL/terminal_live_2.png"),
		preload("res://sprites/branches/TERMINAL/terminal_live_3.png"),
		preload("res://sprites/branches/TERMINAL/terminal_live_4.png")
	],
	BranchType.EMPTY: [null, null, null, null] # No texture for empty, ensure 4 nulls for consistent access
}
# Fill this with ALL your actual preloaded texture paths for each type and rotation.

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	if not sprite:
		printerr("Branch_Preview: Sprite2D node named 'Sprite2D' is missing as a child!")
		return
	sprite.visible = false # Start hidden, will be shown if a valid texture is set
	sprite.rotation_degrees = 0 # The sprite itself is never rotated programmatically

func set_tile_visuals(branch_type_enum_value: BranchType, rotation_idx: int):
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

	if pre_rotated_alive_textures.has(branch_type_enum_value):
		var textures_for_type: Array = pre_rotated_alive_textures[branch_type_enum_value]
		if rotation_idx < textures_for_type.size():
			var tex: Texture2D = textures_for_type[rotation_idx]
			sprite.texture = tex
			sprite.visible = (tex != null) # Show only if texture is valid
		else:
			printerr("Branch_Preview: rotation_idx ", rotation_idx, " out of bounds for 'alive' textures of type ", branch_type_enum_value, ". Array size: ", textures_for_type.size())
			sprite.texture = null
			sprite.visible = false
	else:
		printerr("Branch_Preview: Unknown branch type for texture: ", branch_type_enum_value)
		sprite.texture = null
		sprite.visible = false
