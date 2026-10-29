extends RefCounted
# Regras do Xadrez Zumbi. Não desenha nada: a cena (game.gd) lê este estado
# e anima os eventos. Isso permite testar as regras sem abrir janela.

const FLOOR := 0
const BLOCK := 1  # mesa, entulho, carro: bloqueia passagem e tiro
const WALL := 2
const DOOR := 3   # porta trancada: abre com chave

const INF := 1 << 20

# Vida do Sobrevivente vai de 0 a 100. Cada "golpe" de zumbi (dmg 1) tira HIT pontos.
const MAX_HP := 100
const HIT := 34
const MEDKIT_HEAL := 50
const CALM_TURNS := 3  # rodadas que a mamadeira deixa os bebês quietos

const WAZIR_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const KING_DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
	Vector2i(1, -1), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-1, 1)]
const FERZ_DIRS: Array[Vector2i] = [
	Vector2i(1, -1), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-1, 1)]
const PAWN_MOVE: Array[Vector2i] = [Vector2i(0, 1)]  # zumbi-peão desce em direção ao jogador
const PAWN_BITE: Array[Vector2i] = [Vector2i(-1, 1), Vector2i(1, 1)]
const KNIGHT_DIRS: Array[Vector2i] = [
	Vector2i(1, -2), Vector2i(-1, -2), Vector2i(2, -1), Vector2i(-2, -1),
	Vector2i(2, 1), Vector2i(-2, 1), Vector2i(1, 2), Vector2i(-1, 2)]

# Movimentos inspirados no xadrez:
#   king   = 1 casa em qualquer direção (rei)
#   wazir  = 1 casa reto (sem diagonal)
#   knight = em "L" (cavalo), pula obstáculos
#   ferz   = 1 casa na diagonal
#   pawn   = 1 casa para baixo; morde na diagonal da frente (peão)
#   rook2 / rook3 = até 2 / 3 casas em linha reta (torre curta)
const SURVIVORS := {
	"P": {"name": "Sobrevivente", "hp": MAX_HP, "moves": "king", "main": true},
	"D": {"name": "Cachorro", "hp": 70, "moves": "knight"},
	"B": {"name": "Bebê Chorão", "hp": 50, "moves": "wazir", "cries": true, "required": true},
}

# every  = age a cada N turnos (o Tanque é lento)
# attack = onde morde (se não tiver, morde onde anda)
# hidden = começa escondido até alguém chegar a 2 casas
# charge = empurra a vítima e fica tonto depois de uma investida longa
const ZOMBIES := {
	"Z": {"name": "Zumbi Comum", "hp": 2, "moves": "wazir", "every": 1},
	"R": {"name": "Corredor", "hp": 1, "moves": "king", "every": 1},
	"T": {"name": "Tanque", "hp": 4, "moves": "wazir", "every": 2},
	"K": {"name": "Saltador", "hp": 2, "moves": "knight", "every": 2},
	"N": {"name": "Peão Podre", "hp": 1, "moves": "pawn", "every": 1, "attack": "pawn"},
	"C": {"name": "Rastejante", "hp": 1, "moves": "ferz", "every": 1, "hidden": true},
	"G": {"name": "Trotador", "hp": 2, "moves": "rook2", "every": 1, "attack": "wazir"},
	"U": {"name": "Brutamontes", "hp": 4, "moves": "rook3", "every": 1, "attack": "wazir", "charge": true},
	# --- com super poderes: atacam de longe ---
	# ranged: dirs (rook = reto, bishop = diagonal, queen = os dois, area = em volta),
	#         range, dmg, pierce (atravessa sobreviventes), reload (atira a cada N ações)
	"S": {"name": "Cuspidor", "hp": 2, "moves": "queen2", "every": 1, "acid": true,
		"ranged": {"dirs": "rook", "range": 3, "dmg": 1, "reload": 1}},
	"O": {"name": "Policial Zumbi", "hp": 3, "moves": "rook4", "every": 1, "drops": "a",
		"ranged": {"dirs": "rook", "range": 3, "dmg": 1, "reload": 1}},
	"J": {"name": "Bispo Necromante", "hp": 3, "moves": "bishop4", "every": 1, "revive": 3,
		"ranged": {"dirs": "bishop", "range": 3, "dmg": 1, "reload": 1}},
	"Q": {"name": "Rainha Zumbi", "hp": 6, "moves": "queen5", "every": 1, "aura": 2,
		"ranged": {"dirs": "queen", "range": 3, "dmg": 1, "reload": 1}},
	"Y": {"name": "Gritador", "hp": 2, "moves": "king", "every": 1, "calls": true,
		"ranged": {"dirs": "area", "range": 2, "dmg": 1, "reload": 2}},
	"F": {"name": "Soldado Caído", "hp": 3, "moves": "rook3", "every": 1,
		"ranged": {"dirs": "rook", "range": 5, "dmg": 1, "pierce": true, "reload": 2}},
	"A": {"name": "Esqueleto Arqueiro", "hp": 2, "moves": "queen3", "every": 1, "coward": 2,
		"ranged": {"dirs": "queen", "range": 4, "dmg": 1, "reload": 1}},
	"I": {"name": "Inchado", "hp": 3, "moves": "rook3", "every": 1, "attack": "king", "explodes": true},
}

const WEAPONS := {
	"pistol": {"name": "Pistola", "range": 2, "dmg": 1, "pierce": false},
	"shotgun": {"name": "Escopeta", "range": 1, "dmg": 3, "pierce": false},
	"rifle": {"name": "Rifle", "range": 3, "dmg": 1, "pierce": true},
	# arco: alcança longe e a flecha cai no chão (dá para pegar de volta)
	"bow": {"name": "Arco e Flecha", "range": 4, "dmg": 1, "pierce": false, "arrow": true},
}

# bag = ocupa espaço na mochila
const ITEMS := {
	"k": {"name": "Chave", "bag": true},
	"h": {"name": "Kit Médico", "bag": true},
	"a": {"name": "Munição (+3)", "bag": false},
	"s": {"name": "Escopeta", "bag": false, "weapon": "shotgun"},
	"r": {"name": "Rifle", "bag": false, "weapon": "rifle"},
	"b": {"name": "Arco e Flecha", "bag": false, "weapon": "bow"},
	"f": {"name": "Flecha (+1)", "bag": false},
	# --- equipamentos: ficam com o Sobrevivente até o fim da fase ---
	"1": {"name": "Boné Branco", "bag": false, "hat": 10, "desc": "+10% de vida"},
	"2": {"name": "Boné Verde", "bag": false, "hat": 20, "desc": "+20% de vida"},
	"3": {"name": "Boné Preto", "bag": false, "hat": 30, "desc": "+30% de vida"},
	"v": {"name": "Fita Vermelha", "bag": false, "armor": 10, "desc": "-10% de dano das mordidas"},
	"u": {"name": "Mochila Nível 2", "bag": false, "bag_bonus": 30, "desc": "+30% de espaço na mochila"},
	"y": {"name": "Mochila Militar", "bag": false, "bag_bonus": 50, "desc": "+50% de espaço na mochila"},
	"o": {"name": "Anel do Poder", "bag": false, "reach": 2, "desc": "anda até 2 casas em qualquer direção"},
	"t": {"name": "Tênis Branco", "bag": false, "reach": 3, "desc": "anda até 3 casas em qualquer direção"},
	# --- consumível ---
	"m": {"name": "Mamadeira", "bag": true, "desc": "acalma os bebês por 3 rodadas"},
}

var size := Vector2i.ZERO
var cells := PackedInt32Array()
var decor := {}      # Vector2i -> letra do obstáculo ("M", "X", "W", "d")
var items := {}      # Vector2i -> letra do item
var units: Array = []  # cada unidade é um Dictionary
var next_id := 1
var backpack: Array = []
var bag_capacity := 3
var bag_base := 3
var bag_bonus := 0     # % de espaço extra da melhor mochila
var hat_bonus := 0     # % de vida extra do melhor boné
var armor := 0         # % de dano a menos (Fita Vermelha)
var reach := 1         # casas que o Sobrevivente anda (Anel / Tênis)
var calm := 0          # rodadas em que os bebês ficam quietos (Mamadeira)
var equipped: Array = []  # letras dos equipamentos em uso
var weapon := "pistol"
var ammo := 3
var status := "playing"  # playing | won | lost
var end_reason := ""
var rescued: Array = []
var required: Array = []  # tipos que precisam chegar à saída (ex.: bebê)
var turn := 1
var log_lines: Array = []
var hazards := {}        # Vector2i -> rodadas restantes de ácido no chão
var graveyard: Array = []  # zumbis abatidos: {"pos", "type"} (para o Necromante)


func load_level(data: Dictionary) -> void:
	var rows: Array = data["map"]
	size = Vector2i(rows[0].length(), rows.size())
	cells = PackedInt32Array()
	cells.resize(size.x * size.y)
	decor = {}
	items = {}
	units = []
	next_id = 1
	backpack = []
	rescued = []
	required = ["P"]
	log_lines = []
	hazards = {}
	graveyard = []
	status = "playing"
	end_reason = ""
	turn = 1
	bag_base = data.get("backpack", 3)
	bag_capacity = bag_base
	bag_bonus = 0
	hat_bonus = 0
	armor = 0
	reach = 1
	calm = 0
	equipped = []
	weapon = data.get("weapon", "pistol")
	ammo = data.get("ammo", 3)
	for y in size.y:
		var row: String = rows[y]
		assert(row.length() == size.x, "Linha %d do mapa com tamanho errado" % y)
		for x in size.x:
			var ch := row[x]
			var p := Vector2i(x, y)
			var c := FLOOR
			match ch:
				"M", "X":
					c = BLOCK
					decor[p] = ch
				"W":
					c = WALL
					decor[p] = ch
				"d":
					c = DOOR
					decor[p] = ch
				_:
					if ITEMS.has(ch):
						items[p] = ch
					elif SURVIVORS.has(ch):
						_spawn("s", ch, p)
					elif ZOMBIES.has(ch):
						_spawn("z", ch, p)
			cells[y * size.x + x] = c


func _spawn(team: String, type: String, p: Vector2i) -> Dictionary:
	var def: Dictionary = SURVIVORS[type] if team == "s" else ZOMBIES[type]
	var u := {
		"id": next_id, "team": team, "type": type, "pos": p,
		"name": def["name"], "hp": def["hp"], "max_hp": def["hp"],
		"moves": def["moves"], "every": def.get("every", 1), "tick": 0,
		"main": def.get("main", false), "required": def.get("required", false),
		"cries": def.get("cries", false),
		"attack": def.get("attack", def["moves"]), "hidden": def.get("hidden", false),
		"charge": def.get("charge", false), "stun": 0, "cool": 0,
		"ranged": def.get("ranged", {}), "power_t": 0,
	}
	for key in ["acid", "drops", "revive", "aura", "calls", "coward", "explodes"]:
		if def.has(key):
			u[key] = def[key]
	next_id += 1
	units.append(u)
	if u["required"] and not required.has(type):
		required.append(type)
	return u


func clone():
	var b = get_script().new()
	b.size = size
	b.cells = cells.duplicate()
	b.decor = decor.duplicate()
	b.items = items.duplicate()
	b.units = units.duplicate(true)
	b.next_id = next_id
	b.backpack = backpack.duplicate()
	b.bag_capacity = bag_capacity
	b.bag_base = bag_base
	b.bag_bonus = bag_bonus
	b.hat_bonus = hat_bonus
	b.armor = armor
	b.reach = reach
	b.calm = calm
	b.equipped = equipped.duplicate()
	b.weapon = weapon
	b.ammo = ammo
	b.status = status
	b.end_reason = end_reason
	b.rescued = rescued.duplicate()
	b.required = required.duplicate()
	b.turn = turn
	b.hazards = hazards.duplicate()
	b.graveyard = graveyard.duplicate(true)
	return b


# ---------- consultas ----------

func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < size.x and p.y < size.y


func cell(p: Vector2i) -> int:
	return cells[p.y * size.x + p.x]


func unit_at(p: Vector2i) -> Dictionary:
	for u in units:
		if u["pos"] == p:
			return u
	return {}


func unit_by_id(id: int) -> Dictionary:
	for u in units:
		if u["id"] == id:
			return u
	return {}


func main_unit() -> Dictionary:
	for u in units:
		if u["main"]:
			return u
	return {}


func survivors() -> Array:
	return units.filter(func(u): return u["team"] == "s")


func zombies() -> Array:
	return units.filter(func(u): return u["team"] == "z")


# Movimentos: wazir, king, ferz, knight, pawn, ou peça + alcance
# (rook2 = torre até 2 casas, bishop4 = bispo até 4, queen5 = dama até 5).
func dirs_for(moves: String) -> Array[Vector2i]:
	if moves == "wazir" or moves.begins_with("rook"):
		return WAZIR_DIRS
	if moves == "ferz" or moves.begins_with("bishop"):
		return FERZ_DIRS
	match moves:
		"pawn":
			return PAWN_MOVE
		"knight":
			return KNIGHT_DIRS
	return KING_DIRS


func weapon_info() -> Dictionary:
	return WEAPONS[weapon]


func valid_moves(u: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if u.is_empty() or u["team"] != "s":
		return out
	# Anel do Poder / Tênis Branco: o Sobrevivente desliza várias casas
	# em linha (como a dama), parando em obstáculos, peças e portas.
	var steps: int = reach if u["main"] else 1
	for d in dirs_for(u["moves"]):
		for i in range(1, steps + 1):
			var p: Vector2i = u["pos"] + d * i
			if not in_bounds(p):
				break
			var c := cell(p)
			if c == BLOCK or c == WALL:
				break
			if c == DOOR and not (u["main"] and backpack.has("k")):
				break
			if not unit_at(p).is_empty():
				break
			out.append(p)
			if c == DOOR:
				break
	return out


# Casas que o tiro pode alcançar (8 direções, até o alcance da arma).
func shoot_targets() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var m := main_unit()
	if m.is_empty() or ammo <= 0:
		return out
	var rng: int = weapon_info()["range"]
	for d in KING_DIRS:
		for i in range(1, rng + 1):
			var p: Vector2i = m["pos"] + d * i
			if not in_bounds(p) or cell(p) != FLOOR:
				break
			var o := unit_at(p)
			if not o.is_empty() and o["team"] == "s":
				break
			out.append(p)
	return out


# ---------- ações do jogador (cada uma gasta a rodada) ----------

func player_move(id: int, to: Vector2i) -> Dictionary:
	var u := unit_by_id(id)
	if status != "playing" or not valid_moves(u).has(to):
		return {}
	var result := {"from": u["pos"], "to": to, "picked": "", "rescued": false, "door": false}
	if cell(to) == DOOR:
		backpack.erase("k")
		cells[to.y * size.x + to.x] = FLOOR
		decor.erase(to)
		result["door"] = true
		_log("Porta destrancada com a chave.")
	u["pos"] = to
	if u["main"] and items.has(to):
		result["picked"] = _pickup(to)
	if u["main"]:
		# encostou no bebê: pega no colo
		for d in KING_DIRS:
			var o := unit_at(to + d)
			if not o.is_empty() and o["cries"]:
				units.erase(o)
				u["carrying"] = o["type"]
				u["cries"] = true
				result["carried"] = o["id"]
				_log("Pegou %s no colo! O choro atrai os zumbis até você." % o["name"])
				break
	if to.y == 0:
		units.erase(u)
		rescued.append(u["type"])
		if u.has("carrying"):
			rescued.append(u["carrying"])
		result["rescued"] = true
		_log("%s chegou à saída!" % u["name"])
	_check_end()
	return result


func _pickup(p: Vector2i) -> String:
	var it: String = items[p]
	var def: Dictionary = ITEMS[it]
	if def.has("hat") or def.has("armor") or def.has("bag_bonus") or def.has("reach"):
		if not _equip(it):
			return ""
	elif def["bag"]:
		if backpack.size() >= bag_capacity:
			_log("Mochila cheia! %s ficou no chão." % def["name"])
			return ""
		backpack.append(it)
	elif it == "a":
		ammo += 3
	elif it == "f":
		ammo += 1
	elif def.has("weapon"):
		weapon = def["weapon"]
	items.erase(p)
	_log("Pegou: %s." % def["name"])
	return it


# Veste um equipamento. Do mesmo tipo (boné, mochila, calçado) fica só o melhor.
# Devolve false se já tem um igual ou melhor (o item fica no chão).
func _equip(it: String) -> bool:
	var def: Dictionary = ITEMS[it]
	var m := main_unit()
	if def.has("hat"):
		var v: int = def["hat"]
		if v <= hat_bonus:
			_log("Você já usa um boné igual ou melhor.")
			return false
		var extra := MAX_HP * (v - hat_bonus) / 100
		hat_bonus = v
		m["max_hp"] += extra
		m["hp"] += extra
	elif def.has("armor"):
		if armor >= int(def["armor"]):
			_log("Você já usa a Fita Vermelha.")
			return false
		armor = def["armor"]
	elif def.has("bag_bonus"):
		var v: int = def["bag_bonus"]
		if v <= bag_bonus:
			_log("Sua mochila já é igual ou maior.")
			return false
		bag_bonus = v
		bag_capacity = ceili(bag_base * (100 + v) / 100.0)
	elif def.has("reach"):
		if int(def["reach"]) <= reach:
			_log("Você já anda igual ou mais longe.")
			return false
		reach = def["reach"]
	equipped.append(it)
	_log("Equipou %s: %s." % [def["name"], def["desc"]])
	return true


func player_shoot(dir: Vector2i) -> Dictionary:
	var m := main_unit()
	if status != "playing" or m.is_empty() or ammo <= 0:
		return {}
	var targets := shoot_targets()
	if not targets.has(m["pos"] + dir):
		return {}
	ammo -= 1
	var w := weapon_info()
	var end: Vector2i = m["pos"]
	var hits: Array = []
	var explosions: Array = []  # Inchados que estouraram ao morrer
	for i in range(1, int(w["range"]) + 1):
		var p: Vector2i = m["pos"] + dir * i
		if not targets.has(p):
			break
		end = p
		var z := unit_at(p)
		if z.is_empty() or z["team"] != "z":
			continue
		z["hp"] -= w["dmg"]
		var killed: bool = z["hp"] <= 0
		hits.append({"id": z["id"], "killed": killed})
		if killed:
			_log("%s abatido!" % z["name"])
			_kill(z, explosions)
		else:
			_log("Acertou %s (vida %d)." % [z["name"], z["hp"]])
		if not w["pierce"]:
			break
	if hits.is_empty():
		_log("Flecha perdida." if w.get("arrow", false) else "Tiro perdido.")
	var dropped := false
	if w.get("arrow", false) and not items.has(end):
		items[end] = "f"  # a flecha fica no chão para ser recuperada
		dropped = true
	_check_end()
	return {"from": m["pos"], "end": end, "hits": hits, "arrow": w.get("arrow", false),
		"dropped": dropped, "explosions": explosions}


# target_id = quem recebe o kit médico (o personagem selecionado); sem ele, o Sobrevivente.
func use_item(index: int, target_id := -1) -> bool:
	var m := main_unit()
	if status != "playing" or m.is_empty() or index < 0 or index >= backpack.size():
		return false
	var t := unit_by_id(target_id)
	if t.is_empty() or t["team"] != "s":
		t = m
	if backpack[index] == "h" and t["hp"] < t["max_hp"]:
		t["hp"] = mini(t["hp"] + MEDKIT_HEAL, t["max_hp"])
		backpack.remove_at(index)
		_log("%s usou Kit Médico (vida %d)." % [t["name"], t["hp"]])
		return true
	if backpack[index] == "m" and has_baby():
		calm = CALM_TURNS
		backpack.remove_at(index)
		_log("Deu a mamadeira: o bebê ficou quieto por %d rodadas." % CALM_TURNS)
		return true
	return false


# Tem algum bebê no tabuleiro (no chão ou no colo)?
func has_baby() -> bool:
	for u in survivors():
		if u["cries"]:
			return true
	return false


func wait_turn() -> void:
	_log("Esperou.")


# ---------- turno dos zumbis ----------

func move_range(moves: String) -> int:
	for piece in ["rook", "bishop", "queen"]:
		if moves.begins_with(piece):
			return int(moves.substr(piece.length()))
	return 1


# Casas onde o zumbi morde.
func attack_dirs(z: Dictionary) -> Array[Vector2i]:
	if z.get("attack", z["moves"]) == "pawn":
		return PAWN_BITE
	return dirs_for(z.get("attack", z["moves"]))


# Casas que o zumbi alcança andando a partir de p (desliza em linha reta
# até o alcance; para em obstáculo e, se with_units, em outras peças).
func zombie_steps(p: Vector2i, moves: String, with_units: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in dirs_for(moves):
		for i in range(1, move_range(moves) + 1):
			var n: Vector2i = p + d * i
			if not in_bounds(n) or cell(n) != FLOOR:
				break
			if with_units and not unit_at(n).is_empty():
				break
			out.append(n)
	return out

# Distância (em jogadas) de cada casa até o alvo mais próximo, usando o
# movimento do zumbi. Ignora unidades no caminho; paredes, mesas e portas bloqueiam.
func distance_field(sources: Array, moves: String) -> Dictionary:
	var dist := {}
	var queue: Array = []
	for p in sources:
		dist[p] = 0
		queue.append(p)
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		for n in zombie_steps(p, moves, false):
			if not dist.has(n):
				dist[n] = dist[p] + 1
				queue.append(n)
	return dist


func _targets() -> Array:
	var s := survivors()
	if calm > 0:  # bebê mamando: o choro não atrai ninguém
		return s
	var criers := s.filter(func(u): return u["cries"])
	return criers if not criers.is_empty() else s


func run_zombie_turn() -> Array:
	var events: Array = []
	if status != "playing":
		return events
	_acid_tick(events)
	for z in zombies():
		if status != "playing":
			break
		if not units.has(z):
			continue
		if z["hidden"]:
			# Rastejante: acorda quando alguém chega a 2 casas (e só age na próxima)
			for s in survivors():
				if _cheb(s["pos"], z["pos"]) <= 2:
					z["hidden"] = false
					events.append({"type": "reveal", "id": z["id"]})
					_log("Um %s saiu do esconderijo!" % z["name"])
					break
			continue
		if z["stun"] > 0:
			z["stun"] -= 1
			continue
		z["tick"] += 1
		if z["tick"] % int(z["every"]) != 0:
			continue
		_zombie_act(z, events)
		# Rainha Zumbi: quem está perto dela age de novo
		if units.has(z) and status == "playing" and not z.has("aura") and _near_queen(z):
			_zombie_act(z, events, true)
	_check_end()
	if status == "playing":
		turn += 1
		if calm > 0:
			calm -= 1
	return events


# Uma ação de um zumbi: poder especial, ataque de longe, mordida ou andar.
# bonus = ação extra (aura da Rainha, grito do Gritador): não usa poderes com recarga.
func _zombie_act(z: Dictionary, events: Array, bonus := false) -> void:
	var targets := _targets()
	if targets.is_empty() or not units.has(z):
		return
	if not bonus and z["cool"] > 0:
		z["cool"] -= 1
	# Necromante: a cada N ações levanta um zumbi abatido perto dele
	if z.has("revive") and not bonus:
		z["power_t"] += 1
		if z["power_t"] >= int(z["revive"]):
			var ev := _try_revive(z)
			if not ev.is_empty():
				z["power_t"] = 0
				events.append(ev)
				return
	# Arqueiro: foge se alguém chega perto
	if z.has("coward"):
		var near := targets.filter(func(t): return _cheb(t["pos"], z["pos"]) <= int(z["coward"]))
		if not near.is_empty():
			var away := _step_away(z, near)
			if away.x >= 0:
				events.append({"type": "move", "id": z["id"], "from": z["pos"], "to": away})
				z["pos"] = away
				return
	# ataque de longe
	if not z["ranged"].is_empty() and z["cool"] == 0 and not bonus:
		if not _ranged_attack(z, events).is_empty():
			return
	# mordida (ou explosão do Inchado)
	for d in attack_dirs(z):
		var o := unit_at(z["pos"] + d)
		if not o.is_empty() and o["team"] == "s":
			if z.has("explodes"):
				_explode(z, events)
			else:
				events.append(_attack(z, o))
			return
	# andar pelo caminho mais curto até o alvo
	var best := Vector2i(-1, -1)
	if z["moves"] == "pawn":
		var fwd: Vector2i = z["pos"] + PAWN_MOVE[0]
		if in_bounds(fwd) and cell(fwd) == FLOOR and unit_at(fwd).is_empty():
			best = fwd
	else:
		var dist := distance_field(targets.map(func(u): return u["pos"]), z["moves"])
		var here: int = dist.get(z["pos"], INF)
		var best_d: int = here
		var best_len := 0
		for p in zombie_steps(z["pos"], z["moves"], true):
			var dp: int = dist.get(p, INF)
			var ln: int = (p - z["pos"]).abs().x + (p - z["pos"]).abs().y
			# mais perto do alvo; no empate, o passo mais longo
			if dp < best_d or (dp == best_d and dp < here and ln > best_len):
				best_d = dp
				best_len = ln
				best = p
	if best.x < 0:
		return
	var from: Vector2i = z["pos"]
	events.append({"type": "move", "id": z["id"], "from": from, "to": best})
	z["pos"] = best
	if z["charge"] and (best - from).abs().x + (best - from).abs().y >= 2:
		z["stun"] = 1
		_log("%s fez uma investida e ficou tonto." % z["name"])
	if z["moves"] == "pawn" and best.y == size.y - 1:
		_promote(z, "T")
		events.append({"type": "promote", "id": z["id"]})


func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _near_queen(z: Dictionary) -> bool:
	for q in zombies():
		if q.has("aura") and q != z and _cheb(q["pos"], z["pos"]) <= int(q["aura"]):
			return true
	return false


func ranged_dirs(kind: String) -> Array[Vector2i]:
	match kind:
		"rook":
			return WAZIR_DIRS
		"bishop":
			return FERZ_DIRS
	return KING_DIRS


# Casas que um zumbi de longe ameaça agora (para mostrar ao jogador).
func ranged_threat(z: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r: Dictionary = z.get("ranged", {})
	if r.is_empty():
		return out
	var rng: int = r["range"]
	if r["dirs"] == "area":
		for dy in range(-rng, rng + 1):
			for dx in range(-rng, rng + 1):
				var p: Vector2i = z["pos"] + Vector2i(dx, dy)
				if p != z["pos"] and in_bounds(p):
					out.append(p)
		return out
	for d in ranged_dirs(r["dirs"]):
		for i in range(1, rng + 1):
			var p: Vector2i = z["pos"] + d * i
			if not in_bounds(p) or cell(p) != FLOOR:
				break
			out.append(p)
			var u := unit_at(p)
			if not u.is_empty() and (u["team"] != "s" or not r.get("pierce", false)):
				break
	return out


# Procura um sobrevivente na linha de tiro e ataca. Paredes, móveis, portas
# e outros zumbis bloqueiam. Devolve o evento (ou {} se não tinha alvo).
func _ranged_attack(z: Dictionary, events: Array) -> Dictionary:
	var r: Dictionary = z["ranged"]
	var rng: int = r["range"]
	var dmg: int = r.get("dmg", 1)
	if r["dirs"] == "area":
		# Gritador: puxa o ar numa rodada (área vermelha) e grita na seguinte
		var victims := survivors().filter(func(u): return _cheb(u["pos"], z["pos"]) <= rng)
		if not z.has("aim_area"):
			if victims.is_empty():
				return {}
			z["aim_area"] = true
			var aim := {"type": "aim", "id": z["id"], "from": z["pos"], "to": z["pos"]}
			events.append(aim)
			_log("%s está puxando o ar..." % z["name"])
			return aim
		z.erase("aim_area")
		if victims.is_empty():
			return {}
		var ev := {"type": "scream", "id": z["id"], "at": z["pos"], "range": rng}
		events.append(ev)
		_log("%s soltou um grito!" % z["name"])
		for v in victims:
			_hurt(v, dmg, z["name"])
		z["cool"] = int(r.get("reload", 1))
		if z.has("calls"):
			# o grito chama os outros zumbis: todos dão um passo extra
			for o in zombies():
				if o != z and not o["hidden"] and o["stun"] == 0 and status == "playing":
					_zombie_act(o, events, true)
		return ev
	# Ataque em linha: primeiro MIRA (o jogador vê a linha vermelha) e só
	# atira na ação seguinte se ainda houver alguém na linha.
	if z.has("aim"):
		var aim_d: Vector2i = z["aim"]
		z.erase("aim")
		var line := _line_scan(z, aim_d)
		if not line["hits"].is_empty():
			return _fire(z, line, events)
	for d in ranged_dirs(r["dirs"]):
		var line := _line_scan(z, d)
		if line["hits"].is_empty():
			continue
		z["aim"] = d
		var ev := {"type": "aim", "id": z["id"], "from": z["pos"], "to": line["end"]}
		events.append(ev)
		_log("%s está mirando em você!" % z["name"])
		return ev
	return {}


# Casas da linha de tiro de um zumbi numa direção: até onde vai e quem acerta.
func _line_scan(z: Dictionary, d: Vector2i) -> Dictionary:
	var r: Dictionary = z["ranged"]
	var hits: Array = []
	var end: Vector2i = z["pos"]
	for i in range(1, int(r["range"]) + 1):
		var p: Vector2i = z["pos"] + d * i
		if not in_bounds(p) or cell(p) != FLOOR:
			break
		end = p
		var u := unit_at(p)
		if u.is_empty():
			continue
		if u["team"] != "s":
			break  # outro zumbi na frente
		hits.append(u)
		if not r.get("pierce", false):
			break
	return {"hits": hits, "end": end, "dir": d}


func _fire(z: Dictionary, line: Dictionary, events: Array) -> Dictionary:
	var r: Dictionary = z["ranged"]
	var hits: Array = line["hits"]
	var end: Vector2i = line["end"]
	var ev := {"type": "shoot", "id": z["id"], "from": z["pos"], "to": end, "kind": z["type"],
		"targets": hits.map(func(u): return u["id"])}
	events.append(ev)
	_log("%s atacou de longe!" % z["name"])
	for u in hits:
		_hurt(u, int(r.get("dmg", 1)), z["name"])
	if z.has("acid"):
		hazards[end] = 2  # queima por 2 rodadas
		ev["acid"] = end
	z["cool"] = int(r.get("reload", 1))
	return ev


# Passo que mais afasta o zumbi dos sobreviventes próximos.
func _step_away(z: Dictionary, near: Array) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_s := _min_dist(z["pos"], near)
	for p in zombie_steps(z["pos"], z["moves"], true):
		var sc := _min_dist(p, near)
		if sc > best_s:
			best_s = sc
			best = p
	return best


func _min_dist(p: Vector2i, near: Array) -> int:
	var m := INF
	for t in near:
		m = mini(m, _cheb(t["pos"], p))
	return m


func _try_revive(z: Dictionary) -> Dictionary:
	for g in graveyard:
		var p: Vector2i = g["pos"]
		if _cheb(p, z["pos"]) <= 2 and cell(p) == FLOOR and unit_at(p).is_empty():
			graveyard.erase(g)
			var t: String = g["type"] if g["type"] in ["Z", "R", "N", "G"] else "Z"
			var nz := _spawn("z", t, p)
			nz["tick"] = -1
			_log("%s levantou um %s!" % [z["name"], nz["name"]])
			return {"type": "revive", "id": z["id"], "new_id": nz["id"], "at": p}
	return {}


# Ácido no chão: queima quem está em cima e some com o tempo.
func _acid_tick(events: Array) -> void:
	for p in hazards.keys():
		var u := unit_at(p)
		if not u.is_empty() and u["team"] == "s":
			events.append({"type": "acid", "at": p, "target": u["id"]})
			_hurt(u, 1, "O ácido")
		hazards[p] -= 1
		if hazards[p] <= 0:
			hazards.erase(p)


# Inchado estoura: 1 de dano em todas as peças das 8 casas em volta.
func _explode(z: Dictionary, events: Array) -> void:
	if z.get("exploded", false):
		return
	z["exploded"] = true
	units.erase(z)
	graveyard.append({"pos": z["pos"], "type": z["type"]})
	events.append({"type": "explode", "id": z["id"], "at": z["pos"]})
	_log("%s explodiu!" % z["name"])
	for d in KING_DIRS:
		var u := unit_at(z["pos"] + d)
		if u.is_empty():
			continue
		if u["team"] == "s":
			_hurt(u, 1, "A explosão")
		else:
			u["hp"] -= 1
			if u["hp"] <= 0:
				_kill(u, events)


# Zumbi morreu: vai para o cemitério, larga item; o Inchado estoura.
func _kill(z: Dictionary, events: Array) -> void:
	if not units.has(z):
		return
	if z.has("explodes"):
		_explode(z, events)
		return
	units.erase(z)
	graveyard.append({"pos": z["pos"], "type": z["type"]})
	if z.has("drops") and not items.has(z["pos"]):
		items[z["pos"]] = z["drops"]
		_log("%s largou %s." % [z["name"], ITEMS[z["drops"]]["name"]])


# Pontos de vida que um golpe tira (a Fita Vermelha só protege o Sobrevivente).
func damage_points(dmg: int, victim := {}) -> int:
	var a: int = armor if victim.is_empty() or victim["main"] else 0
	return roundi(dmg * HIT * (100 - a) / 100.0)


# Dano em um sobrevivente. Todos têm vida; com 0 o personagem morre.
# O Sobrevivente morto acaba a fase; os outros levantam como zumbi.
func _hurt(victim: Dictionary, dmg: int, source: String) -> void:
	if not units.has(victim):
		return
	victim["hp"] -= damage_points(dmg, victim)
	_log("%s feriu %s! (vida %d)" % [source, victim["name"], maxi(victim["hp"], 0)])
	if victim["hp"] > 0:
		return
	units.erase(victim)
	if victim["main"]:
		_lose("O Sobrevivente foi pego pelos zumbis.")
		return
	var nz := _spawn("z", "Z", victim["pos"])
	nz["tick"] = -1  # não age na mesma rodada
	_log("%s morreu e virou zumbi!" % victim["name"])
	if victim["required"]:
		_lose("%s morreu." % victim["name"])


# Peão que chega ao fim do tabuleiro vira outro zumbi (como no xadrez).
func _promote(z: Dictionary, type: String) -> void:
	var def: Dictionary = ZOMBIES[type]
	_log("%s chegou ao fim e virou %s!" % [z["name"], def["name"]])
	z["type"] = type
	z["name"] = def["name"]
	z["hp"] = def["hp"]
	z["max_hp"] = def["hp"]
	z["moves"] = def["moves"]
	z["every"] = def.get("every", 1)
	z["attack"] = def.get("attack", def["moves"])
	z["tick"] = 0


func _attack(z: Dictionary, victim: Dictionary) -> Dictionary:
	var ev := {"type": "attack", "id": z["id"], "target": victim["id"], "at": victim["pos"]}
	var was_main: bool = victim["main"]
	if was_main and z["charge"] and victim["hp"] > damage_points(1, victim):
		var to: Vector2i = victim["pos"] + (victim["pos"] - z["pos"])
		if in_bounds(to) and cell(to) == FLOOR and unit_at(to).is_empty():
			victim["pos"] = to
			ev["pushed_to"] = to
			_log("%s empurrou o Sobrevivente!" % z["name"])
	_hurt(victim, 1, z["name"])
	if not was_main and not units.has(victim):
		ev["converted"] = units[-1]["id"]
	if was_main and not units.has(victim):
		ev["killed"] = true
	return ev


func _check_end() -> void:
	if status != "playing" or not survivors().is_empty():
		return
	for t in required:
		if not rescued.has(t):
			_lose("Nem todos chegaram à saída.")
			return
	status = "won"
	end_reason = "Todos que restavam chegaram à saída!"


func _lose(reason: String) -> void:
	status = "lost"
	end_reason = reason


func _log(msg: String) -> void:
	log_lines.append(msg)
	if log_lines.size() > 40:
		log_lines.pop_front()
