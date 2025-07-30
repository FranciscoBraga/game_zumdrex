# Player.gd
extends Node2D

class_name Player

# Sinal para avisar que o jogador terminou o turno
signal turn_ended

@export var start_grid_pos: Vector2i = Vector2i(9, -5) # Posição inicial no grid
var grid_pos: Vector2i

@export var action_points: int = 2
var max_action_points: int = 2

# Referências para os outros managers
@onready var grid_manager = get_parent().find_child("GridManager")
@onready var turn_manager = get_parent().find_child("TurnManager")

func _ready():
	grid_pos = start_grid_pos
	print("player:",grid_pos)
	grid_manager.register_object(self, grid_pos)
	
	# Conecta ao sinal de início de turno do jogador
	turn_manager.player_turn_started.connect(on_turn_started)

func on_turn_started():
	action_points = max_action_points
	print("Jogador tem pontos de ação."%action_points)

func move_to_tile(target_grid_pos: Vector2i):
	print("move_to_tile")
	if action_points >= 1:
		var valid_moves = grid_manager.get_valid_moves(grid_pos, "QUEEN")
		if target_grid_pos in valid_moves:
			print("Jogador movendo de "%grid_pos)
			print("para"%target_grid_pos)
			grid_manager.move_object(self, grid_pos, target_grid_pos)
			grid_pos = target_grid_pos
			
			action_points -= 1
			print("Ações restantes:"% action_points)
			
			if action_points <= 0:
				end_my_turn()
		else:
			print("Movimento inválido!")
	else:
		print("Sem pontos de ação!")

func end_my_turn():
	if turn_manager.current_turn == turn_manager.Turn.PLAYER:
		print("Jogador encerrando o turno.")
		turn_ended.emit()

# Função de Input para teste
func _unhandled_input(event):
	# Só processa cliques se for o turno do jogador
	if turn_manager.current_turn != turn_manager.Turn.PLAYER:
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target_grid_pos = grid_manager.global_world_to_grid_pos(get_global_mouse_position())
		move_to_tile(target_grid_pos)
	
	# Para passar o turno manualmente
	if event.is_action_pressed("ui_accept"): # Tecla Enter/Espaço
		end_my_turn()
