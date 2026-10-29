extends SceneTree
# Testes das regras. Rodar:
#   godot --headless --path . --script res://tests/test_rules.gd

const Board = preload("res://script/board_logic.gd")
const Levels = preload("res://script/levels.gd")

var failures := 0
var checks := 0


func _init() -> void:
	test_level1_layout()
	test_king_moves_and_mesa()
	test_zombie_chases()
	test_zombie_attacks()
	test_shooting()
	test_rifle_pierces()
	test_bow()
	test_door_and_key()
	test_backpack_capacity()
	test_medkit()
	test_rescue_and_win()
	test_dog_knight_and_conversion()
	test_baby_attracts_zombies()
	test_carry_baby()
	test_tank_is_slow()
	test_zombie_blocked_by_wall()
	test_levels_are_winnable()
	print("\n%d verificações, %d falhas" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FALHOU: ", msg)


func make(map: Array, extra := {}) -> Object:
	var b = Board.new()
	var data := {"map": map}
	data.merge(extra)
	b.load_level(data)
	return b


func test_level1_layout() -> void:
	var b = Board.new()
	b.load_level(Levels.LEVELS[0])
	check(b.size == Vector2i(4, 4), "fase 1 é 4x4")
	check(b.main_unit()["pos"] == Vector2i(3, 3), "pessoa no canto inferior direito")
	check(b.zombies()[0]["pos"] == Vector2i(0, 0), "zumbi no canto superior esquerdo")
	check(b.cell(Vector2i(1, 1)) == Board.BLOCK, "mesa em (1,1)")


func test_king_moves_and_mesa() -> void:
	var b = make(["....", ".M..", "..P.", "...."])
	var moves: Array = b.valid_moves(b.main_unit())
	check(moves.size() == 7, "rei tem 7 casas livres ao lado da mesa (tem %d)" % moves.size())
	check(not moves.has(Vector2i(1, 1)), "não anda para cima da mesa")


func test_zombie_chases() -> void:
	var b = make(["Z...", "....", "....", "...P"])
	b.wait_turn()
	var ev: Array = b.run_zombie_turn()
	check(ev.size() == 1 and ev[0]["type"] == "move", "zumbi se move")
	var zp: Vector2i = b.zombies()[0]["pos"]
	check(zp == Vector2i(1, 0) or zp == Vector2i(0, 1), "zumbi anda 1 casa reta em direção ao alvo")


func test_zombie_attacks() -> void:
	var b = make(["....", "....", "..ZP", "...."])
	b.run_zombie_turn()
	check(b.main_unit()["hp"] == 2, "mordida tira 1 de vida")
	check(b.zombies()[0]["pos"] == Vector2i(2, 2), "zumbi fica parado ao atacar")
	b.run_zombie_turn()
	b.run_zombie_turn()
	check(b.status == "lost", "sem vida = derrota")


func test_shooting() -> void:
	var b = make(["....", "....", "Z.P.", "...."], {"ammo": 2})
	check(b.shoot_targets().has(Vector2i(0, 2)), "pistola alcança 2 casas")
	var r: Dictionary = b.player_shoot(Vector2i(-1, 0))
	check(r["hits"].size() == 1 and b.zombies()[0]["hp"] == 1, "tiro tira 1 de vida")
	check(b.ammo == 1, "tiro gasta munição")
	b.player_shoot(Vector2i(-1, 0))
	check(b.zombies().is_empty(), "segundo tiro mata o zumbi comum")
	check(b.shoot_targets().is_empty(), "sem munição não atira")


func test_rifle_pierces() -> void:
	var b = make([".....", "PRR..", "....."], {"weapon": "rifle"})
	var r: Dictionary = b.player_shoot(Vector2i(1, 0))
	check(r["hits"].size() == 2 and b.zombies().is_empty(), "rifle atravessa e acerta 2 corredores")


func test_bow() -> void:
	var b = make(["......", "P...Z.", "......"], {"weapon": "bow", "ammo": 1})
	check(b.shoot_targets().has(Vector2i(4, 1)), "arco alcança 4 casas")
	var r: Dictionary = b.player_shoot(Vector2i(1, 0))
	check(r["hits"].size() == 1 and b.zombies()[0]["hp"] == 1, "flecha tira 1 de vida")
	check(b.ammo == 0 and b.items.get(Vector2i(4, 1), "") == "f", "flecha cai na casa do zumbi")
	var b2 = make([".....", ".....", "P...."], {"weapon": "bow", "ammo": 1})
	b2.player_shoot(Vector2i(1, 0))
	check(b2.items.get(Vector2i(4, 2), "") == "f", "flecha perdida cai no fim do alcance")
	var m: Dictionary = b2.main_unit()
	b2.items[Vector2i(1, 2)] = "f"
	b2.player_move(m["id"], Vector2i(1, 2))
	check(b2.ammo == 1, "pegar a flecha devolve 1 de munição")
	var b3 = make(["....", "Pb..", "...."])
	b3.player_move(b3.main_unit()["id"], Vector2i(1, 1))
	check(b3.weapon == "bow", "pegar o arco troca a arma")


func test_door_and_key() -> void:
	var b = make(["....", "WdWW", "k...", "P..."])
	var m: Dictionary = b.main_unit()
	b.player_move(m["id"], Vector2i(0, 2))
	check(b.backpack == ["k"], "chave vai para a mochila")
	check(b.valid_moves(m).has(Vector2i(1, 1)), "com chave pode entrar na porta")
	b.player_move(m["id"], Vector2i(1, 1))
	check(b.backpack.is_empty() and b.cell(Vector2i(1, 1)) == Board.FLOOR, "porta abre e chave é gasta")
	var b2 = make(["....", "WdWW", "P...", "...."])
	check(not b2.valid_moves(b2.main_unit()).has(Vector2i(1, 1)), "sem chave a porta bloqueia")


func test_backpack_capacity() -> void:
	var b = make(["....", "....", "khk.", "P..."], {"backpack": 2})
	var id: int = b.main_unit()["id"]
	b.player_move(id, Vector2i(0, 2))
	b.player_move(id, Vector2i(1, 2))
	b.player_move(id, Vector2i(2, 2))
	check(b.backpack.size() == 2 and b.items.has(Vector2i(2, 2)), "mochila cheia deixa o item no chão")


func test_medkit() -> void:
	var b = make(["....", "....", "h...", "P..."])
	var m: Dictionary = b.main_unit()
	b.player_move(m["id"], Vector2i(0, 2))
	check(not b.use_item(0), "kit não é usado com vida cheia")
	m["hp"] = 1
	check(b.use_item(0) and m["hp"] == 3 and b.backpack.is_empty(), "kit cura 2")


func test_rescue_and_win() -> void:
	var b = Board.new()
	b.load_level(Levels.LEVELS[0])
	var id: int = b.main_unit()["id"]
	for y in [2, 1, 0]:
		b.player_move(id, Vector2i(3, y))
		b.run_zombie_turn()
	check(b.status == "won", "fase 1: subir em linha reta vence (status %s)" % b.status)


func test_dog_knight_and_conversion() -> void:
	var b = make(["......", "......", "..M...", "......", ".D..P."])
	var dog: Dictionary = b.unit_at(Vector2i(1, 4))
	var moves: Array = b.valid_moves(dog)
	check(moves.has(Vector2i(2, 2)) == false and moves.has(Vector2i(0, 2)) and moves.has(Vector2i(3, 3)), "cachorro anda em L")
	var b2 = make(["......", "......", "......", "......", ".DZ.P."])
	b2.run_zombie_turn()
	check(b2.zombies().size() == 2 and b2.survivors().size() == 1, "cachorro mordido vira zumbi")
	check(b2.status == "playing", "perder o cachorro não acaba a fase")


func test_baby_attracts_zombies() -> void:
	var b = make([".....", "..Z..", ".P...", ".....", "....B"])
	b.run_zombie_turn()
	var zp: Vector2i = b.zombies()[0]["pos"]
	check(zp == Vector2i(3, 1) or zp == Vector2i(2, 2), "zumbi vai atrás do bebê, não do mais próximo")
	var b2 = make([".....", ".....", ".....", "...ZB", "P...."])
	b2.run_zombie_turn()
	check(b2.status == "lost", "bebê transformado = derrota")


func test_carry_baby() -> void:
	var b = make([".....", ".....", "..B..", ".....", "P...Z"])
	var m: Dictionary = b.main_unit()
	b.player_move(m["id"], Vector2i(1, 3))
	check(m.get("carrying", "") == "B" and b.survivors().size() == 1, "encostar no bebê pega no colo")
	b.run_zombie_turn()
	check(b.zombies()[0]["pos"] == Vector2i(3, 4), "zumbi persegue quem carrega o bebê")
	var id: int = m["id"]
	for y in [2, 1, 0]:
		b.player_move(id, Vector2i(1, y))
	check(b.status == "won" and b.rescued.has("B"), "chegar à saída com o bebê vence")


func test_tank_is_slow() -> void:
	var b = make(["T....", ".....", ".....", ".....", "....P"])
	b.run_zombie_turn()
	check(b.zombies()[0]["pos"] == Vector2i(0, 0), "tanque não anda no 1º turno")
	b.run_zombie_turn()
	check(b.zombies()[0]["pos"] != Vector2i(0, 0), "tanque anda no 2º turno")


func test_zombie_blocked_by_wall() -> void:
	var b = make(["..Z..", "WWdWW", ".....", "P...."])
	var ev: Array = b.run_zombie_turn()
	check(ev.is_empty(), "zumbi não atravessa porta trancada")


# ---------- robô que joga as fases ----------

func test_levels_are_winnable() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in Levels.LEVELS.size():
		var wins := 0
		var tries := 400
		for t in tries:
			if play_once(Levels.LEVELS[i], rng):
				wins += 1
		print("Fase %d (%s): robô venceu %d/%d" % [i + 1, Levels.LEVELS[i]["name"], wins, tries])
		check(wins > 0, "fase %d precisa ser vencível" % (i + 1))


func play_once(level: Dictionary, rng: RandomNumberGenerator) -> bool:
	var b = Board.new()
	b.load_level(level)
	for _t in 80:
		if b.status != "playing":
			break
		var best := {}
		var best_score := -INF
		for a in actions(b):
			var s: float = a["score"] + rng.randf() * 4.0
			if s > best_score:
				best_score = s
				best = a
		match best["kind"]:
			"move":
				b.player_move(best["id"], best["to"])
			"shoot":
				b.player_shoot(best["dir"])
			"heal":
				b.use_item(best["index"])
			_:
				b.wait_turn()
		b.run_zombie_turn()
	return b.status == "won"


func cheb(a: Vector2i, c: Vector2i) -> int:
	return maxi(absi(a.x - c.x), absi(a.y - c.y))


func danger(b, p: Vector2i) -> int:
	var n := 0
	for z in b.zombies():
		for d in b.dirs_for(z["moves"]):
			if z["pos"] + d == p:
				n += 1
	return n


func actions(b) -> Array:
	var out: Array = [{"kind": "wait", "score": -2.0}]
	for s in b.survivors():
		for to in b.valid_moves(s):
			var score: float = (s["pos"].y - to.y) * 2.0 - danger(b, to) * 6.0
			var babies: Array = b.survivors().filter(func(u): return u["cries"])
			if s["main"] and not babies.is_empty():
				var bp: Vector2i = babies[0]["pos"]
				score = (cheb(s["pos"], bp) - cheb(to, bp)) * 3.0 - danger(b, to) * 6.0
			if b.items.has(to) and s["main"]:
				score += 3.0
			if to.y == 0:
				score += 5.0
			out.append({"kind": "move", "id": s["id"], "to": to, "score": score})
	var targets: Array = b.shoot_targets()
	for d in b.KING_DIRS:
		if not targets.has(b.main_unit().get("pos", Vector2i(-99, -99)) + d):
			continue
		var hits := 0
		for i in range(1, int(b.weapon_info()["range"]) + 1):
			var z: Dictionary = b.unit_at(b.main_unit()["pos"] + d * i)
			if not z.is_empty() and z["team"] == "z":
				hits += 1
		if hits > 0:
			out.append({"kind": "shoot", "dir": d, "score": 2.0 + hits * 2.0})
	var m: Dictionary = b.main_unit()
	if not m.is_empty() and m["hp"] < m["max_hp"]:
		var idx: int = b.backpack.find("h")
		if idx >= 0:
			out.append({"kind": "heal", "index": idx, "score": 4.0})
	return out
