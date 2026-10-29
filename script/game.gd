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

const BOARD_AREA := Rect2(50, 72, 610, 610)
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
var ui := {}
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
	load_level(level_index)
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

func load_level(i: int) -> void:
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
	_sync_views()
	_refresh_ui()
	queue_redraw()


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
	if board.use_item(index):
		_sync_views()
		_zombie_phase()
	else:
		var it: String = board.backpack[index] if index < board.backpack.size() else ""
		if it == "k":
			_flash_hint("A chave é usada sozinha ao entrar numa porta.")
		elif it == "h":
			_flash_hint("Vida já está cheia.")


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
	var tw := create_tween()
	tw.tween_property(self, "tracer_alpha", 0.0, 0.3)
	await tw.finished
	_sync_views()
	mode = "move"
	await _zombie_phase()


func _zombie_phase() -> void:
	busy = true
	_refresh_ui()
	queue_redraw()
	if board.status == "playing":
		await get_tree().create_timer(0.12).timeout
		for ev in board.run_zombie_turn():
			var v = views.get(ev["id"])
			if v == null:
				continue
			if ev["type"] == "move":
				v.face(ev["to"].x - ev["from"].x)
				await _tween_pos(v, grid_to_px(ev["to"]))
			elif ev["type"] == "attack":
				var target_px := grid_to_px(ev["at"])
				v.face(int(signf(target_px.x - v.position.x)))
				var home: Vector2 = v.position
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
			views[id].queue_free()
			views.erase(id)


func _process(_delta: float) -> void:
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
	draw_string(font, Vector2(origin.x, board_rect.position.y - fw - 12), "SAÍDA  ↑  leve todos até a linha de cima",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.95, 0.55))
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
		else:  # armas: desenho simples
			var col := Color(0.75, 0.75, 0.8)
			draw_rect(Rect2(c + Vector2(-0.35, -0.06) * tile, Vector2(0.6, 0.12) * tile), col)
			draw_rect(Rect2(c + Vector2(0.05, 0.0) * tile, Vector2(0.12, 0.22) * tile), Color(0.45, 0.3, 0.15))
			draw_string(font, c + Vector2(-0.35, 0.4) * tile, "RIFLE" if it == "r" else "ESCOPETA",
				HORIZONTAL_ALIGNMENT_LEFT, -1, int(maxf(10, tile * 0.16)), Color.WHITE)


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
			for d in board.dirs_for(hz["moves"]):
				var p: Vector2i = hover + d
				if board.in_bounds(p):
					draw_rect(Rect2(origin + Vector2(p) * tile, Vector2(tile, tile)).grow(-10), Color(1, 0.4, 0.1, 0.5), false, 2.0)


# ---------- interface ----------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(700, 20)
	panel.custom_minimum_size = Vector2(560, 680)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.12, 0.14)
	sb.border_color = Color(0.35, 0.3, 0.25)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(16)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	ui["title"] = _label(vb, "ZUMDREX — Xadrez Zumbi", 26, Color(0.6, 1.0, 0.5))
	ui["level"] = _label(vb, "", 18, Color(1, 0.85, 0.5))
	ui["intro"] = _label(vb, "", 14, Color(0.85, 0.85, 0.85))
	vb.add_child(HSeparator.new())
	ui["stats"] = _label(vb, "", 16, Color.WHITE)
	ui["selected"] = _label(vb, "", 14, Color(0.8, 0.9, 1.0))

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	vb.add_child(hb)
	ui["btn_move"] = _button(hb, "1  Andar", func(): set_mode("move"))
	ui["btn_shoot"] = _button(hb, "2  Atirar", func(): set_mode("shoot"))
	ui["btn_wait"] = _button(hb, "3  Esperar", _on_wait)
	_button(hb, "R  Reiniciar", func(): load_level(level_index))
	ui["hint"] = _label(vb, "", 14, Color(1, 0.9, 0.4))

	vb.add_child(HSeparator.new())
	ui["bag_label"] = _label(vb, "Mochila", 16, Color(0.9, 0.8, 0.6))
	ui["bag"] = HBoxContainer.new()
	ui["bag"].add_theme_constant_override("separation", 6)
	vb.add_child(ui["bag"])

	vb.add_child(HSeparator.new())
	ui["log"] = _label(vb, "", 13, Color(0.75, 0.75, 0.75))
	ui["log"].size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label(vb, "Clique numa peça sua para selecionar. Passe o mouse num zumbi para ver onde ele morde. Tab troca de peça.", 12, Color(0.55, 0.55, 0.6))

	# janela de fim de fase
	var ov := PanelContainer.new()
	var osb := sb.duplicate()
	osb.bg_color = Color(0.05, 0.05, 0.07, 0.95)
	osb.set_content_margin_all(28)
	ov.add_theme_stylebox_override("panel", osb)
	ov.position = Vector2(150, 260)
	ov.custom_minimum_size = Vector2(400, 0)
	layer.add_child(ov)
	var ovb := VBoxContainer.new()
	ovb.add_theme_constant_override("separation", 14)
	ov.add_child(ovb)
	ui["ov_title"] = _label(ovb, "", 28, Color.WHITE)
	ui["ov_text"] = _label(ovb, "", 16, Color(0.85, 0.85, 0.85))
	ui["ov_button"] = _button(ovb, "", _on_overlay_button)
	ui["overlay"] = ov
	ov.visible = false


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
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _refresh_ui() -> void:
	var lv: Dictionary = Levels.LEVELS[level_index]
	ui["level"].text = "Fase %d/%d: %s   •   Rodada %d" % [level_index + 1, Levels.LEVELS.size(), lv["name"], board.turn]
	ui["intro"].text = lv["intro"]
	var m: Dictionary = board.main_unit()
	var w: Dictionary = board.weapon_info()
	var hp_txt := "fora do tabuleiro" if m.is_empty() else "♥".repeat(m["hp"]) + "♡".repeat(m["max_hp"] - m["hp"])
	ui["stats"].text = "Vida: %s     Arma: %s (alcance %d, dano %d%s)     Munição: %d" % [
		hp_txt, w["name"], w["range"], w["dmg"], ", atravessa" if w["pierce"] else "", board.ammo]
	var sel: Dictionary = board.unit_by_id(selected_id)
	var move_names := {"king": "1 casa em qualquer direção (rei)", "wazir": "1 casa reta", "knight": "em L, pulando obstáculos (cavalo)"}
	ui["selected"].text = "" if sel.is_empty() else "Selecionado: %s — anda %s" % [sel["name"], move_names[sel["moves"]]]
	ui["btn_move"].button_pressed = false
	ui["btn_move"].modulate = Color(0.6, 1, 0.6) if mode == "move" else Color.WHITE
	ui["btn_shoot"].modulate = Color(1, 0.6, 0.6) if mode == "shoot" else Color.WHITE
	ui["btn_shoot"].disabled = busy or m.is_empty() or board.ammo <= 0
	if busy:
		ui["hint"].text = "Os zumbis estão se movendo..."
	elif mode == "shoot":
		ui["hint"].text = "Clique numa casa vermelha para atirar naquela direção. (botão direito cancela)"
	else:
		ui["hint"].text = "Sua vez! Clique numa casa com bolinha verde (ou use as setas) para andar. Ou atire, espere ou use um item."
	# mochila
	for c in ui["bag"].get_children():
		c.queue_free()
	ui["bag_label"].text = "Mochila (%d/%d) — clique num item para usar" % [board.backpack.size(), board.bag_capacity]
	for i in board.bag_capacity:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(64, 64)
		b.expand_icon = true
		if i < board.backpack.size():
			var it: String = board.backpack[i]
			b.icon = TEX_ITEM.get(it)
			b.tooltip_text = Board.ITEMS[it]["name"]
			b.pressed.connect(_on_use_item.bind(i))
		else:
			b.disabled = true
		ui["bag"].add_child(b)
	var lines: Array = board.log_lines.slice(maxi(0, board.log_lines.size() - 8))
	ui["log"].text = "\n".join(lines)


func _show_hover_info() -> void:
	if busy or board.status != "playing" or not board.in_bounds(hover):
		return
	var u: Dictionary = board.unit_at(hover)
	if u.is_empty() or u["team"] != "z":
		return
	var how := {"king": "1 casa em qualquer direção", "wazir": "1 casa reta", "knight": "em L"}
	var extra := " (age a cada %d rodadas)" % u["every"] if u["every"] > 1 else ""
	ui["hint"].text = "%s — vida %d/%d — anda %s%s. Casas laranja = onde ele morde." % [
		u["name"], u["hp"], u["max_hp"], how[u["moves"]], extra]


func _flash_hint(msg: String) -> void:
	ui["hint"].text = msg


func _show_end() -> void:
	var won: bool = board.status == "won"
	var last: bool = level_index == Levels.LEVELS.size() - 1
	ui["ov_title"].text = ("Fase concluída!" if not last else "Você venceu o jogo!") if won else "Fim de jogo"
	ui["ov_title"].add_theme_color_override("font_color", Color(0.5, 1, 0.5) if won else Color(1, 0.4, 0.4))
	ui["ov_text"].text = board.end_reason
	ui["ov_button"].text = ("Próxima fase  (Enter)" if not last else "Jogar de novo  (Enter)") if won else "Tentar de novo  (Enter)"
	ui["overlay"].visible = true


func _on_overlay_button() -> void:
	if board.status == "won":
		load_level((level_index + 1) % Levels.LEVELS.size())
	else:
		load_level(level_index)
