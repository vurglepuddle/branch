# res://data/difficulty_layouts.gd
extends Node

# You MUST use the actual enum values from your BranchType.gd here
const BranchType = preload("res://scripts/core/branch_types.gd").BranchType

const PREVIEW_LAYOUTS = {
	"baby": [
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(1, 7), "rot_idx": 1, "state": "alive"},
		{"tile_type_enum": BranchType.THREE, "pos": Vector2i(1, 8), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(1, 9), "rot_idx": 0, "state": "alive"},
		
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(2, 7), "rot_idx": 3, "state": "alive"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(2, 8), "rot_idx": 1, "state": "alive"},

		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(3, 8), "rot_idx": 1, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(3, 9), "rot_idx": 1, "state": "alive"},
		
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(4, 7), "rot_idx": 2, "state": "alive"},
		{"tile_type_enum": BranchType.THREE, "pos": Vector2i(4, 8), "rot_idx": 2, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(4, 9), "rot_idx": 3, "state": "alive"},

	],
	"intern": [
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(0, 6), "rot_idx": 1, "state": "alive"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(0, 7), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(0, 8), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(0, 9), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(0, 10), "rot_idx": 0, "state": "dead"},
		
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(1, 6), "rot_idx": 3, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(1, 7), "rot_idx": 1, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(1, 8), "rot_idx": 3, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(1, 9), "rot_idx": 3, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(1, 10), "rot_idx": 1, "state": "dead"},
		
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(2, 6), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.THREE, "pos": Vector2i(2, 7), "rot_idx": 1, "state": "alive"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(2, 8), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(2, 9), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(2, 10), "rot_idx": 3, "state": "dead"},
		
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(3, 6), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(3, 7), "rot_idx": 3, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(3, 8), "rot_idx": 1, "state": "alive"},
		{"tile_type_enum": BranchType.THREE, "pos": Vector2i(3, 9), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(3, 10), "rot_idx": 0, "state": "alive"},
		
		{"tile_type_enum": BranchType.THREE, "pos": Vector2i(4, 6), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(4, 7), "rot_idx": 0, "state": "dead"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(4, 8), "rot_idx": 2, "state": "alive"},
		{"tile_type_enum": BranchType.THREE, "pos": Vector2i(4, 9), "rot_idx": 2, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(4, 10), "rot_idx": 0, "state": "alive"},
		
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(5, 6), "rot_idx": 2, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(5, 7), "rot_idx": 0, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(5, 8), "rot_idx": 0, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(5, 9), "rot_idx": 0, "state": "dead"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(5, 10), "rot_idx": 0, "state": "dead"},
		
	],
	"profi": [
# Top embellishment (dead)
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(0, 4), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(1, 4), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(2, 4), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(3, 4), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(4, 4), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(5, 4), "rot_idx": 3, "state": "dead"},
#P
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(0, 5), "rot_idx": 1, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(1, 5), "rot_idx": 2, "state": "alive"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(0, 6), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(1, 6), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(0, 7), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(1, 7), "rot_idx": 0, "state": "alive"},
#R
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(2, 5), "rot_idx": 1, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(3, 5), "rot_idx": 2, "state": "alive"},
		{"tile_type_enum": BranchType.THREE, "pos": Vector2i(2, 6), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(3, 6), "rot_idx": 3, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(2, 7), "rot_idx": 0, "state": "alive"},
#o
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(4, 5), "rot_idx": 1, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(5, 5), "rot_idx": 2, "state": "alive"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(4, 6), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(5, 6), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(4, 7), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(5, 7), "rot_idx": 3, "state": "alive"},
#f
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(0, 8), "rot_idx": 1, "state": "alive"},
		{"tile_type_enum": BranchType.THREE, "pos": Vector2i(1, 8), "rot_idx": 1, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(2, 8), "rot_idx": 2, "state": "alive"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(0, 9), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(1, 9), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(2, 9), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(0, 10), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.THREE, "pos": Vector2i(1, 10), "rot_idx": 3, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(2, 10), "rot_idx": 3, "state": "alive"},
#i
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(3, 8), "rot_idx": 2, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(4, 8), "rot_idx": 1, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(5, 8), "rot_idx": 2, "state": "alive"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(3, 9), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(4, 9), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(5, 9), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(3, 10), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(4, 10), "rot_idx": 3, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(5, 10), "rot_idx": 0, "state": "alive"},
#embellishment row 2
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(0, 11), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(1, 11), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(2, 11), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(3, 11), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(4, 11), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(5, 11), "rot_idx": 2, "state": "dead"},
#embellishment row 3
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(0, 12), "rot_idx": 0, "state": "dead"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(1, 12), "rot_idx": 3, "state": "dead"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(2, 12), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(3, 12), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(4, 12), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(5, 12), "rot_idx": 3, "state": "dead"},

	],
	"master": [
#embellishment r-type 1
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(0, 2), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(1, 2), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(2, 2), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(3, 2), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(4, 2), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(5, 2), "rot_idx": 2, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(5, 3), "rot_idx": 0, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(5, 4), "rot_idx": 0, "state": "dead"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(5, 5), "rot_idx": 0, "state": "dead"},
#m
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(0, 3), "rot_idx": 1, "state": "alive"},
		{"tile_type_enum": BranchType.THREE, "pos": Vector2i(1, 3), "rot_idx": 1, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(2, 3), "rot_idx": 2, "state": "alive"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(0, 4), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(1, 4), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(2, 4), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(0, 5), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(1, 5), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(2, 5), "rot_idx": 0, "state": "alive"},
#a
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(3, 3), "rot_idx": 1, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(4, 3), "rot_idx": 2, "state": "alive"},
		{"tile_type_enum": BranchType.THREE, "pos": Vector2i(3, 4), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.THREE, "pos": Vector2i(4, 4), "rot_idx": 2, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(3, 5), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(4, 5), "rot_idx": 0, "state": "alive"},
#embellishment 2
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(0, 6), "rot_idx": 2, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(0, 7), "rot_idx": 0, "state": "dead"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(0, 8), "rot_idx": 0, "state": "dead"},
#c
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(1, 6), "rot_idx": 1, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(2, 6), "rot_idx": 3, "state": "alive"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(1, 7), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(1, 8), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(2, 8), "rot_idx": 3, "state": "alive"},
#embellishment 3
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(2, 7), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(3, 7), "rot_idx": 2, "state": "dead"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(3, 8), "rot_idx": 0, "state": "dead"},
#t
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(3, 6), "rot_idx": 1, "state": "alive"},
		{"tile_type_enum": BranchType.THREE, "pos": Vector2i(4, 6), "rot_idx": 1, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(5, 6), "rot_idx": 3, "state": "alive"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(4, 7), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(4, 8), "rot_idx": 0, "state": "alive"},
#e
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(0, 9), "rot_idx": 1, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(1, 9), "rot_idx": 3, "state": "alive"},
		{"tile_type_enum": BranchType.THREE, "pos": Vector2i(0, 10), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(1, 10), "rot_idx": 3, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(0, 11), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(1, 11), "rot_idx": 3, "state": "alive"},
#r
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(2, 9), "rot_idx": 1, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(3, 9), "rot_idx": 2, "state": "alive"},
		{"tile_type_enum": BranchType.THREE, "pos": Vector2i(2, 10), "rot_idx": 0, "state": "alive"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(3, 10), "rot_idx": 3, "state": "alive"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(2, 11), "rot_idx": 0, "state": "alive"},
#embellishment 4
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(2, 12), "rot_idx": 3, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(1, 12), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(0, 12), "rot_idx": 1, "state": "dead"},
		
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(0, 13), "rot_idx": 0, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(1, 13), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(2, 13), "rot_idx": 1, "state": "dead"},
		{"tile_type_enum": BranchType.THREE, "pos": Vector2i(3, 13), "rot_idx": 3, "state": "dead"},
		{"tile_type_enum": BranchType.THREE, "pos": Vector2i(4, 13), "rot_idx": 3, "state": "dead"},
		{"tile_type_enum": BranchType.BEND, "pos": Vector2i(5, 13), "rot_idx": 3, "state": "dead"},
		
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(3, 12), "rot_idx": 0, "state": "dead"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(3, 11), "rot_idx": 2, "state": "dead"},
		
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(4, 12), "rot_idx": 0, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(4, 11), "rot_idx": 0, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(4, 10), "rot_idx": 0, "state": "dead"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(4, 9), "rot_idx": 2, "state": "dead"},
		
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(5, 12), "rot_idx": 0, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(5, 11), "rot_idx": 0, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(5, 10), "rot_idx": 0, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(5, 9), "rot_idx": 0, "state": "dead"},
		{"tile_type_enum": BranchType.STRAIGHT, "pos": Vector2i(5, 8), "rot_idx": 0, "state": "dead"},
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(5, 7), "rot_idx": 2, "state": "dead"},
		
		


	],
	"expert": [

		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(0, 1), "rot_idx": 1}, # Opening upwards
		
	],
	"torrero": [
 
		{"tile_type_enum": BranchType.TERMINAL, "pos": Vector2i(0, 1), "rot_idx": 1}, # Opening upwards

	],
}
