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
	test_pawn_zombie()
	test_crawler_hidden()
	test_trotter()
	test_brute_charge()
	test_spitter_acid()
	test_police_drops_ammo()
	test_necromancer_revives()
	test_queen_aura()
	test_screamer()
	test_soldier_pierce_reload()
	test_archer_keeps_distance()
	test_bloater_explodes()
	test_walls_block_ranged()
	test_hats()
	test_red_ribbon()
	test_backpacks()
	test_ring_and_sneakers()
	test_baby_bottle()
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
	check(b.main_unit()["hp"] == 66, "mordida tira 34 de vida")
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
	m["hp"] = 10
	check(b.use_item(0) and m["hp"] == 60 and b.backpack.is_empty(), "kit cura 50")


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
	var dog2: Dictionary = b2.unit_at(Vector2i(1, 4))
	check(b2.survivors().size() == 2 and dog2["hp"] == 36, "cachorro mordido perde 34 de vida (70 -> 36)")
	b2.run_zombie_turn()
	check(b2.survivors().size() == 2 and dog2["hp"] == 2, "cachorro aguenta a segunda mordida (36 -> 2)")
	b2.run_zombie_turn()
	check(b2.zombies().size() == 2 and b2.survivors().size() == 1, "na terceira mordida o cachorro morre e vira zumbi")
	check(b2.status == "playing", "perder o cachorro não acaba a fase")
	var b3 = make(["......", "......", "......", "......", "D...P."])
	var dog3: Dictionary = b3.unit_at(Vector2i(0, 4))
	b3.backpack.append("h")
	dog3["hp"] = 10
	check(b3.use_item(0, dog3["id"]) and dog3["hp"] == 60, "kit médico cura o personagem selecionado")


func test_baby_attracts_zombies() -> void:
	var b = make([".....", "..Z..", ".P...", ".....", "....B"])
	b.run_zombie_turn()
	var zp: Vector2i = b.zombies()[0]["pos"]
	check(zp == Vector2i(3, 1) or zp == Vector2i(2, 2), "zumbi vai atrás do bebê, não do mais próximo")
	var b2 = make([".....", ".....", ".....", "...ZB", "P...."])
	b2.run_zombie_turn()
	check(b2.status == "playing" and b2.unit_at(Vector2i(4, 3))["hp"] == 16, "bebê aguenta uma mordida (50 -> 16)")
	b2.run_zombie_turn()
	check(b2.status == "lost", "bebê morto = derrota")


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

func test_pawn_zombie() -> void:
	var b = make(["....", ".N..", "....", ".P.."])
	b.run_zombie_turn()
	check(b.zombies()[0]["pos"] == Vector2i(1, 2), "peão desce 1 casa")
	b.run_zombie_turn()
	check(b.zombies()[0]["pos"] == Vector2i(1, 2) and b.main_unit()["hp"] == 100, "peão bloqueado na frente não anda nem morde")
	var b2 = make(["....", ".N..", "..P.", "...."])
	b2.run_zombie_turn()
	check(b2.main_unit()["hp"] == 66, "peão morde na diagonal da frente")
	var b3 = make(["P...", "....", ".N..", "...."])
	b3.run_zombie_turn()
	check(b3.zombies()[0]["type"] == "T" and b3.zombies()[0]["hp"] == 4, "peão que chega ao fim vira Tanque")


func test_crawler_hidden() -> void:
	var b = make([".....", "C....", ".....", ".....", "....P"])
	var ev: Array = b.run_zombie_turn()
	check(ev.is_empty() and b.zombies()[0]["hidden"], "rastejante longe fica escondido e parado")
	var m: Dictionary = b.main_unit()
	m["pos"] = Vector2i(2, 3)
	ev = b.run_zombie_turn()
	check(not b.zombies()[0]["hidden"] and ev[0]["type"] == "reveal", "rastejante acorda a 2 casas")
	b.run_zombie_turn()
	check(b.zombies()[0]["pos"] == Vector2i(1, 2), "rastejante anda na diagonal")
	b.run_zombie_turn()
	check(m["hp"] == 66, "rastejante morde na diagonal")


func test_trotter() -> void:
	var b = make(["G.....", "......", "......", ".....P"])
	b.run_zombie_turn()
	var zp: Vector2i = b.zombies()[0]["pos"]
	check(zp == Vector2i(2, 0) or zp == Vector2i(0, 2), "trotador anda 2 casas retas")
	var b2 = make(["GM....", "......", "......", ".....P"])
	b2.run_zombie_turn()
	check(b2.zombies()[0]["pos"] == Vector2i(0, 2), "trotador não atravessa mesa")


func test_brute_charge() -> void:
	var b = make(["U.....", "......", "......", "......", "......", "P....."])
	b.run_zombie_turn()
	check(b.zombies()[0]["pos"] == Vector2i(0, 3), "brutamontes faz investida de 3 casas")
	check(b.zombies()[0]["stun"] == 1, "fica tonto depois da investida")
	var ev: Array = b.run_zombie_turn()
	check(ev.is_empty() and b.zombies()[0]["stun"] == 0, "tonto perde a rodada")
	var b2 = make([".....", ".U...", ".P...", ".....", "....."])
	b2.run_zombie_turn()
	check(b2.main_unit()["hp"] == 66 and b2.main_unit()["pos"] == Vector2i(1, 3), "mordida do brutamontes empurra 1 casa")


func test_spitter_acid() -> void:
	var b = make(["S...", "....", "....", "P..."])
	var ev: Array = b.run_zombie_turn()
	check(ev[0]["type"] == "aim" and b.main_unit()["hp"] == 100, "zumbi de longe primeiro mira")
	ev = b.run_zombie_turn()
	check(ev[0]["type"] == "shoot" and b.main_unit()["hp"] == 66, "cuspidor acerta a 3 casas em linha reta")
	check(b.hazards.has(Vector2i(0, 3)), "cuspe deixa ácido no chão")
	b.units.erase(b.zombies()[0])
	b.run_zombie_turn()
	check(b.main_unit()["hp"] == 32, "ácido queima quem fica em cima")
	b.main_unit()["pos"] = Vector2i(3, 3)
	b.run_zombie_turn()
	check(b.hazards.is_empty(), "ácido some depois de 2 rodadas")


func test_police_drops_ammo() -> void:
	var b = make([".....", ".....", "PO...", "....."], {"ammo": 3})
	b.zombies()[0]["hp"] = 1
	b.player_shoot(Vector2i(1, 0))
	check(b.items.get(Vector2i(1, 2), "") == "a", "policial larga munição ao morrer")
	var b2 = make(["O....", ".....", ".....", "P...."])
	b2.run_zombie_turn()
	b2.run_zombie_turn()
	check(b2.main_unit()["hp"] == 66, "policial atira a 3 casas")
	var b3 = make(["O....", ".....", ".....", "P...."])
	b3.run_zombie_turn()
	b3.main_unit()["pos"] = Vector2i(1, 3)  # saiu da linha de tiro
	b3.run_zombie_turn()
	check(b3.main_unit()["hp"] == 100, "sair da linha vermelha desvia do tiro")


func test_necromancer_revives() -> void:
	var b = make(["......", "..J...", "......", "......", "......", "P....."])
	b.graveyard.append({"pos": Vector2i(3, 1), "type": "Z"})
	b.zombies()[0]["revive"] = 1
	var ev: Array = b.run_zombie_turn()
	check(ev[0]["type"] == "revive" and b.zombies().size() == 2, "necromante levanta zumbi abatido perto")
	check(b.graveyard.is_empty(), "o cemitério é usado")
	var b2 = make(["J.....", "......", "......", "...P.."])
	b2.run_zombie_turn()
	b2.run_zombie_turn()
	check(b2.main_unit()["hp"] == 66, "necromante ataca na diagonal de longe")


func test_queen_aura() -> void:
	var b = make([".......", "Q.Z....", ".......", ".......", ".......", ".......", "......P"])
	b.zombies()[0]["ranged"] = {}  # só a aura
	b.zombies()[0]["moves"] = "wazir"
	var zc: Dictionary = b.zombies()[1]
	b.run_zombie_turn()
	var moved: int = (zc["pos"] - Vector2i(2, 1)).abs().x + (zc["pos"] - Vector2i(2, 1)).abs().y
	check(moved == 2, "zumbi perto da rainha anda 2 vezes (andou %d)" % moved)


func test_screamer() -> void:
	var b = make(["Z.....", "......", "...Y..", "......", ".P....", "......"])
	var zc: Dictionary = b.zombies()[0]
	var b0 = make(["......", "......", "...Y..", "......", ".P....", "......"])
	var ev0: Array = b0.run_zombie_turn()
	check(ev0[0]["type"] == "aim" and b0.main_unit()["hp"] == 100, "gritador puxa o ar antes de gritar")
	b.zombies()[1]["aim_area"] = true  # já puxou o ar
	var ev: Array = b.run_zombie_turn()
	check(ev.any(func(e): return e["type"] == "scream") and b.main_unit()["hp"] == 66, "grito fere quem está a 2 casas")
	var moved: int = (zc["pos"] - Vector2i(0, 0)).abs().x + (zc["pos"] - Vector2i(0, 0)).abs().y
	check(moved == 2, "grito chama zumbi (ele anda de novo)")
	var ev2: Array = b.run_zombie_turn()
	check(not ev2.any(func(e): return e["type"] == "scream"), "gritador recarrega: não grita 2 rodadas seguidas")


func test_soldier_pierce_reload() -> void:
	var b = make(["F.DP.."], {})
	b.run_zombie_turn()
	b.run_zombie_turn()
	check(b.unit_at(Vector2i(2, 0))["hp"] == 36 and b.main_unit()["hp"] == 66, "soldado atravessa: acerta cachorro e sobrevivente")
	var b2 = make(["F....P", "......"])
	b2.run_zombie_turn()
	b2.run_zombie_turn()
	var ev: Array = b2.run_zombie_turn()
	check(b2.main_unit()["hp"] == 66 and not ev.any(func(e): return e["type"] == "shoot"), "soldado recarrega antes do próximo tiro")


func test_archer_keeps_distance() -> void:
	var b = make([".......", ".......", "...A...", "...P...", ".......", ".......", "......."])
	b.run_zombie_turn()
	var a: Dictionary = b.zombies()[0]
	check(b._cheb(a["pos"], Vector2i(3, 3)) >= 3 and b.main_unit()["hp"] == 100, "arqueiro foge quando você chega perto")
	var b2 = make(["A......", ".......", ".......", ".......", "....P.."])
	b2.run_zombie_turn()
	b2.run_zombie_turn()
	check(b2.main_unit()["hp"] == 66, "arqueiro acerta na diagonal de longe")


func test_bloater_explodes() -> void:
	var b = make(["....", ".IZ.", ".P..", "...."])
	var ev: Array = b.run_zombie_turn()
	check(ev[0]["type"] == "explode" and b.main_unit()["hp"] == 66, "inchado explode perto do sobrevivente")
	check(b.zombies().size() == 1 and b.zombies()[0]["hp"] == 1, "explosão fere zumbis em volta")
	var b2 = make(["....", "PI..", "....", "...."], {"ammo": 3})
	b2.zombies()[0]["hp"] = 1
	var r: Dictionary = b2.player_shoot(Vector2i(1, 0))
	check(r["explosions"].size() == 1 and b2.main_unit()["hp"] == 66, "inchado abatido explode também")


func test_walls_block_ranged() -> void:
	var b = make(["O...", "W...", "....", "P..."])
	b.run_zombie_turn()
	check(b.main_unit()["hp"] == 100, "parede bloqueia tiro de zumbi")


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
		if z.get("hidden", false):
			continue
		for d in b.attack_dirs(z):
			if z["pos"] + d == p:
				n += 1
		if z.get("cool", 0) <= 1 and b.ranged_threat(z).has(p):
			n += 1
		if z.has("aim_area") and b.ranged_threat(z).has(p):
			n += 3
		if z.has("aim"):  # linha vermelha: vai atirar agora
			for i in range(1, int(z["ranged"]["range"]) + 1):
				if z["pos"] + z["aim"] * i == p:
					n += 3
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


func test_hats() -> void:
	var b = make(["....", "....", "1.2.", "P.3."])
	var m: Dictionary = b.main_unit()
	b.player_move(m["id"], Vector2i(0, 2))
	check(m["max_hp"] == 110 and m["hp"] == 110, "boné branco: +10% de vida")
	b.player_move(m["id"], Vector2i(1, 2))
	b.player_move(m["id"], Vector2i(2, 2))
	check(m["max_hp"] == 120 and m["hp"] == 120, "boné verde troca o branco: +20%")
	b.player_move(m["id"], Vector2i(2, 3))
	check(m["max_hp"] == 130, "boné preto: +30%")
	var b2 = make(["....", "....", "3.1.", "P..."])
	var m2: Dictionary = b2.main_unit()
	b2.player_move(m2["id"], Vector2i(0, 2))
	b2.player_move(m2["id"], Vector2i(1, 2))
	b2.player_move(m2["id"], Vector2i(2, 2))
	check(m2["max_hp"] == 130 and b2.items.has(Vector2i(2, 2)), "boné pior fica no chão")


func test_red_ribbon() -> void:
	var b = make(["....", "....", "v.ZP", "...."])
	check(b.damage_points(1, {"main": false}) == 34, "fita não protege os outros")
	b.items.erase(Vector2i(0, 2))
	b.items[Vector2i(3, 3)] = "v"
	var m: Dictionary = b.main_unit()
	b.player_move(m["id"], Vector2i(3, 3))
	b.player_move(m["id"], Vector2i(3, 2))
	b.run_zombie_turn()
	check(m["hp"] == 69, "fita vermelha: mordida tira 31 em vez de 34 (tem %d)" % m["hp"])


func test_backpacks() -> void:
	var b = make(["....", "....", "u.y.", "P..."], {"backpack": 4})
	var m: Dictionary = b.main_unit()
	b.player_move(m["id"], Vector2i(0, 2))
	check(b.bag_capacity == 6, "mochila nível 2: 4 + 30% = 6 espaços (arredonda para cima)")
	b.player_move(m["id"], Vector2i(1, 2))
	b.player_move(m["id"], Vector2i(2, 2))
	check(b.bag_capacity == 6 and b.bag_bonus == 50, "mochila militar: 4 + 50% = 6")
	var b2 = make(["....", "....", "y...", "P..."], {"backpack": 3})
	b2.player_move(b2.main_unit()["id"], Vector2i(0, 2))
	check(b2.bag_capacity == 5, "mochila militar: 3 + 50% = 5 (arredonda para cima)")


func test_ring_and_sneakers() -> void:
	var b = make([".....", ".....", ".....", ".....", "o...P"])
	var m: Dictionary = b.main_unit()
	check(not b.valid_moves(m).has(Vector2i(2, 4)), "sem anel anda só 1 casa")
	b.items.erase(Vector2i(0, 4))
	b.items[Vector2i(3, 4)] = "o"
	b.player_move(m["id"], Vector2i(3, 4))
	check(b.valid_moves(m).has(Vector2i(1, 4)) and b.valid_moves(m).has(Vector2i(1, 2)), "anel: até 2 casas em qualquer direção")
	check(not b.valid_moves(m).has(Vector2i(0, 4)), "anel não chega a 3 casas")
	var b2 = make([".....", "..M..", ".....", ".....", "t...P"])
	b2.items.erase(Vector2i(0, 4))
	b2.items[Vector2i(4, 3)] = "t"
	var m2: Dictionary = b2.main_unit()
	b2.player_move(m2["id"], Vector2i(4, 3))
	check(b2.valid_moves(m2).has(Vector2i(4, 0)) and b2.valid_moves(m2).has(Vector2i(1, 3)), "tênis: até 3 casas")
	check(not b2.valid_moves(m2).has(Vector2i(1, 0)), "tênis não atravessa a mesa")


func test_baby_bottle() -> void:
	var b0 = make(["...Z....B", ".........", ".........", "...P....."])
	b0.run_zombie_turn()
	check(b0.zombies()[0]["pos"] == Vector2i(4, 0), "sem mamadeira o zumbi vai atrás do bebê")
	var b = make(["...Z....B", ".........", ".........", "...P....."])
	b.backpack.append("m")
	check(b.use_item(0), "mamadeira pode ser usada com bebê na fase")
	check(b.calm == 3, "bebê fica quieto 3 rodadas")
	b.run_zombie_turn()
	check(b.zombies()[0]["pos"] == Vector2i(3, 1), "com o bebê quieto o zumbi vai atrás de quem está mais perto")
	var b2 = make(["Z...", "....", "....", "...P"])
	b2.backpack.append("m")
	check(not b2.use_item(0), "sem bebê a mamadeira não é usada")
