# TurnManager.gd
extends Node

# Sinal emitido quando o turno do jogador começa
signal player_turn_started
# Sinal emitido quando o turno dos inimigos começa
signal enemy_turn_started

enum Turn { PLAYER, ENEMY }
var current_turn = Turn.PLAYER

@onready var player = get_parent().find_child("Player") # Encontra o jogador na cena
var enemies = []

func _ready():
	# Encontra todos os inimigos na cena
	for child in get_parent().get_children():
		if child is Zombie: # Usa o nome da classe do script do zumbi
			enemies.append(child)
	
	# Conecta os sinais de fim de turno
	player.turn_ended.connect(end_player_turn)
	for enemy in enemies:
		enemy.turn_ended.connect(on_enemy_turn_ended)

	# Inicia o primeiro turno
	start_player_turn()

func start_player_turn():
	current_turn = Turn.PLAYER
	print("--- TURNO DO JOGADOR ---")
	player_turn_started.emit()

func end_player_turn():
	if current_turn == Turn.PLAYER:
		start_enemy_turn()

func start_enemy_turn():
	current_turn = Turn.ENEMY
	print("--- TURNO DOS ZUMBIS ---")
	enemy_turn_started.emit()
	
	# Se não houver inimigos, pula o turno
	if enemies.is_empty():
		end_enemy_turn()
		return
	
	# Diz ao primeiro inimigo para jogar
	enemies[0].take_turn()

# Chamado quando um inimigo termina seu turno
func on_enemy_turn_ended(enemy_node):
	var current_index = enemies.find(enemy_node)
	var next_index = current_index + 1
	
	if next_index < enemies.size():
		# Passa para o próximo inimigo
		enemies[next_index].take_turn()
	else:
		# Todos os inimigos jogaram, termina o turno deles
		end_enemy_turn()

func end_enemy_turn():
	print("--- FIM DO TURNO DOS ZUMBIS ---")
	start_player_turn()
