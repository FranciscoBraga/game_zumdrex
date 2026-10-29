extends Node2D
# Visual de uma peça no tabuleiro. Sobrevivente e zumbis usam folhas de
# sprites geradas no Gemini e recortadas com tools/slice_gemini_sheet.py.

const PLAYER_TEX = preload("res://assets/characters/survivor.png")
# survivor.png: 6 colunas x 16 linhas, quadros de 48x48 (gerado pelo Gemini,
# recortado com tools/slice_gemini_sheet.py). Linhas usadas:
const ROW_IDLE := 1    # parado, de lado
const ROW_WALK := 4    # andando, de lado
const ROW_SHOOT := {"pistol": 6, "bow": 9, "rifle": 12, "shotgun": 12}
const SHOOT_FRAMES := 3

# Folha própria de cada zumbi (gerada no Gemini): assets/zombies/<letra>.png
# 6 colunas x 3 linhas de 48x48: andando (6), atacando (4), morrendo (3).
const ZOMBIE_SHEET_DIR := "res://assets/zombies/"
const Z_WALK := 0
const Z_ATTACK := 1
const Z_DEATH := 2
const Z_LEN := [6, 4, 3]
var unit_id := 0
var type := ""
var team := ""
var tile := 64.0
var hp := 1
var max_hp := 1
var selected := false
var carrying := false
var is_hidden := false
var stunned := false
var sprite: Sprite2D
var _t := 0.0
var _flash := 0.0
var anim_row := ROW_IDLE
var anim_t := 0.0
var anim_once := false  # true = toca uma vez (tiro/ataque) e volta para parado
var anim_len := 6
var anim_fps := 6.0
var has_sheet := false  # zumbi com folha própria do Gemini
var dying := false


func setup(u: Dictionary, tile_size: float) -> void:
	unit_id = u["id"]
	type = u["type"]
	team = u["team"]
	tile = tile_size
	if type == "P" or team == "z":
		sprite = Sprite2D.new()
		var s := tile / 48.0 * 1.6
		if type == "P":
			sprite.texture = PLAYER_TEX
			sprite.hframes = 6
			sprite.vframes = 16
		else:
			has_sheet = true
			sprite.texture = load(ZOMBIE_SHEET_DIR + type + ".png")
			sprite.hframes = 6
			sprite.vframes = 3
			_set_anim(Z_WALK, false, 4.0)
		sprite.scale = Vector2(s, s)
		sprite.position = Vector2(0, -tile * 0.26)
		add_child(sprite)
	update_from(u)
	_t = randf() * 3.0


func update_from(u: Dictionary) -> void:
	hp = u["hp"]
	max_hp = u["max_hp"]
	carrying = u.has("carrying")
	is_hidden = u.get("hidden", false)
	stunned = u.get("stun", 0) > 0
	if sprite:
		sprite.visible = not is_hidden
	queue_redraw()


func face(dx: int) -> void:
	if sprite and dx != 0:
		# sprites originais olham para a direita
		sprite.flip_h = dx < 0


func _set_anim(row: int, once: bool, fps: float) -> void:
	anim_row = row
	anim_once = once
	anim_fps = fps
	anim_t = 0.0
	if type == "P":
		anim_len = SHOOT_FRAMES if once else 6
	else:
		anim_len = Z_LEN[row]


func play_walk() -> void:
	if type == "P":
		_set_anim(ROW_WALK, false, 12.0)
	elif has_sheet:
		_set_anim(Z_WALK, false, 12.0)


func play_idle() -> void:
	if type == "P":
		_set_anim(ROW_IDLE, false, 6.0)
	elif has_sheet:
		_set_anim(Z_WALK, false, 4.0)  # zumbi parado cambaleia devagar


# toca a animação de tiro da arma e espera ela terminar
func play_shoot(weapon: String) -> void:
	if type != "P":
		return
	_set_anim(ROW_SHOOT.get(weapon, ROW_SHOOT["pistol"]), true, 10.0)
	await get_tree().create_timer(SHOOT_FRAMES / 10.0).timeout


# zumbi atacando (mordida ou ataque de longe)
func play_attack() -> void:
	if has_sheet:
		_set_anim(Z_ATTACK, true, 12.0)


# zumbi morrendo: toca a animação e some
func die() -> void:
	if not has_sheet or dying:
		queue_free()
		return
	dying = true
	# o Inchado morre explodindo (a "explosão" é a linha de ataque dele)
	var row := Z_ATTACK if type == "I" else Z_DEATH
	_set_anim(row, true, 8.0)
	await get_tree().create_timer(Z_LEN[row] / 8.0 + 0.35).timeout
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	await tw.finished
	queue_free()


func flash() -> void:
	_flash = 0.35


func _process(delta: float) -> void:
	_t += delta
	if sprite:
		anim_t += delta
		var f := int(anim_t * anim_fps)
		if anim_once:
			if f >= anim_len + 2 and not dying:  # segura o último quadro um instante
				play_idle()
			else:
				sprite.frame = anim_row * 6 + mini(f, anim_len - 1)
		else:
			sprite.frame = anim_row * 6 + f % anim_len
		if _flash > 0.0:
			_flash -= delta
			sprite.self_modulate = Color(3, 1, 1) if _flash > 0.0 else Color.WHITE
	elif _flash > 0.0:
		_flash -= delta
	queue_redraw()


func _draw() -> void:
	var r := tile * 0.5
	if is_hidden:  # Rastejante escondido: só uma mancha escura que se mexe
		var w := 1.0 + sin(_t * 3.0) * 0.08
		draw_circle(Vector2(0, r * 0.3), r * 0.42 * w, Color(0.05, 0.08, 0.05, 0.55))
		draw_circle(Vector2(r * 0.15, r * 0.2), r * 0.06, Color(0.9, 0.2, 0.2, 0.5 + 0.4 * sin(_t * 5.0)))
		return
	# sombra
	draw_circle(Vector2(0, r * 0.62), r * 0.38, Color(0, 0, 0, 0.35))
	if stunned:  # estrelinhas de tontura
		for i in 3:
			var a := _t * 3.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * r * 0.35, -r * 0.75 + sin(a) * r * 0.1), r * 0.07, Color(1, 0.95, 0.3))
	if selected:
		draw_arc(Vector2(0, r * 0.55), r * 0.6, 0, TAU, 32, Color(1, 0.9, 0.2), 3.0)
	var bob := sin(_t * 4.0) * 2.0
	match type:
		"D":
			_draw_dog(r, bob)
		"B":
			_draw_baby(Vector2(0, -r * 0.05 + bob), r)
	if carrying:
		_draw_baby(Vector2(r * 0.45, r * 0.1), r * 0.6)
	if _flash > 0.0 and not sprite:
		draw_circle(Vector2.ZERO, r * 0.5, Color(1, 0.2, 0.2, 0.5))
	# vida
	if max_hp > 1 or team == "s":
		var w := tile * 0.7
		var y := -r * 0.92
		draw_rect(Rect2(-w / 2, y, w, 6), Color(0, 0, 0, 0.7))
		var c := Color(0.3, 0.9, 0.3) if team == "s" else Color(0.9, 0.3, 0.3)
		draw_rect(Rect2(-w / 2 + 1, y + 1, (w - 2) * float(hp) / max_hp, 4), c)


func _draw_dog(r: float, bob: float) -> void:
	var o := Vector2(0, r * 0.15 + bob * 0.5)
	var fur := Color(0.62, 0.42, 0.24)
	draw_rect(Rect2(o + Vector2(-r * 0.45, -r * 0.15), Vector2(r * 0.8, r * 0.38)), fur)
	draw_rect(Rect2(o + Vector2(-r * 0.4, r * 0.2), Vector2(r * 0.12, r * 0.25)), fur.darkened(0.2))
	draw_rect(Rect2(o + Vector2(r * 0.2, r * 0.2), Vector2(r * 0.12, r * 0.25)), fur.darkened(0.2))
	draw_circle(o + Vector2(r * 0.42, -r * 0.25), r * 0.24, fur)
	draw_rect(Rect2(o + Vector2(r * 0.25, -r * 0.55), Vector2(r * 0.12, r * 0.2)), fur.darkened(0.35))
	draw_circle(o + Vector2(r * 0.5, -r * 0.3), r * 0.05, Color.BLACK)
	draw_line(o + Vector2(-r * 0.45, -r * 0.1), o + Vector2(-r * 0.7, -r * 0.4 + bob), fur, 4.0)


func _draw_baby(o: Vector2, r: float) -> void:
	draw_circle(o + Vector2(0, r * 0.2), r * 0.32, Color(0.55, 0.75, 1.0))  # manta
	draw_circle(o + Vector2(0, -r * 0.15), r * 0.22, Color(1.0, 0.82, 0.7))  # rosto
	draw_circle(o + Vector2(-r * 0.08, -r * 0.18), r * 0.03, Color.BLACK)
	draw_circle(o + Vector2(r * 0.08, -r * 0.18), r * 0.03, Color.BLACK)
	draw_circle(o + Vector2(0, -r * 0.06), r * 0.05, Color(0.6, 0.1, 0.1))  # chorando
	# lágrimas / ondas de choro
	var a := fmod(_t * 2.0, 1.0)
	draw_arc(o + Vector2(0, -r * 0.15), r * (0.35 + a * 0.4), -2.4, -0.7, 12, Color(1, 1, 1, 0.6 * (1.0 - a)), 2.0)
