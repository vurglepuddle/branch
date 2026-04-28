# WordPreviewRenderer.gd
extends SubViewport

const BranchType = preload("res://scripts/core/branch_types.gd").BranchType

@export var branch_preview_scene: PackedScene
@export var cell_pixel_size: Vector2 = Vector2(84, 68)

@export var preview_grid_width_in_tiles: int = 6
@export var preview_grid_height_in_tiles: int = 17

@onready var tile_container: Node2D = $TileContainer

# Maps Vector2i(x, y) → BranchPreviewNode for O(1) lookup during animation.
var _tile_map: Dictionary = {}

func _ready():
	if not tile_container:
		printerr("WordPreviewRenderer: Node2D child named 'TileContainer' is missing!")
		return
	if not branch_preview_scene:
		printerr("WordPreviewRenderer: 'Branch Preview Scene' export not assigned!")
		return
	if not (DifficultyLayouts is Node):
		printerr("WordPreviewRenderer: Autoload 'DifficultyLayouts' not valid.")
		return

	if cell_pixel_size.x <= 0 or cell_pixel_size.y <= 0:
		printerr("WordPreviewRenderer: cell_pixel_size is invalid (<=0).")
		return
	if preview_grid_width_in_tiles <= 0 or preview_grid_height_in_tiles <= 0:
		printerr("WordPreviewRenderer: preview_grid_width/height_in_tiles is invalid (<=0).")
		return

	self.size = Vector2i(
		ceil(preview_grid_width_in_tiles * cell_pixel_size.x),
		ceil(preview_grid_height_in_tiles * cell_pixel_size.y)
	)
	print("WordPreviewRenderer _ready: Initialized SubViewport size to: ", self.size)


func generate_preview(difficulty_name: String):
	if not branch_preview_scene or not is_instance_valid(tile_container) or not (DifficultyLayouts is Node) \
	   or cell_pixel_size.x <= 0 or cell_pixel_size.y <= 0 \
	   or preview_grid_width_in_tiles <= 0 or preview_grid_height_in_tiles <= 0:
		printerr("WordPreviewRenderer: Aborting generate_preview due to missing components or invalid settings.")
		return

	for child in tile_container.get_children():
		child.queue_free()
	_tile_map.clear()

	var layouts = DifficultyLayouts.PREVIEW_LAYOUTS
	if not layouts.has(difficulty_name):
		printerr("WordPreviewRenderer: No layout defined for '", difficulty_name, "'.")
		return

	var layout_data: Array = layouts[difficulty_name]
	if layout_data.is_empty():
		return

	for tile_info in layout_data:
		if not ("tile_type_enum" in tile_info and "pos" in tile_info and "rot_idx" in tile_info):
			printerr("WordPreviewRenderer: Invalid tile_info structure: ", tile_info)
			continue

		var tile_type_enum_value = tile_info.tile_type_enum
		var absolute_grid_pos: Vector2i = tile_info.pos
		var rotation_idx: int = tile_info.rot_idx
		var tile_state: String = tile_info.get("state", "alive")

		if absolute_grid_pos.x < 0 or absolute_grid_pos.x >= preview_grid_width_in_tiles or \
		   absolute_grid_pos.y < 0 or absolute_grid_pos.y >= preview_grid_height_in_tiles:
			printerr("WordPreviewRenderer: Tile pos ", absolute_grid_pos, " out of bounds. Skipping.")
			continue

		var tile_instance: Node2D = branch_preview_scene.instantiate()
		if not tile_instance.has_method("set_tile_visuals"):
			tile_instance.queue_free()
			continue

		tile_container.add_child(tile_instance)
		tile_instance.position = Vector2(
			absolute_grid_pos.x * cell_pixel_size.x + cell_pixel_size.x / 2.0,
			absolute_grid_pos.y * cell_pixel_size.y + cell_pixel_size.y / 2.0
		)
		tile_instance.set_tile_visuals(tile_type_enum_value, rotation_idx, tile_state)
		_tile_map[absolute_grid_pos] = tile_instance


# Updates or creates a preview tile at (x, y) with the given game tile visuals.
func update_tile(x: int, y: int, type_enum: int, rot_idx: int, state: String) -> void:
	var key := Vector2i(x, y)
	if not _tile_map.has(key):
		if not branch_preview_scene:
			return
		var tile: Node2D = branch_preview_scene.instantiate()
		if not tile.has_method("set_tile_visuals"):
			tile.queue_free()
			return
		tile.position = Vector2(
			x * cell_pixel_size.x + cell_pixel_size.x / 2.0,
			y * cell_pixel_size.y + cell_pixel_size.y / 2.0
		)
		tile_container.add_child(tile)
		_tile_map[key] = tile
	_tile_map[key].set_tile_visuals(type_enum, rot_idx, state)


# Hides a preview tile at (x, y) by setting it to EMPTY visuals.
func hide_tile(x: int, y: int) -> void:
	var key := Vector2i(x, y)
	if _tile_map.has(key):
		_tile_map[key].set_tile_visuals(BranchType.EMPTY, 0, "dead")
