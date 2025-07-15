# GridManager.gd - VERSÃO CORRIGIDA
extends Node2D

@export var TILE_SIZE: int = 64
@export var ground_layer: TileMapLayer

var grid_objects = {}

func _ready():
	if not ground_layer:
		push_error("A variável 'ground_layer' no GridManager não foi definida! Por favor, arraste o nó TileMapLayer para o slot no Inspector.")
		get_tree().quit()

func register_object(obj, grid_pos: Vector2i):
	grid_objects[grid_pos] = obj
	obj.position = ground_layer.map_to_local(grid_pos) + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)

func remove_object_from(grid_pos: Vector2i):
	if grid_objects.has(grid_pos):
		grid_objects.erase(grid_pos)

func move_object(obj, from_pos: Vector2i, to_pos: Vector2i):
	remove_object_from(from_pos)
	register_object(obj, to_pos)

func world_to_grid_pos(world_pos: Vector2) -> Vector2i:
	return ground_layer.local_to_map(world_pos)

func is_cell_valid_and_empty(grid_pos: Vector2i) -> bool:
	var used_rect = ground_layer.get_used_rect()
	if not used_rect.has_point(grid_pos):
		return false
	if grid_objects.has(grid_pos):
		return false
	
	# --- LINHA CORRIGIDA AQUI ---
	if ground_layer.get_cell_source_id(grid_pos) == -1:
		return false
		
	return true

func get_valid_moves(grid_pos: Vector2i, move_type: String) -> Array[Vector2i]:
	var valid_moves = []
	
	match move_type:
		"QUEEN":
			var directions = [
				Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
			]
			for dir in directions:
				var next_pos = grid_pos + dir
				if is_cell_valid_and_empty(next_pos):
					valid_moves.append(next_pos)
					
		"PAWN":
			var forward_pos = grid_pos + Vector2i.DOWN 
			if is_cell_valid_and_empty(forward_pos):
				valid_moves.append(forward_pos)

	return valid_moves
