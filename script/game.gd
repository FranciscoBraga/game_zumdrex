extends Node2D
# Cena principal do Xadrez Zumbi: desenha o tabuleiro, recebe cliques,
# monta a interface (painel e mochila) e anima os turnos.
#
# Controles:
#   clique numa peça sua      seleciona
#   clique numa casa com bolinha verde   anda (clicar mais longe anda 1 passo naquela direção)
#   setas do teclado          anda 1 casa
#   1 / A   modo andar        2 / F   modo atirar (clique numa casa vermelha)
#   3 / Espaço   esperar      R   reiniciar fase      Tab   trocar de peça

const Board = preload("res://script/board_logic.gd")
const Levels = preload("res://script/levels.gd")
const UnitView = preload("res://script/unit_view.gd")

const TEX_ITEM := {
	"k": preload("res://assets/items and trap_animation/keys/keys_1_1.png"),
	"h": preload("res://assets/items and trap_animation/flasks/flasks_1_1.png"),
	"a": preload("res://assets/items and trap_animation/mini_box_1/mini_box_1_1.png"),
}

# tabuleiro no centro, com a altura toda; painéis estreitos dos lados
const BOARD_AREA := Rect2(282, 36, 716, 648)
const LEFT_PANEL := Rect2(10, 10, 240, 700)
const RIGHT_PANEL := Rect2(1030, 10, 240, 700)
const MOVE_TIME := 0.18
const NO_CELL := Vector2i(-99, -99)
# cores do tabuleiro de xadrez
const SQ_LIGHT := Color(0.93, 0.86, 0.72)
const SQ_DARK := Color(0.62, 0.45, 0.32)
const FRAME := Color(0.27, 0.17, 0.11)
const FRAME_EDGE := Color(0.55, 0.4, 0.25)

var board
var level_index := 0
var tile := 64.0
var origin := Vector2.ZERO
var views := {}  # id -> UnitView
var selected_id := -1
var mode := "move"  # move | shoot
var busy := false
var hover := Vector2i(-1, -1)
var tracer_from := Vector2.ZERO
var tracer_to := Vector2.ZERO
var tracer_alpha := 0.0
var tracer_arrow := false
var fx: Array = []  # efeitos rápidos: {kind, a, b, t, color, r}

# cor do ataque de longe de cada zumbi
const RANGED_COLOR := {
	"S": Color(0.45, 1.0, 0.3), "O": Color(1.0, 0.9, 0.4), "J": Color(0.75, 0.35, 1.0),
	"Q": Color(1.0, 0.4, 0.75), "F": Color(1.0, 0.8, 0.3), "A": Color(0.85, 0.7, 0.5),
}
var ui := {}
var overlay_kind := "intro"  # intro | end
var show_intro := true
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	_build_ui()
	var shot_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			level_index = clampi(int(arg.get_slice("=", 1)) - 1, 0, Levels.LEVELS.size() - 1)
		elif arg.begins_with("--screenshot="):
			shot_path = arg.get_slice("=", 1)
		elif arg == "--no-intro":
			show_intro = false
	load_level(level_index, true)
	if shot_path != "":
		_screenshot(shot_path)


func _screenshot(path: String) -> void:
	# modo de teste: espera alguns quadros, salva a tela e fecha
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


# ---------- fases ----------

# with_intro = mostra o cartão com o objetivo (ao entrar na fase; não ao reiniciar)
func load_level(i: int, with_intro := false) -> void:
	level_index = i
	board = Board.new()
	board.load_level(Levels.LEVELS[i])
	tile = floorf(minf(BOARD_AREA.size.x / board.size.x, BOARD_AREA.size.y / board.size.y))
	tile = minf(tile, 120.0)
	var board_px := Vector2(board.size) * tile
	origin = BOARD_AREA.position + (BOARD_AREA.size - board_px) / 2.0
	for v in views.values():
		v.queue_free()
	views.clear()
	selected_id = board.main_unit()["id"]
	mode = "move"
	busy = false
	ui["overlay"].visible = false
	ui["tip"].visible = false
	_sync_views()
	_refresh_ui()
	queue_redraw()
	if with_intro and show_intro:
		_show_intro()


func grid_to_px(p: Vector2i) -> Vector2:
	return origin + (Vector2(p) + Vector2(0.5, 0.5)) * tile


func px_to_grid(v: Vector2) -> Vector2i:
	var g := ((v - origin) / tile).floor()
	return Vector2i(int(g.x), int(g.y))


# ---------- entrada ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := px_to_grid(event.position)
		if h != hover:
			hover = h
			_show_hover_info()
			_update_cursor()
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_cell_clicked(px_to_grid(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		set_mode("move")
	elif event is InputEventKey and event.pressed and not event.echo:
		if ui["overlay"].visible:  # cartão aberto: só Enter (ou Esc no objetivo) fecha
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER] or (event.keycode == KEY_ESCAPE and overlay_kind == "intro"):
				_on_overlay_button()
			return
		match event.keycode:
			KEY_1, KEY_A:
				set_mode("move")
			KEY_2, KEY_F:
				set_mode("shoot")
			KEY_3, KEY_SPACE:
				_on_wait()
			KEY_R:
				load_level(level_index)
			KEY_TAB:
				_cycle_selection()
			KEY_ESCAPE:
				set_mode("move")
			KEY_UP:
				_try_step(Vector2i.UP)
			KEY_DOWN:
				_try_step(Vector2i.DOWN)
			KEY_LEFT:
				_try_step(Vector2i.LEFT)
			KEY_RIGHT:
				_try_step(Vector2i.RIGHT)
			KEY_ENTER, KEY_KP_ENTER:
				if ui["overlay"].visible:
					_on_overlay_button()


func set_mode(m: String) -> void:
	if busy or board.status != "playing":
		return
	if m == "shoot":
		if board.main_unit().is_empty():
			_flash_hint("O Sobrevivente já saiu do tabuleiro.")
			return
		if board.ammo <= 0:
			_flash_hint("Sem munição!")
			return
		selected_id = board.main_unit()["id"]
	mode = m
	_refresh_ui()
	queue_redraw()


func _cycle_selection() -> void:
	if busy:
		return
	var s: Array = board.survivors()
	if s.is_empty():
		return
	var idx := 0
	for i in s.size():
		if s[i]["id"] == selected_id:
			idx = (i + 1) % s.size()
	selected_id = s[idx]["id"]
	mode = "move"
	_refresh_ui()
	queue_redraw()


func _on_cell_clicked(c: Vector2i) -> void:
	if busy or board.status != "playing" or not board.in_bounds(c):
		return
	var u: Dictionary = board.unit_at(c)
	if mode == "shoot":
		if board.shoot_targets().has(c):
			var m: Dictionary = board.main_unit()
			_do_shoot((c - m["pos"]).sign())
		elif not u.is_empty() and u["team"] == "s":
			selected_id = u["id"]
			set_mode("move")
		return
	if not u.is_empty() and u["team"] == "s":
		selected_id = u["id"]
		_refresh_ui()
		queue_redraw()
		return
	var sel: Dictionary = board.unit_by_id(selected_id)
	if sel.is_empty():
		return
	if board.valid_moves(sel).has(c):
		_do_move(sel, c)
	elif board.cell(c) == Board.DOOR and (c - sel["pos"]).abs().x <= 1 and (c - sel["pos"]).abs().y <= 1:
		_flash_hint("Porta trancada: precisa de uma chave na mochila.")
	else:
		var step := _step_toward(sel, c)
		if step != NO_CELL:
			_do_move(sel, step)
		else:
			_flash_hint("Não dá para ir para lá. Clique numa casa com bolinha verde.")


# Casa válida que mais aproxima a peça do ponto clicado (1 passo naquela direção).
func _step_toward(sel: Dictionary, target: Vector2i) -> Vector2i:
	if sel["moves"] == "knight":
		return NO_CELL  # o cavalo pula em L: só anda clicando direto na casa marcada
	var best := NO_CELL
	var best_d := Vector2(sel["pos"] - target).length()
	for p in board.valid_moves(sel):
		var d := Vector2(p - target).length()
		if d < best_d - 0.01:
			best_d = d
			best = p
	return best


func _try_step(dir: Vector2i) -> void:
	if busy or board.status != "playing":
		return
	if mode != "move":
		set_mode("move")
	var sel: Dictionary = board.unit_by_id(selected_id)
	if sel.is_empty():
		return
	var to: Vector2i = sel["pos"] + dir
	if board.valid_moves(sel).has(to):
		_do_move(sel, to)
	elif sel["moves"] == "knight":
		_flash_hint("O Cachorro anda em L: clique numa casa com bolinha verde.")
	else:
		_flash_hint("Caminho bloqueado nessa direção.")


func _update_cursor() -> void:
	var shape := Input.CURSOR_ARROW
	if not busy and board != null and board.status == "playing" and board.in_bounds(hover):
		var u: Dictionary = board.unit_at(hover)
		if not u.is_empty() and u["team"] == "s":
			shape = Input.CURSOR_POINTING_HAND
		elif mode == "shoot" and board.shoot_targets().has(hover):
			shape = Input.CURSOR_CROSS
		elif mode == "move" and board.valid_moves(board.unit_by_id(selected_id)).has(hover):
			shape = Input.CURSOR_POINTING_HAND
	Input.set_default_cursor_shape(shape)


func _on_wait() -> void:
	if busy or board.status != "playing":
		return
	board.wait_turn()
	_zombie_phase()


func _on_use_item(index: int) -> void:
	if busy or board.status != "playing":
		return
	if board.use_item(index, selected_id):
		_sync_views()
		_zombie_phase()
	else:
		var it: String = board.backpack[index] if index < board.backpack.size() else ""
		if it == "k":
			_flash_hint("A chave é usada sozinha ao entrar numa porta.")
		elif it == "h":
			_flash_hint("A vida de quem está selecionado já está cheia. Selecione outro para curar.")
		elif it == "m":
			_flash_hint("Não tem bebê para acalmar.")


# ---------- ações animadas ----------

func _do_move(sel: Dictionary, to: Vector2i) -> void:
	busy = true
	var id: int = sel["id"]
	var from: Vector2i = sel["pos"]
	var res: Dictionary = board.player_move(id, to)
	var v = views.get(id)
	if v:
		v.face(to.x - from.x)
		v.play_walk()
		await _tween_pos(v, grid_to_px(to))
		v.play_idle()
	if res.get("carried", 0) and views.has(res["carried"]):
		var baby = views[res["carried"]]
		await _tween_pos(baby, grid_to_px(to))
	if res.get("rescued", false) and v:
		var tw := create_tween()
		tw.tween_property(v, "modulate:a", 0.0, 0.25)
		tw.parallel().tween_property(v, "position:y", v.position.y - tile * 0.4, 0.25)
		await tw.finished
	_sync_views()
	await _zombie_phase()


func _do_shoot(dir: Vector2i) -> void:
	busy = true
	var res: Dictionary = board.player_shoot(dir)
	if res.is_empty():
		busy = false
		return
	var v = views.get(board.main_unit().get("id", -1))
	if v:
		v.face(dir.x)
		await v.play_shoot(board.weapon)
	tracer_arrow = res.get("arrow", false)
	tracer_from = grid_to_px(res["from"])
	tracer_to = grid_to_px(res["end"])
	tracer_alpha = 1.0
	for h in res["hits"]:
		if views.has(h["id"]):
			views[h["id"]].flash()
	for ev in res.get("explosions", []):
		await _play_fx_event(ev)
	var tw := create_tween()
	tw.tween_property(self, "tracer_alpha", 0.0, 0.3)
	await tw.finished
	_sync_views()
	mode = "move"
	await _zombie_phase()


func _zombie_phase() -> void:
	busy = true
	ui["tip"].visible = false
	_refresh_ui()
	queue_redraw()
	if board.status == "playing":
		await get_tree().create_timer(0.12).timeout
		for ev in board.run_zombie_turn():
			if await _play_fx_event(ev):
				continue
			var v = views.get(ev.get("id", -1))
			if v == null:
				continue
			if ev["type"] == "move":
				v.face(ev["to"].x - ev["from"].x)
				v.play_walk()
				await _tween_pos(v, grid_to_px(ev["to"]))
				v.play_idle()
			elif ev["type"] == "promote" or ev["type"] == "reveal":
				# troca o visual (peão virou tanque / rastejante apareceu)
				v.queue_free()
				views.erase(ev["id"])
				_sync_views()
				if views.has(ev["id"]):
					views[ev["id"]].flash()
			elif ev["type"] == "attack":
				var target_px := grid_to_px(ev["at"])
				v.face(int(signf(target_px.x - v.position.x)))
				var home: Vector2 = v.position
				v.play_attack()
				var tw := create_tween()
				tw.tween_property(v, "position", home.lerp(target_px, 0.45), 0.09)
				tw.tween_property(v, "position", home, 0.12)
				if views.has(ev["target"]):
					views[ev["target"]].flash()
				await tw.finished
				_sync_views()
	_sync_views()
	if board.unit_by_id(selected_id).is_empty():
		var s: Array = board.survivors()
		selected_id = s[0]["id"] if not s.is_empty() else -1
	mode = "move"
	busy = false
	_refresh_ui()
	queue_redraw()
	if board.status != "playing":
		_show_end()


# Efeitos dos poderes dos zumbis. Devolve true se tratou o evento.
func _play_fx_event(ev: Dictionary) -> bool:
	match ev["type"]:
		"aim":
			var v = views.get(ev["id"])
			if v:
				v.face(int(signf(ev["to"].x - ev["from"].x)))
				v.flash()
			await get_tree().create_timer(0.2).timeout
			return true
		"shoot":
			var v = views.get(ev["id"])
			var a := grid_to_px(ev["from"])
			var b := grid_to_px(ev["to"])
			if v:
				v.face(int(signf(b.x - a.x)))
				v.play_attack()
			fx.append({"kind": "shot", "a": a, "b": b, "t": 1.0,
				"color": RANGED_COLOR.get(ev["kind"], Color.WHITE)})
			await get_tree().create_timer(0.25).timeout
			for id in ev["targets"]:
				if views.has(id):
					views[id].flash()
			if ev.has("acid"):
				fx.append({"kind": "splash", "a": grid_to_px(ev["acid"]), "t": 1.0, "color": RANGED_COLOR["S"]})
			_sync_views()
			return true
		"scream":
			fx.append({"kind": "ring", "a": grid_to_px(ev["at"]), "t": 1.0, "r": (ev["range"] + 0.5) * tile,
				"color": Color(1.0, 0.95, 0.4)})
			for s in board.survivors():
				if views.has(s["id"]):
					views[s["id"]].flash()
			await get_tree().create_timer(0.35).timeout
			_sync_views()
			return true
		"explode":
			fx.append({"kind": "boom", "a": grid_to_px(ev["at"]), "t": 1.0, "color": Color(1.0, 0.55, 0.15)})
			await get_tree().create_timer(0.3).timeout
			_sync_views()
			return true
		"revive":
			fx.append({"kind": "splash", "a": grid_to_px(ev["at"]), "t": 1.0, "color": RANGED_COLOR["J"]})
			_sync_views()
			if views.has(ev["new_id"]):
				views[ev["new_id"]].flash()
			await get_tree().create_timer(0.3).timeout
			return true
		"acid":
			fx.append({"kind": "splash", "a": grid_to_px(ev["at"]), "t": 1.0, "color": RANGED_COLOR["S"]})
			if views.has(ev["target"]):
				views[ev["target"]].flash()
			await get_tree().create_timer(0.2).timeout
			_sync_views()
			return true
	return false


func _draw_fx() -> void:
	for f in fx:
		var t: float = f["t"]
		var c: Color = f["color"]
		match f["kind"]:
			"shot":  # projétil voando com rastro
				var tip: Vector2 = f["a"].lerp(f["b"], clampf((1.0 - t) * 1.6, 0.0, 1.0))
				draw_line(f["a"], tip, Color(c, 0.35 * t), 3.0)
				draw_circle(tip, tile * 0.1, Color(c, t))
			"ring":  # onda do grito
				var rr: float = f["r"] * (1.0 - t * 0.7)
				draw_arc(f["a"], rr, 0, TAU, 40, Color(c, t), 4.0)
				draw_arc(f["a"], rr * 0.6, 0, TAU, 32, Color(c, t * 0.6), 3.0)
			"boom":  # explosão 3x3
				draw_rect(Rect2(f["a"] - Vector2(tile, tile) * 1.5, Vector2(tile, tile) * 3), Color(c, 0.35 * t))
				draw_circle(f["a"], tile * (1.5 - t), Color(1, 0.9, 0.4, t))
			"splash":
				draw_circle(f["a"], tile * 0.45 * (1.4 - t * 0.4), Color(c, 0.6 * t))


func _tween_pos(v: Node2D, to: Vector2) -> void:
	var tw := create_tween()
	tw.tween_property(v, "position", to, MOVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished


func _sync_views() -> void:
	var alive := {}
	for u in board.units:
		alive[u["id"]] = true
		var v = views.get(u["id"])
		if v == null:
			v = UnitView.new()
			v.setup(u, tile)
			v.position = grid_to_px(u["pos"])
			v.z_index = 1
			add_child(v)
			views[u["id"]] = v
		v.update_from(u)
		v.position = grid_to_px(u["pos"])
		v.z_index = 1 + u["pos"].y
		v.selected = (u["id"] == selected_id and board.status == "playing")
	for id in views.keys():
		if not alive.has(id):
			views[id].die()  # zumbi com folha própria toca a animação de morte
			views.erase(id)


func _process(delta: float) -> void:
	for f in fx:
		f["t"] -= delta * 2.2
	fx = fx.filter(func(f): return f["t"] > 0.0)
	queue_redraw()  # mantém as marcações pulsando


# ---------- desenho do tabuleiro ----------

func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.09, 0.08, 0.1))
	var board_rect := Rect2(origin, Vector2(board.size) * tile)
	# moldura de madeira com coordenadas, como num tabuleiro de verdade
	var fw := 26.0
	draw_rect(board_rect.grow(fw + 4), Color(0.12, 0.08, 0.05))
	draw_rect(board_rect.grow(fw), FRAME)
	draw_rect(board_rect.grow(fw), FRAME_EDGE, false, 2.0)
	draw_rect(board_rect.grow(3), FRAME_EDGE, false, 3.0)
	var fs := 15
	for x in board.size.x:
		var letter := char(97 + x)
		var cx: float = origin.x + (x + 0.5) * tile - 5
		draw_string(font, Vector2(cx, board_rect.end.y + fw * 0.9), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, FRAME_EDGE.lightened(0.4))
	for y in board.size.y:
		var num := str(board.size.y - y)
		var cy: float = origin.y + (y + 0.5) * tile + 5
		draw_string(font, Vector2(board_rect.position.x - fw * 0.7, cy), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, FRAME_EDGE.lightened(0.4))
	draw_string(font, Vector2(board_rect.position.x, board_rect.position.y - fw * 0.3), "↑  SAÍDA  ↑",
		HORIZONTAL_ALIGNMENT_CENTER, board_rect.size.x, 14, Color(0.5, 0.95, 0.55))
	for y in board.size.y:
		for x in board.size.x:
			var p := Vector2i(x, y)
			var r := Rect2(origin + Vector2(p) * tile, Vector2(tile, tile))
			draw_rect(r, SQ_LIGHT if (x + y) % 2 == 0 else SQ_DARK)
			if y == 0:  # linha de saída
				draw_rect(r, Color(0.2, 0.8, 0.3, 0.28))
				draw_rect(Rect2(r.position, Vector2(tile, 4)), Color(0.3, 0.95, 0.4, 0.9))
			_draw_cell_content(p, r)
	_draw_highlights()
	_draw_fx()
	if tracer_alpha > 0.0:
		if tracer_arrow:  # flecha voando: rastro fino e a ponta andando
			var tip := tracer_from.lerp(tracer_to, 1.0 - tracer_alpha)
			var back := tip - (tracer_to - tracer_from).normalized() * tile * 0.45
			draw_line(tracer_from, tip, Color(1, 1, 1, 0.25 * tracer_alpha), 2.0)
			_draw_arrow(back, tip, 1.0)
		else:
			draw_line(tracer_from, tracer_to, Color(1, 0.9, 0.3, tracer_alpha), 4.0)
			draw_circle(tracer_to, tile * 0.15 * tracer_alpha, Color(1, 0.6, 0.2, tracer_alpha))


func _draw_cell_content(p: Vector2i, r: Rect2) -> void:
	var d: String = board.decor.get(p, "")
	var c := r.get_center()
	match d:
		"M":  # mesa
			var top := Rect2(r.position + Vector2(tile * 0.12, tile * 0.18), Vector2(tile * 0.76, tile * 0.5))
			draw_rect(Rect2(top.position + Vector2(tile * 0.04, top.size.y), Vector2(tile * 0.08, tile * 0.22)), Color(0.35, 0.2, 0.1))
			draw_rect(Rect2(top.end - Vector2(tile * 0.12, 0), Vector2(tile * 0.08, tile * 0.22)), Color(0.35, 0.2, 0.1))
			draw_rect(top, Color(0.55, 0.34, 0.17))
			draw_rect(top, Color(0.3, 0.18, 0.08), false, 2.0)
		"X":  # entulho
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-0.4, 0.35) * tile, c + Vector2(-0.2, -0.1) * tile, c + Vector2(0.05, 0.05) * tile,
				c + Vector2(0.2, -0.3) * tile, c + Vector2(0.42, 0.35) * tile]), Color(0.45, 0.42, 0.38))
			draw_line(c + Vector2(-0.3, 0.1) * tile, c + Vector2(0.3, -0.15) * tile, Color(0.6, 0.3, 0.2), 4.0)
		"W":  # parede
			draw_rect(r, Color(0.42, 0.22, 0.18))
			for row in 4:
				var yy := r.position.y + row * tile / 4.0
				draw_line(Vector2(r.position.x, yy), Vector2(r.end.x, yy), Color(0.25, 0.12, 0.1), 2.0)
				var off := (tile / 4.0) if row % 2 == 0 else (tile * 0.6)
				draw_line(Vector2(r.position.x + off, yy), Vector2(r.position.x + off, yy + tile / 4.0), Color(0.25, 0.12, 0.1), 2.0)
		"d":  # porta trancada
			draw_rect(r.grow(-tile * 0.06), Color(0.5, 0.32, 0.15))
			for i in 3:
				var xx := r.position.x + tile * (0.25 + i * 0.25)
				draw_line(Vector2(xx, r.position.y + 6), Vector2(xx, r.end.y - 6), Color(0.35, 0.2, 0.08), 2.0)
			draw_circle(c, tile * 0.12, Color(0.95, 0.8, 0.2))
			draw_rect(Rect2(c + Vector2(-tile * 0.03, 0), Vector2(tile * 0.06, tile * 0.12)), Color(0.2, 0.15, 0.05))
	if board.hazards.has(p):  # poça de ácido do Cuspidor
		var wob := sin(Time.get_ticks_msec() / 250.0 + p.x) * 0.04
		draw_circle(c + Vector2(0, tile * 0.1), tile * (0.36 + wob), Color(0.35, 0.85, 0.2, 0.55))
		draw_circle(c + Vector2(-tile * 0.12, tile * 0.05), tile * 0.06, Color(0.8, 1, 0.6, 0.8))
	var it: String = board.items.get(p, "")
	if it != "":
		var glow := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 300.0)
		draw_circle(c, tile * 0.3, Color(1, 0.9, 0.4, 0.12 + glow * 0.1))
		if TEX_ITEM.has(it):
			var s := tile * 0.55
			draw_texture_rect(TEX_ITEM[it], Rect2(c - Vector2(s, s) / 2, Vector2(s, s)), false)
		elif it == "b":  # arco
			var wood := Color(0.55, 0.33, 0.15)
			draw_arc(c + Vector2(-0.08, 0) * tile, tile * 0.3, -1.25, 1.25, 16, wood, maxf(3.0, tile * 0.06))
			draw_line(c + Vector2(-0.08 + 0.095, -0.285) * tile, c + Vector2(-0.08 + 0.095, 0.285) * tile, Color(0.9, 0.9, 0.85), 1.5)
			_draw_arrow(c + Vector2(-0.3, 0.0) * tile, c + Vector2(0.3, 0.0) * tile, 1.0)
			draw_string(font, c + Vector2(-0.3, 0.42) * tile, "ARCO",
				HORIZONTAL_ALIGNMENT_LEFT, -1, int(maxf(10, tile * 0.16)), Color.WHITE)
		elif it == "f":  # flecha caída
			_draw_arrow(c + Vector2(-0.25, 0.15) * tile, c + Vector2(0.25, -0.15) * tile, 1.0)
		elif Board.ITEMS[it].has("desc"):  # equipamentos e mamadeira
			_draw_gear(it, c)
		else:  # armas: desenho simples
			var col := Color(0.75, 0.75, 0.8)
			draw_rect(Rect2(c + Vector2(-0.35, -0.06) * tile, Vector2(0.6, 0.12) * tile), col)
			draw_rect(Rect2(c + Vector2(0.05, 0.0) * tile, Vector2(0.12, 0.22) * tile), Color(0.45, 0.3, 0.15))
			draw_string(font, c + Vector2(-0.35, 0.4) * tile, "RIFLE" if it == "r" else "ESCOPETA",
				HORIZONTAL_ALIGNMENT_LEFT, -1, int(maxf(10, tile * 0.16)), Color.WHITE)


# Desenho simples dos equipamentos (bonés, fita, mochilas, anel, tênis, mamadeira).
func _draw_gear(it: String, c: Vector2) -> void:
	var t := tile
	var outline := Color(0.1, 0.08, 0.08)
	var label := ""
	match it:
		"1", "2", "3":  # boné: copa + aba
			var col: Color = {"1": Color(0.95, 0.95, 0.92), "2": Color(0.25, 0.7, 0.3), "3": Color(0.15, 0.15, 0.17)}[it]
			draw_circle(c + Vector2(0, 0.02) * t, t * 0.2, outline)
			draw_circle(c + Vector2(0, 0.02) * t, t * 0.18, col)
			draw_rect(Rect2(c + Vector2(-0.18, 0.02) * t, Vector2(0.36, 0.1) * t), col)  # base da copa
			draw_rect(Rect2(c + Vector2(0.0, 0.1) * t, Vector2(0.34, 0.07) * t), col.darkened(0.25))  # aba
			draw_rect(Rect2(c + Vector2(0.0, 0.1) * t, Vector2(0.34, 0.07) * t), outline, false, 1.0)
			label = "BONÉ"
		"v":  # fita vermelha: laço
			var red := Color(0.9, 0.12, 0.12)
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(-0.28, -0.16) * t, c + Vector2(-0.28, 0.16) * t]), red)
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(0.28, -0.16) * t, c + Vector2(0.28, 0.16) * t]), red)
			draw_line(c, c + Vector2(-0.12, 0.3) * t, red, maxf(3.0, t * 0.06))
			draw_line(c, c + Vector2(0.12, 0.3) * t, red, maxf(3.0, t * 0.06))
			draw_circle(c, t * 0.06, red.darkened(0.3))
			label = "FITA"
		"u", "y":  # mochila
			var col := Color(0.55, 0.36, 0.2) if it == "u" else Color(0.3, 0.4, 0.2)
			var body := Rect2(c + Vector2(-0.2, -0.18) * t, Vector2(0.4, 0.42) * t)
			draw_rect(body, col)
			draw_rect(Rect2(body.position, Vector2(body.size.x, body.size.y * 0.35)), col.darkened(0.25))
			draw_rect(body, outline, false, 1.5)
			draw_arc(c + Vector2(0, -0.18) * t, t * 0.1, PI, TAU, 8, outline, 2.0)
			label = "MOCHILA" if it == "u" else "MILITAR"
		"o":  # anel dourado com pedra
			draw_arc(c + Vector2(0, 0.04) * t, t * 0.17, 0, TAU, 20, Color(0.95, 0.78, 0.2), maxf(3.0, t * 0.07))
			draw_circle(c + Vector2(0, -0.14) * t, t * 0.08, Color(0.6, 0.2, 0.9))
			label = "ANEL"
		"t":  # tênis branco
			draw_rect(Rect2(c + Vector2(-0.26, 0.0) * t, Vector2(0.52, 0.14) * t), Color(0.95, 0.95, 0.95))
			draw_rect(Rect2(c + Vector2(-0.26, -0.16) * t, Vector2(0.24, 0.18) * t), Color(0.95, 0.95, 0.95))
			draw_rect(Rect2(c + Vector2(-0.26, 0.1) * t, Vector2(0.52, 0.05) * t), Color(0.6, 0.6, 0.65))
			draw_rect(Rect2(c + Vector2(-0.26, -0.16) * t, Vector2(0.52, 0.31) * t), outline, false, 1.0)
			label = "TÊNIS"
		"m":  # mamadeira
			draw_rect(Rect2(c + Vector2(-0.1, -0.1) * t, Vector2(0.2, 0.32) * t), Color(0.95, 0.97, 1.0))
			draw_rect(Rect2(c + Vector2(-0.1, 0.06) * t, Vector2(0.2, 0.16) * t), Color(1.0, 0.98, 0.85))
			draw_rect(Rect2(c + Vector2(-0.11, -0.15) * t, Vector2(0.22, 0.06) * t), Color(0.4, 0.7, 1.0))
			draw_circle(c + Vector2(0, -0.2) * t, t * 0.05, Color(0.95, 0.75, 0.55))
			draw_rect(Rect2(c + Vector2(-0.1, -0.1) * t, Vector2(0.2, 0.32) * t), outline, false, 1.0)
			label = "MAMADEIRA"
	draw_string(font, c + Vector2(-0.45, 0.44) * t, label, HORIZONTAL_ALIGNMENT_CENTER, t * 0.9,
		int(maxf(9, t * 0.14)), Color.WHITE)


# Linhas vermelhas: zumbis que estão mirando e vão atirar na próxima rodada.
func _draw_aims(pulse: float) -> void:
	for z in board.zombies():
		if z.has("aim_area"):  # Gritador vai gritar: área em volta
			for p in board.ranged_threat(z):
				var ra := Rect2(origin + Vector2(p) * tile, Vector2(tile, tile))
				draw_rect(ra, Color(1, 0.15, 0.1, 0.12 + 0.12 * pulse))
				draw_rect(ra.grow(-3), Color(1, 0.3, 0.2, 0.6), false, 2.0)
		if not z.has("aim"):
			continue
		var d: Vector2i = z["aim"]
		var r: Dictionary = z["ranged"]
		for i in range(1, int(r["range"]) + 1):
			var p: Vector2i = z["pos"] + d * i
			if not board.in_bounds(p) or board.cell(p) != Board.FLOOR:
				break
			var rr := Rect2(origin + Vector2(p) * tile, Vector2(tile, tile))
			draw_rect(rr, Color(1, 0.1, 0.1, 0.15 + 0.15 * pulse))
			draw_rect(rr.grow(-3), Color(1, 0.2, 0.2, 0.8), false, 2.0)
			var u: Dictionary = board.unit_at(p)
			if not u.is_empty() and (u["team"] == "z" or not r.get("pierce", false)):
				break
		var a := grid_to_px(z["pos"])
		draw_line(a, a + Vector2(d) * tile * 0.6, Color(1, 0.2, 0.2, 0.9), 3.0)


func _draw_arrow(from: Vector2, to: Vector2, a: float) -> void:
	var d := (to - from).normalized()
	var n := Vector2(-d.y, d.x)
	var head := tile * 0.1
	draw_line(from, to, Color(0.5, 0.32, 0.15, a), maxf(2.0, tile * 0.035))
	draw_colored_polygon(PackedVector2Array([to + d * head * 0.6, to - d * head + n * head * 0.6, to - d * head - n * head * 0.6]), Color(0.8, 0.8, 0.85, a))
	draw_line(from, from + d * head - n * head * 0.7, Color(0.9, 0.3, 0.25, a), 2.0)
	draw_line(from, from + d * head + n * head * 0.7, Color(0.9, 0.3, 0.25, a), 2.0)


func _draw_highlights() -> void:
	if busy or board.status != "playing":
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 220.0)
	_draw_aims(pulse)
	var sel: Dictionary = board.unit_by_id(selected_id)
	if not sel.is_empty():  # casa da peça selecionada em amarelo
		var sr := Rect2(origin + Vector2(sel["pos"]) * tile, Vector2(tile, tile))
		draw_rect(sr, Color(1.0, 0.85, 0.15, 0.45))
		draw_rect(sr.grow(-2), Color(1.0, 0.8, 0.1, 0.95), false, 4.0)
	if mode == "move":
		if not sel.is_empty():
			for p in board.valid_moves(sel):
				var r := Rect2(origin + Vector2(p) * tile, Vector2(tile, tile))
				var c := r.get_center()
				if p == hover:
					draw_rect(r, Color(0.2, 0.85, 0.3, 0.55))
					draw_rect(r.grow(-2), Color(0.1, 0.6, 0.2, 1.0), false, 4.0)
				else:
					draw_rect(r, Color(0.2, 0.85, 0.3, 0.12 + 0.12 * pulse))
				# bolinha verde estilo xadrez online
				draw_circle(c, tile * (0.15 + 0.03 * pulse), Color(0.05, 0.45, 0.15, 0.85))
				draw_circle(c, tile * 0.09, Color(0.4, 1.0, 0.5, 0.95))
	else:
		for p in board.shoot_targets():
			var r := Rect2(origin + Vector2(p) * tile, Vector2(tile, tile)).grow(-4)
			var z: Dictionary = board.unit_at(p)
			var a := 0.45 if (not z.is_empty() and z["team"] == "z") else 0.18
			draw_rect(r, Color(1, 0.25, 0.2, a))
			draw_rect(r, Color(1, 0.3, 0.25, 0.8), false, 2.0)
	# zumbis que podem morder a casa sob o mouse
	if board.in_bounds(hover):
		draw_rect(Rect2(origin + Vector2(hover) * tile, Vector2(tile, tile)), Color(1, 1, 1, 0.6), false, 2.0)
		var hz: Dictionary = board.unit_at(hover)
		if not hz.is_empty() and hz["team"] == "z":
			for p in board.ranged_threat(hz):  # alcance do ataque de longe
				draw_rect(Rect2(origin + Vector2(p) * tile, Vector2(tile, tile)).grow(-6), Color(0.85, 0.2, 1.0, 0.18))
			for d in board.attack_dirs(hz):
				var p: Vector2i = hover + d
				if board.in_bounds(p):
					draw_rect(Rect2(origin + Vector2(p) * tile, Vector2(tile, tile)).grow(-10), Color(1, 0.4, 0.1, 0.5), false, 2.0)


# ---------- interface ----------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.12, 0.14, 0.92)
	sb.border_color = Color(0.35, 0.3, 0.25)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(12)
	sb.set_corner_radius_all(6)

	# --- painel esquerdo: situação do jogo ---
	var left := _panel(layer, sb, LEFT_PANEL)
	ui["level"] = _label(left, "", 17, Color(1, 0.85, 0.5))
	ui["turn"] = _label(left, "", 14, Color(0.75, 0.75, 0.8))
	left.add_child(HSeparator.new())
	ui["hp"] = _label(left, "", 18, Color(1, 0.55, 0.55))
	ui["hp_bar"] = ProgressBar.new()
	ui["hp_bar"].show_percentage = false
	ui["hp_bar"].custom_minimum_size = Vector2(0, 10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.25, 0.25)
	ui["hp_bar"].add_theme_stylebox_override("fill", fill)
	left.add_child(ui["hp_bar"])
	ui["weapon"] = _label(left, "", 14, Color.WHITE)
	ui["gear"] = _label(left, "", 13, Color(0.6, 0.9, 1.0))
	left.add_child(HSeparator.new())
	ui["selected"] = _label(left, "", 13, Color(0.8, 0.9, 1.0))
	ui["hint"] = _label(left, "", 13, Color(1, 0.9, 0.4))
	left.add_child(HSeparator.new())
	ui["log"] = _label(left, "", 12, Color(0.7, 0.7, 0.7))
	ui["log"].size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui["log"].vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

	# --- painel direito: ações e mochila ---
	var right := _panel(layer, sb, RIGHT_PANEL)
	ui["btn_move"] = _button(right, "1  Andar", func(): set_mode("move"))
	ui["btn_shoot"] = _button(right, "2  Atirar", func(): set_mode("shoot"))
	ui["btn_wait"] = _button(right, "3  Esperar", _on_wait)
	_button(right, "R  Reiniciar", func(): load_level(level_index))
	_button(right, "?  Objetivo da fase", _show_intro)
	right.add_child(HSeparator.new())
	ui["bag_label"] = _label(right, "Mochila", 15, Color(0.9, 0.8, 0.6))
	ui["bag"] = GridContainer.new()
	ui["bag"].columns = 3
	ui["bag"].add_theme_constant_override("h_separation", 6)
	ui["bag"].add_theme_constant_override("v_separation", 6)
	right.add_child(ui["bag"])
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	_label(right, "Clique numa peça para selecionar. Tab troca de peça. Passe o mouse numa peça para ver detalhes.", 11, Color(0.55, 0.55, 0.6))

	# --- balão de informações perto do mouse ---
	var tip := PanelContainer.new()
	var tsb := sb.duplicate()
	tsb.bg_color = Color(0.05, 0.05, 0.07, 0.94)
	tsb.set_content_margin_all(8)
	tip.add_theme_stylebox_override("panel", tsb)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.custom_minimum_size = Vector2(260, 0)
	layer.add_child(tip)
	ui["tip_text"] = _label(tip, "", 13, Color.WHITE)
	ui["tip_text"].custom_minimum_size.x = 244
	ui["tip"] = tip
	tip.visible = false

	# --- cartão no centro: objetivo da fase e fim de fase ---
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ov)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)  # bloqueia cliques no tabuleiro enquanto o cartão está aberto
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(center)
	var card := PanelContainer.new()
	var osb := sb.duplicate()
	osb.bg_color = Color(0.07, 0.07, 0.09, 0.98)
	osb.set_content_margin_all(28)
	card.add_theme_stylebox_override("panel", osb)
	card.custom_minimum_size = Vector2(520, 0)
	center.add_child(card)
	var ovb := VBoxContainer.new()
	ovb.add_theme_constant_override("separation", 14)
	card.add_child(ovb)
	ui["ov_title"] = _label(ovb, "", 28, Color.WHITE)
	ui["ov_text"] = _label(ovb, "", 16, Color(0.85, 0.85, 0.85))
	ui["ov_button"] = _button(ovb, "", _on_overlay_button)
	ui["ov_button"].alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui["overlay"] = ov
	ov.visible = false


func _panel(layer: Node, sb: StyleBox, rect: Rect2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.custom_minimum_size = rect.size
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	return vb


func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 100
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 36)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _refresh_ui() -> void:
	var lv: Dictionary = Levels.LEVELS[level_index]
	ui["level"].text = "Fase %d/%d\n%s" % [level_index + 1, Levels.LEVELS.size(), lv["name"]]
	ui["turn"].text = "Rodada %d" % board.turn
	var m: Dictionary = board.main_unit()
	var w: Dictionary = board.weapon_info()
	if m.is_empty():
		ui["hp"].text = "Sobrevivente fora do tabuleiro"
		ui["hp_bar"].value = 0
	else:
		ui["hp"].text = "♥ %d/%d" % [maxi(m["hp"], 0), m["max_hp"]]
		ui["hp_bar"].max_value = m["max_hp"]
		ui["hp_bar"].value = maxi(m["hp"], 0)
	ui["weapon"].text = "%s — alcance %d, dano %d%s\nMunição: %d" % [
		w["name"], w["range"], w["dmg"], ", atravessa" if w["pierce"] else "", board.ammo]
	var gear: Array = board.equipped.map(func(it): return "• " + Board.ITEMS[it]["name"])
	if board.calm > 0:
		gear.append("• bebê quieto por %d rodada(s)" % board.calm)
	ui["gear"].text = "\n".join(gear)
	ui["gear"].visible = not gear.is_empty()
	var sel: Dictionary = board.unit_by_id(selected_id)
	var move_names := {"king": "1 casa em qualquer direção", "wazir": "1 casa reta", "knight": "em L, pulando obstáculos"}
	var walk_txt: String = move_names[sel["moves"]] if not sel.is_empty() else ""
	if not sel.is_empty() and sel["main"] and board.reach > 1:
		walk_txt = "até %d casas em qualquer direção" % board.reach
	ui["selected"].text = "" if sel.is_empty() else "Selecionado: %s\nvida %d/%d — anda %s" % [
		sel["name"], sel["hp"], sel["max_hp"], walk_txt]
	ui["btn_move"].modulate = Color(0.6, 1, 0.6) if mode == "move" else Color.WHITE
	ui["btn_shoot"].modulate = Color(1, 0.6, 0.6) if mode == "shoot" else Color.WHITE
	ui["btn_shoot"].disabled = busy or m.is_empty() or board.ammo <= 0
	if busy:
		ui["hint"].text = "Os zumbis estão se movendo..."
	elif mode == "shoot":
		ui["hint"].text = "Clique numa casa vermelha para atirar. Botão direito cancela."
	else:
		ui["hint"].text = "Sua vez! Ande (bolinha verde), atire, espere ou use um item."
	# mochila
	for c in ui["bag"].get_children():
		c.queue_free()
	ui["bag_label"].text = "Mochila (%d/%d)" % [board.backpack.size(), board.bag_capacity]
	for i in board.bag_capacity:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(64, 64)
		b.expand_icon = true
		if i < board.backpack.size():
			var it: String = board.backpack[i]
			b.icon = TEX_ITEM.get(it)
			if b.icon == null:
				b.text = Board.ITEMS[it]["name"].left(5)
			b.tooltip_text = Board.ITEMS[it]["name"]
			b.pressed.connect(_on_use_item.bind(i))
		else:
			b.disabled = true
		ui["bag"].add_child(b)
	var lines: Array = board.log_lines.slice(maxi(0, board.log_lines.size() - 5))
	ui["log"].text = "\n".join(lines)


# Balão perto do mouse com a vida e os poderes da peça.
func _show_hover_info() -> void:
	ui["tip"].visible = false
	if busy or board.status != "playing" or not board.in_bounds(hover) or ui["overlay"].visible:
		return
	var u: Dictionary = board.unit_at(hover)
	if u.is_empty():
		var it: String = board.items.get(hover, "")
		if it != "":
			var d: Dictionary = Board.ITEMS[it]
			_show_tip(d["name"] + (": " + d["desc"] if d.has("desc") else ""))
		return
	if u["team"] == "s":
		_show_tip("%s — vida %d/%d. Com vida 0 morre e vira zumbi." % [u["name"], u["hp"], u["max_hp"]])
		return
	if u.get("hidden", false):
		_show_tip("Tem alguma coisa escondida ali... chegue a 2 casas e ela acorda.")
		return
	var how := {"king": "1 casa em qualquer direção", "wazir": "1 casa reta", "knight": "em L",
		"ferz": "1 casa na diagonal", "pawn": "1 casa para baixo e morde na diagonal da frente",
		"rook2": "até 2 casas em linha reta", "rook3": "até 3 casas em linha reta (investida, empurra)"}
	var extra := " (age a cada %d rodadas)" % u["every"] if u["every"] > 1 else ""
	var walk: String = how.get(u["moves"], "")
	if walk == "":
		var names := {"rook": "em linha reta", "bishop": "na diagonal", "queen": "em qualquer linha"}
		for k in names:
			if u["moves"].begins_with(k):
				walk = "até %d casas %s" % [board.move_range(u["moves"]), names[k]]
	var txt := "%s — vida %d/%d\nAnda %s%s. Laranja = mordida." % [u["name"], u["hp"], u["max_hp"], walk, extra]
	var r: Dictionary = u.get("ranged", {})
	if not r.is_empty():
		txt += "\nRoxo = ataque de longe (%d casas%s)." % [r["range"], ", atravessa" if r.get("pierce", false) else ""]
	var powers := {"acid": "deixa ácido no chão", "drops": "larga munição ao morrer",
		"revive": "levanta zumbis abatidos", "aura": "zumbis perto dela agem 2 vezes",
		"calls": "o grito chama os zumbis", "coward": "foge se você chega perto",
		"explodes": "explode em volta (até quando morre)"}
	for k in powers:
		if u.has(k):
			txt += "\nPoder: " + powers[k] + "."
	_show_tip(txt)


func _show_tip(txt: String) -> void:
	var tip: PanelContainer = ui["tip"]
	ui["tip_text"].text = txt
	tip.reset_size()
	tip.visible = true
	# ao lado da casa, sem sair da tela
	var cell_r := Rect2(origin + Vector2(hover) * tile, Vector2(tile, tile))
	var pos := Vector2(cell_r.end.x + 8, cell_r.position.y)
	if pos.x + tip.size.x > 1270:
		pos.x = cell_r.position.x - tip.size.x - 8
	pos.y = clampf(pos.y, 8, 712 - tip.size.y)
	tip.position = pos


func _flash_hint(msg: String) -> void:
	ui["hint"].text = msg


# Cartão com o objetivo da fase (aparece ao entrar na fase e no botão "?").
func _show_intro() -> void:
	if busy:
		return
	var lv: Dictionary = Levels.LEVELS[level_index]
	overlay_kind = "intro"
	ui["ov_title"].text = "Fase %d: %s" % [level_index + 1, lv["name"]]
	ui["ov_title"].add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	ui["ov_text"].text = lv["intro"]
	ui["ov_button"].text = "Começar  (Enter)"
	ui["tip"].visible = false
	ui["overlay"].visible = true


func _show_end() -> void:
	var won: bool = board.status == "won"
	var last: bool = level_index == Levels.LEVELS.size() - 1
	overlay_kind = "end"
	ui["ov_title"].text = ("Fase concluída!" if not last else "Você venceu o jogo!") if won else "Fim de jogo"
	ui["ov_title"].add_theme_color_override("font_color", Color(0.5, 1, 0.5) if won else Color(1, 0.4, 0.4))
	ui["ov_text"].text = board.end_reason
	ui["ov_button"].text = ("Próxima fase  (Enter)" if not last else "Jogar de novo  (Enter)") if won else "Tentar de novo  (Enter)"
	ui["tip"].visible = false
	ui["overlay"].visible = true


func _on_overlay_button() -> void:
	if overlay_kind == "intro":
		ui["overlay"].visible = false
		return
	if board.status == "won":
		load_level((level_index + 1) % Levels.LEVELS.size(), true)
	else:
		load_level(level_index)
