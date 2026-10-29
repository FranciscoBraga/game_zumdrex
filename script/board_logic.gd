extends RefCounted
# Regras do Xadrez Zumbi. Não desenha nada: a cena (game.gd) lê este estado
# e anima os eventos. Isso permite testar as regras sem abrir janela.

const FLOOR := 0
const BLOCK := 1  # mesa, entulho, carro: bloqueia passagem e tiro
const WALL := 2
const DOOR := 3   # porta trancada: abre com chave

const INF := 1 << 20

const WAZIR_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const KING_DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
	Vector2i(1, -1), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-1, 1)]
const KNIGHT_DIRS: Array[Vector2i] = [
	Vector2i(1, -2), Vector2i(-1, -2), Vector2i(2, -1), Vector2i(-2, -1),
	Vector2i(2, 1), Vector2i(-2, 1), Vector2i(1, 2), Vector2i(-1, 2)]

# Movimentos inspirados no xadrez:
#   king   = 1 casa em qualquer direção (rei)
#   wazir  = 1 casa reto (sem diagonal)
#   knight = em "L" (cavalo), pula obstáculos
const SURVIVORS := {
	"P": {"name": "Sobrevivente", "hp": 3, "moves": "king", "main": true},
	"D": {"name": "Cachorro", "hp": 1, "moves": "knight"},
	"B": {"name": "Bebê Chorão", "hp": 1, "moves": "wazir", "cries": true, "required": true},
}

# every = age a cada N turnos (o Tanque é lento)
const ZOMBIES := {
	"Z": {"name": "Zumbi Comum", "hp": 2, "moves": "wazir", "every": 1},
	"R": {"name": "Corredor", "hp": 1, "moves": "king", "every": 1},
	"T": {"name": "Tanque", "hp": 4, "moves": "wazir", "every": 2},
	"K": {"name": "Saltador", "hp": 2, "moves": "knight", "every": 2},
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
}

var size := Vector2i.ZERO
var cells := PackedInt32Array()
var decor := {}      # Vector2i -> letra do obstáculo ("M", "X", "W", "d")
var items := {}      # Vector2i -> letra do item
var units: Array = []  # cada unidade é um Dictionary
var next_id := 1
var backpack: Array = []
var bag_capacity := 3
var weapon := "pistol"
var ammo := 3
var status := "playing"  # playing | won | lost
var end_reason := ""
var rescued: Array = []
var required: Array = []  # tipos que precisam chegar à saída (ex.: bebê)
var turn := 1
var log_lines: Array = []


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
	status = "playing"
	end_reason = ""
	turn = 1
	bag_capacity = data.get("backpack", 3)
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
	}
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
	b.weapon = weapon
	b.ammo = ammo
	b.status = status
	b.end_reason = end_reason
	b.rescued = rescued.duplicate()
	b.required = required.duplicate()
	b.turn = turn
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


func dirs_for(moves: String) -> Array[Vector2i]:
	match moves:
		"wazir":
			return WAZIR_DIRS
		"knight":
			return KNIGHT_DIRS
	return KING_DIRS


func weapon_info() -> Dictionary:
	return WEAPONS[weapon]


func valid_moves(u: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if u.is_empty() or u["team"] != "s":
		return out
	for d in dirs_for(u["moves"]):
		var p: Vector2i = u["pos"] + d
		if not in_bounds(p):
			continue
		var c := cell(p)
		if c == BLOCK or c == WALL:
			continue
		if c == DOOR and not (u["main"] and backpack.has("k")):
			continue
		if not unit_at(p).is_empty():
			continue
		out.append(p)
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
	if def["bag"]:
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
			units.erase(z)
			_log("%s abatido!" % z["name"])
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
	return {"from": m["pos"], "end": end, "hits": hits, "arrow": w.get("arrow", false), "dropped": dropped}


func use_item(index: int) -> bool:
	var m := main_unit()
	if status != "playing" or m.is_empty() or index < 0 or index >= backpack.size():
		return false
	if backpack[index] == "h" and m["hp"] < m["max_hp"]:
		m["hp"] = mini(m["hp"] + 2, m["max_hp"])
		backpack.remove_at(index)
		_log("Usou Kit Médico (vida %d)." % m["hp"])
		return true
	return false


func wait_turn() -> void:
	_log("Esperou.")


# ---------- turno dos zumbis ----------

# Distância (em jogadas) de cada casa até o alvo mais próximo, usando o
# movimento do zumbi. Ignora unidades no caminho; paredes, mesas e portas bloqueiam.
func distance_field(sources: Array, moves: String) -> Dictionary:
	var dist := {}
	var queue: Array = []
	for p in sources:
		dist[p] = 0
		queue.append(p)
	var dirs := dirs_for(moves)
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		for d in dirs:
			var n: Vector2i = p + d
			if in_bounds(n) and cell(n) == FLOOR and not dist.has(n):
				dist[n] = dist[p] + 1
				queue.append(n)
	return dist


func _targets() -> Array:
	var s := survivors()
	var criers := s.filter(func(u): return u["cries"])
	return criers if not criers.is_empty() else s


func run_zombie_turn() -> Array:
	var events: Array = []
	if status != "playing":
		return events
	for z in zombies():
		if status != "playing":
			break
		if not units.has(z):
			continue
		z["tick"] += 1
		if z["tick"] % int(z["every"]) != 0:
			continue
		var dirs := dirs_for(z["moves"])
		# 1) se um sobrevivente está ao alcance, ataca
		var victim := {}
		for d in dirs:
			var o := unit_at(z["pos"] + d)
			if not o.is_empty() and o["team"] == "s":
				victim = o
				break
		if not victim.is_empty():
			events.append(_attack(z, victim))
			continue
		# 2) senão, anda pelo caminho mais curto até o alvo
		var targets := _targets()
		if targets.is_empty():
			break
		var dist := distance_field(targets.map(func(u): return u["pos"]), z["moves"])
		var best_d: int = dist.get(z["pos"], INF)
		var best := Vector2i(-1, -1)
		for d in dirs:
			var p: Vector2i = z["pos"] + d
			if not in_bounds(p) or cell(p) != FLOOR or not unit_at(p).is_empty():
				continue
			var dp: int = dist.get(p, INF)
			if dp < best_d:
				best_d = dp
				best = p
		if best.x >= 0:
			events.append({"type": "move", "id": z["id"], "from": z["pos"], "to": best})
			z["pos"] = best
	_check_end()
	if status == "playing":
		turn += 1
	return events


func _attack(z: Dictionary, victim: Dictionary) -> Dictionary:
	var ev := {"type": "attack", "id": z["id"], "target": victim["id"], "at": victim["pos"]}
	if victim["main"]:
		victim["hp"] -= 1
		_log("%s mordeu o Sobrevivente! (vida %d)" % [z["name"], victim["hp"]])
		if victim["hp"] <= 0:
			units.erase(victim)
			ev["killed"] = true
			_lose("O Sobrevivente foi pego pelos zumbis.")
	else:
		# sobreviventes frágeis viram zumbis
		units.erase(victim)
		var nz := _spawn("z", "Z", victim["pos"])
		nz["tick"] = -1  # não age na mesma rodada
		ev["converted"] = nz["id"]
		_log("%s virou zumbi!" % victim["name"])
		if victim["required"]:
			_lose("%s foi transformado." % victim["name"])
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
