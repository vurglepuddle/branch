# WordPreviewRenderer.gd
extends SubViewport

@export var branch_preview_scene: PackedScene 
@export var cell_pixel_size: Vector2 = Vector2(84, 68) 

# Define the fixed size of your preview canvas IN TILES
# For example, if you want it to always be 6 tiles wide like your game board,
# and tall enough for any design (e.g., 5 tiles high for words, adjust as needed)
@export var preview_grid_width_in_tiles: int = 6 
# Max height your designs will ever need, or a comfortable fixed preview height
@export var preview_grid_height_in_tiles: int = 17 # EXAMPLE: Adjust this based on your tallest design

@onready var tile_container: Node2D = $TileContainer

func _ready():
	if not tile_container:
		printerr("WordPreviewRenderer: Node2D child named 'TileContainer' is missing!")
		return
	if not branch_preview_scene:
		printerr("WordPreviewRenderer: 'Branch Preview Scene' export not assigned!")
		return
	if not DifficultyLayouts is Node:
		printerr("WordPreviewRenderer: Autoload 'DifficultyLayouts' not valid.")
		return
	
	if cell_pixel_size.x <= 0 or cell_pixel_size.y <= 0:
		printerr("WordPreviewRenderer: cell_pixel_size is invalid (<=0).")
		return
	if preview_grid_width_in_tiles <= 0 or preview_grid_height_in_tiles <= 0:
		printerr("WordPreviewRenderer: preview_grid_width/height_in_tiles is invalid (<=0).")
		return

	# Set the SubViewport size ONCE based on the fixed preview grid dimensions
	self.size = Vector2i(
		ceil(preview_grid_width_in_tiles * cell_pixel_size.x),
		ceil(preview_grid_height_in_tiles * cell_pixel_size.y)
	)
	print("WordPreviewRenderer _ready: Initialized SubViewport size to: ", self.size, 
		  " (based on ", preview_grid_width_in_tiles, "x", preview_grid_height_in_tiles, " tiles)")


func generate_preview(difficulty_name: String):
	# print("--- WordPreviewRenderer: generate_preview called for '", difficulty_name, "' ---")

	if not branch_preview_scene or not is_instance_valid(tile_container) or not (DifficultyLayouts is Node) \
	   or cell_pixel_size.x <= 0 or cell_pixel_size.y <= 0 \
	   or preview_grid_width_in_tiles <= 0 or preview_grid_height_in_tiles <= 0:
		printerr("WordPreviewRenderer: Aborting generate_preview due to missing components or invalid settings.")
		return

	for child in tile_container.get_children():
		child.queue_free()

	var layouts = DifficultyLayouts.PREVIEW_LAYOUTS 
	if not layouts.has(difficulty_name):
		printerr("WordPreviewRenderer: No layout defined for '", difficulty_name, "'.")
		return # No layout data, so nothing to draw

	# --- THIS LINE WAS MISSING OR MISPLACED IN THE PREVIOUS EXAMPLE ---
	var layout_data: Array = layouts[difficulty_name] 
	# --- END OF FIX ---

	if layout_data.is_empty():
		# print("WordPreviewRenderer: Layout data for '", difficulty_name, "' is EMPTY.")
		return # No tiles to draw
	# print("WordPreviewRenderer: Layout data for '", difficulty_name, "' has ", layout_data.size(), " tiles.")
			
	var tile_instance_count = 0
	for tile_info in layout_data: # Now layout_data is correctly defined
		if not ("tile_type_enum" in tile_info and "pos" in tile_info and "rot_idx" in tile_info):
			printerr("WordPreviewRenderer: Invalid tile_info structure for '", difficulty_name, "': ", tile_info, " (missing essential fields)")
			continue

		var tile_type_enum_value = tile_info.tile_type_enum
		var absolute_grid_pos: Vector2i = tile_info.pos
		var rotation_idx: int = tile_info.rot_idx
		var tile_state: String = tile_info.get("state", "alive")

		if absolute_grid_pos.x < 0 or absolute_grid_pos.x >= preview_grid_width_in_tiles or \
		   absolute_grid_pos.y < 0 or absolute_grid_pos.y >= preview_grid_height_in_tiles:
			printerr("WordPreviewRenderer: Tile pos ", absolute_grid_pos, " for '", difficulty_name, 
					 "' is outside defined preview_grid bounds. Skipping tile.")
			continue
			
		var tile_instance: Node2D = branch_preview_scene.instantiate()
		if not tile_instance.has_method("set_tile_visuals"):
			printerr("WordPreviewRenderer: Instantiated node from '", branch_preview_scene.resource_path, 
					 "' DOES NOT HAVE 'set_tile_visuals' method! It is: ", tile_instance)
			if tile_instance.get_script(): printerr("  Script on instance: ", tile_instance.get_script().resource_path)
			else: printerr("  Instance has NO SCRIPT.")
			tile_instance.queue_free()
			continue
			
		tile_container.add_child(tile_instance)
		tile_instance_count += 1
		
		tile_instance.position = Vector2(
			absolute_grid_pos.x * cell_pixel_size.x + cell_pixel_size.x / 2.0,
			absolute_grid_pos.y * cell_pixel_size.y + cell_pixel_size.y / 2.0
		)
		
		tile_instance.set_tile_visuals(tile_type_enum_value, rotation_idx, tile_state)
			
	# print("WordPreviewRenderer: Instantiated ", tile_instance_count, " tile previews for '", difficulty_name, "'.")
	# SubViewport size is fixed, set in _ready()
