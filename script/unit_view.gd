extends Node2D
# Visual de uma peça no tabuleiro. As artes são provisórias:
# trocar pelas imagens finais (Gemini) quando estiverem prontas.

const PLAYER_TEX = preload("res://assets/characters/survivor.png")
# survivor.png: 6 colunas x 16 linhas, quadros de 48x48 (gerado pelo Gemini,
# recortado com tools/slice_gemini_sheet.py). Linhas usadas:
const ROW_IDLE := 1    # parado, de lado
const ROW_WALK := 4    # andando, de lado
const ROW_SHOOT := {"pistol": 6, "bow": 9, "rifle": 12, "shotgun": 12}
const SHOOT_FRAMES := 3
const ANIM_DIR := "res://assets/Character_animation/"
# zumbi -> pasta/prefixo dos 4 quadros de animação (16x16)
const ZOMBIE_FRAMES := {
	"Z": "monsters_idle/skeleton1/v1/skeleton_v1_",
	"R": "monsters_idle/skeleton2/v1/skeleton2_v1_",
	"T": "monsters_idle/vampire/v1/vampire_v1_",
	"K": "monsters_idle/skull/v1/skull_v1_",
	"N": "monsters_idle/skeleton1/v2/skeleton_v2_",
	"C": "monsters_idle/skull/v2/skull_v2_",
	"G": "monsters_idle/skeleton2/v2/skeleton2_v2_",
	"U": "monsters_idle/vampire/v2/vampire_v2_",
	# com super poderes
	"S": "monsters_idle/skull/v1/skull_v1_",
	"O": "monsters_idle/skeleton2/v1/skeleton2_v1_",
	"J": "priests_idle/priest1/v1/priest1_v1_",
	"Q": "priests_idle/priest3/v1/priest3_v1_",
	"Y": "monsters_idle/skull/v2/skull_v2_",
	"F": "priests_idle/priest2/v1/priest2_v1_",
	"A": "monsters_idle/skeleton1/v2/skeleton_v2_",
	"I": "monsters_idle/vampire/v1/vampire_v1_",
}

# tamanho relativo de cada zumbi (16 px -> casa)
const ZOMBIE_SIZE := {"T": 0.85, "U": 0.9, "N": 0.6, "C": 0.55, "Q": 0.95, "I": 0.95, "S": 0.75, "Y": 0.75}

const ZOMBIE_TINT := {
	"Z": Color(0.65, 1.0, 0.6),
	"R": Color(1.0, 0.7, 0.6),
	"T": Color(0.75, 1.0, 0.7),
	"K": Color(0.85, 0.7, 1.0),
	"N": Color(0.9, 0.95, 0.6),
	"C": Color(0.6, 0.9, 0.75),
	"G": Color(1.0, 0.85, 0.5),
	"U": Color(1.0, 0.55, 0.5),
	"S": Color(0.55, 1.0, 0.35),
	"O": Color(0.55, 0.7, 1.0),
	"J": Color(0.8, 0.55, 1.0),
	"Q": Color(1.0, 0.55, 0.85),
	"Y": Color(1.0, 0.95, 0.45),
	"F": Color(0.75, 0.85, 0.5),
	"A": Color(0.95, 0.9, 0.8),
	"I": Color(0.6, 0.95, 0.45),
}

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
var frames: Array = []  # texturas soltas (zumbis)
var _t := 0.0
var _flash := 0.0
var anim_row := ROW_IDLE
var anim_t := 0.0
var anim_once := false  # true = toca uma vez (tiro) e volta para parado


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
			for i in range(1, 5):
				frames.append(load(ANIM_DIR + ZOMBIE_FRAMES[type] + str(i) + ".png"))
			sprite.texture = frames[0]
			sprite.modulate = ZOMBIE_TINT.get(type, Color.WHITE)
			s = tile / 16.0 * ZOMBIE_SIZE.get(type, 0.68)
		sprite.scale = Vector2(s, s)
		sprite.position = Vector2(0, -tile * (0.26 if type == "P" else 0.08))
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


func play_walk() -> void:
	if type == "P":
		anim_row = ROW_WALK
		anim_t = 0.0
		anim_once = false


func play_idle() -> void:
	if type == "P":
		anim_row = ROW_IDLE
		anim_once = false


# toca a animação de tiro da arma e espera ela terminar
func play_shoot(weapon: String) -> void:
	if type != "P":
		return
	anim_row = ROW_SHOOT.get(weapon, ROW_SHOOT["pistol"])
	anim_t = 0.0
	anim_once = true
	await get_tree().create_timer(SHOOT_FRAMES / 10.0).timeout


func flash() -> void:
	_flash = 0.35


func _process(delta: float) -> void:
	_t += delta
	if sprite:
		if frames.is_empty():
			anim_t += delta
			if anim_once:
				var f := int(anim_t * 10.0)
				if f >= SHOOT_FRAMES + 2:  # segura o último quadro um instante
					play_idle()
				else:
					sprite.frame = anim_row * 6 + mini(f, SHOOT_FRAMES - 1)
			else:
				var speed := 12.0 if anim_row == ROW_WALK else 6.0
				sprite.frame = anim_row * 6 + int(anim_t * speed) % 6
		else:
			sprite.texture = frames[int(_t * 5.0) % frames.size()]
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
