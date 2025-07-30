# Zombie.gd
extends Node2D

class_name Zombie

signal turn_ended(zombie_node)

@export var start_grid_pos: Vector2i = Vector2i(-10, 3)
var grid_pos: Vector2i

# Referências
@onready var grid_manager = get_parent().find_child("GridManager")
@onready var turn_manager = get_parent().find_child("TurnManager")

func _ready():
	grid_pos = start_grid_pos
	print("zombie:",grid_pos)
	grid_manager.register_object(self, grid_pos)
	turn_manager.enemy_turn_started.connect(on_enemy_turn_started)

# Esta função é um placeholder. take_turn() será chamado pelo TurnManager.
func on_enemy_turn_started():
	pass

# A IA do Zumbi
func take_turn():
	# Linha 28 corrigida
	print("Zumbi em %s está agindo." % grid_pos)
	
	# Lógica simples: tenta mover uma casa para frente
	var possible_moves = grid_manager.get_valid_moves(grid_pos, "PAWN")
	
	if not possible_moves.is_empty():
		# Move para o primeiro movimento válido encontrado
		var target_pos = possible_moves[0]
		grid_manager.move_object(self, grid_pos, target_pos)
		grid_pos = target_pos
		# Linha 38 corrigida
		print("Zumbi moveu para %s" % grid_pos)
	else:
		# Linha 40 corrigida
		print("Zumbi em %s não pode se mover." % grid_pos)

	# Cria uma pequena pausa para o jogador ver o movimento
	await get_tree().create_timer(0.5).timeout
	
	# Avisa ao TurnManager que terminou
	turn_ended.emit(self)
