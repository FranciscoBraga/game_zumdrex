extends SceneTree
# Testa a cena jogável simulando cliques. Rodar:
#   godot --headless --path . --script res://tests/test_scene.gd

var failures := 0


func check(cond: bool, msg: String) -> void:
	print(("ok      " if cond else "FALHOU  ") + msg)
	if not cond:
		failures += 1


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await wait(0.2)
	var b = game.board
	check(b.size == Vector2i(4, 4) and game.views.size() == 2, "fase 1 carregada com 2 peças na tela")

	# clicar longe escolhe 1 passo naquela direção
	check(game._step_toward(b.main_unit(), Vector2i(0, 3)) == Vector2i(2, 3), "clique longe anda 1 passo na direção")
	check(game._step_toward(b.main_unit(), Vector2i(3, 0)) == Vector2i(3, 2), "clique longe para cima anda 1 passo para cima")
	check(b.turn == 1, "calcular o passo não gasta a rodada")

	# anda para cima
	game._on_cell_clicked(Vector2i(3, 2))
	check(game.busy, "durante a animação a entrada fica bloqueada")
	await wait(1.0)
	check(b.main_unit()["pos"] == Vector2i(3, 2), "sobrevivente andou")
	check(b.turn == 2 and not game.busy, "zumbis jogaram e voltou a vez do jogador")
	var zv = game.views[b.zombies()[0]["id"]]
	check(zv.position == game.grid_to_px(b.zombies()[0]["pos"]), "sprite do zumbi acompanha a posição")

	# modo tiro
	game.set_mode("shoot")
	check(game.mode == "shoot", "modo atirar ativado")
	game.set_mode("move")

	game._on_cell_clicked(Vector2i(3, 1))
	await wait(1.0)
	game._on_cell_clicked(Vector2i(3, 0))
	await wait(1.0)
	check(b.status == "won" and game.ui["overlay"].visible, "fase 1 vencida e janela de vitória aparece")

	game._on_overlay_button()
	await wait(0.2)
	check(game.level_index == 1 and game.board.size == Vector2i(6, 6), "botão leva para a fase 2")

	# fase 2: tiro de verdade
	game.load_level(1)
	await wait(0.1)
	b = game.board
	var ammo: int = b.ammo
	game.set_mode("shoot")
	var targets: Array = b.shoot_targets()
	check(not targets.is_empty(), "há casas para atirar")
	game._on_cell_clicked(targets[0])
	await wait(1.2)
	check(b.ammo == ammo - 1 and game.mode == "move", "tiro gasta munição e volta ao modo andar")

	# usar item / mochila na tela
	check(game.ui["bag"].get_child_count() >= 3, "mochila mostra os espaços")

	# fase 4: pegar o bebê
	game.load_level(3)
	await wait(0.1)
	b = game.board
	check(b.survivors().size() == 2, "fase 4 tem sobrevivente e bebê")

	# reiniciar
	game.load_level(0)
	await wait(0.1)
	check(game.board.turn == 1 and game.views.size() == 2, "reiniciar recarrega a fase")

	print("\n%d falhas" % failures)
	quit(1 if failures > 0 else 0)
