class_name PaperNetCodec
extends RefCounted

# Format binaire compact des instantanés de l'hôte et des messages de mouvement du client (0.17).
# Avant : un tableau de Variant (noms d'effets en toutes lettres) passé par var_to_bytes puis
# deflate, plus huit arguments d'appel. Maintenant : un seul tableau d'octets, effets désignés par
# un numéro (table construite depuis PaperActor.NET_EFFECT_RULES, identique chez tous les joueurs),
# vitesses et visée quantifiées, deflate seulement s'il fait gagner de la place.

const VERSION: int = 17
const FLAG_DEFLATE: int = 1
const ROW_ALIVE: int = 1
const ROW_LMS: int = 2
const ROW_FOLLOWED: int = 4
const ROW_OWNED: int = 8
const ROW_OM_STAMINA: int = 16
const KEY_STRING: int = 255
const T_TRUE: int = 0
const T_FLOAT: int = 1
const T_INT: int = 2
const T_BYTE: int = 3
const T_STRING: int = 4
const T_VECTOR: int = 5
const T_FALSE: int = 6
const T_VARIANT: int = 7
const EXTRA_KEYS: Array[String] = ["grounded", "escaped", "outlet_position", "grind_direction", "bleedout", "boost_level", "slow_factor", "boost_factor", "carry_speed_factor"]

static var _keys: Array = []
static var _index: Dictionary = {}


static func _table() -> void :
	if not _keys.is_empty(): return
	var names: Dictionary = {}
	for key: Variant in PaperActor.NET_EFFECT_RULES: names[str(key)] = true
	for key: String in PaperActor.NET_QTE_KEYS: names[key] = true
	for key: String in EXTRA_KEYS: names[key] = true
	_keys = names.keys()
	_keys.sort()
	for i: int in range(mini(_keys.size(), KEY_STRING)): _index[_keys[i]] = i


static func _put_vel(buffer: StreamPeerBuffer, v: Vector3) -> void :
	for c: float in [v.x, v.y, v.z]: buffer.put_16(clampi(int(round(c * 100.0)), -32767, 32767))


static func _get_vel(buffer: StreamPeerBuffer) -> Vector3:
	return Vector3(buffer.get_16() / 100.0, buffer.get_16() / 100.0, buffer.get_16() / 100.0)


static func _put_dir(buffer: StreamPeerBuffer, v: Vector3) -> void :
	var n: Vector3 = v.normalized() if v.length_squared() > 0.000001 else Vector3.FORWARD
	for c: float in [n.x, n.y, n.z]: buffer.put_16(clampi(int(round(c * 32767.0)), -32767, 32767))


static func _get_dir(buffer: StreamPeerBuffer) -> Vector3:
	var v: Vector3 = Vector3(buffer.get_16(), buffer.get_16(), buffer.get_16()) / 32767.0
	return v.normalized() if v.length_squared() > 0.000001 else Vector3.FORWARD


static func _put_pos(buffer: StreamPeerBuffer, v: Vector3) -> void :
	buffer.put_float(v.x);buffer.put_float(v.y);buffer.put_float(v.z)


static func _get_pos(buffer: StreamPeerBuffer) -> Vector3:
	return Vector3(buffer.get_float(), buffer.get_float(), buffer.get_float())


static func _put_text(buffer: StreamPeerBuffer, text: String) -> void :
	var bytes: PackedByteArray = text.to_utf8_buffer()
	if bytes.size() > 255: bytes = bytes.slice(0, 255)
	buffer.put_u8(bytes.size());buffer.put_data(bytes)


static func _get_text(buffer: StreamPeerBuffer) -> String:
	var size: int = buffer.get_u8()
	if size == 0: return ""
	var got: Array = buffer.get_data(size)
	return (got[1] as PackedByteArray).get_string_from_utf8() if int(got[0]) == OK else ""


static func _put_value(buffer: StreamPeerBuffer, value: Variant) -> void :
	if value is bool:
		buffer.put_u8(T_TRUE if value else T_FALSE)
	elif value is int:
		if value >= 0 and value <= 255: buffer.put_u8(T_BYTE);buffer.put_u8(value)
		elif value >= -2147483648 and value <= 2147483647: buffer.put_u8(T_INT);buffer.put_32(value)
		else: buffer.put_u8(T_FLOAT);buffer.put_double(float(value))
	elif value is float:
		buffer.put_u8(T_FLOAT);buffer.put_float(value)
	elif value is String or value is StringName:
		buffer.put_u8(T_STRING);_put_text(buffer, str(value))
	elif value is Vector3:
		buffer.put_u8(T_VECTOR);_put_pos(buffer, value)
	else:
		var raw: PackedByteArray = var_to_bytes(value)
		buffer.put_u8(T_VARIANT);buffer.put_u16(raw.size());buffer.put_data(raw)


static func _get_value(buffer: StreamPeerBuffer) -> Variant:
	match buffer.get_u8():
		T_TRUE: return true
		T_FALSE: return false
		T_BYTE: return buffer.get_u8()
		T_INT: return buffer.get_32()
		T_FLOAT: return buffer.get_float()
		T_STRING: return _get_text(buffer)
		T_VECTOR: return _get_pos(buffer)
		T_VARIANT:
			var size: int = buffer.get_u16()
			var got: Array = buffer.get_data(size)
			return bytes_to_var(got[1]) if int(got[0]) == OK else null
	return null


# --- Instantané de l'hôte -----------------------------------------------------------------------

static func encode_snapshot(world: Node) -> PackedByteArray:
	_table()
	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	buffer.put_double(float(world.clock))
	buffer.put_float(float(world.time_left))
	_put_text(buffer, str(world.phase))
	buffer.put_u8(1 if world.lms else 0)
	buffer.put_32(int(world.blocked_door))
	buffer.put_u32(int(world.round_serial) & 0xFFFFFFFF)
	buffer.put_u8(mini(world.actors.size(), 255))
	var written: int = 0
	for key: Variant in world.actors:
		if written >= 255: break
		written += 1
		var a: PaperActor = world.actors[key]
		var m: PaperNetMotion = a.net_motion
		var followed: bool = m != null and m.remote
		var om_stamina: bool = a.stamina == -1.0 and a.max_stamina == -1.0
		var flags: int = (ROW_ALIVE if a.alive else 0) | (ROW_LMS if a.lms else 0) | (ROW_FOLLOWED if followed else 0) | (ROW_OWNED if followed and m.owned else 0) | (ROW_OM_STAMINA if om_stamina else 0)
		buffer.put_32(int(a.id))
		buffer.put_u8(flags)
		_put_pos(buffer, a.global_position)
		_put_vel(buffer, a.velocity)
		_put_dir(buffer, a.aim)
		if followed: buffer.put_u8(m.epoch & 255)
		buffer.put_float(a.hp);buffer.put_float(a.max_hp)
		if not om_stamina: buffer.put_float(a.stamina);buffer.put_float(a.max_stamina)
		var mask: int = 0
		for slot: int in range(6):
			if float(a.cooldowns.get(slot, 0.0)) > 0.0: mask |= 1 << slot
		buffer.put_u8(mask)
		for slot: int in range(6):
			if mask & (1 << slot): buffer.put_u16(clampi(int(ceil(float(a.cooldowns.get(slot, 0.0)) * 100.0)), 1, 65535))
		var fx: Dictionary = a.network_effects()
		buffer.put_u8(mini(fx.size(), 255))
		var count: int = 0
		for name: Variant in fx:
			if count >= 255: break
			count += 1
			var index: int = int(_index.get(str(name), KEY_STRING))
			buffer.put_u8(index)
			if index == KEY_STRING: _put_text(buffer, str(name))
			_put_value(buffer, fx[name])
	var raw: PackedByteArray = buffer.data_array
	var packed: PackedByteArray = raw.compress(FileAccess.COMPRESSION_DEFLATE)
	var out: StreamPeerBuffer = StreamPeerBuffer.new()
	out.put_u8(VERSION)
	if packed.size() + 3 < raw.size():
		out.put_u8(FLAG_DEFLATE);out.put_u16(raw.size());out.put_data(packed)
	else:
		out.put_u8(0);out.put_data(raw)
	return out.data_array


# Décode un instantané : {t, remaining, phase, lms, door, serial, rows: [{id, flags, pos, vel, aim,
# epoch, hp, max_hp, stamina, max_stamina, cooldowns, effects}]} ; vide si le paquet est invalide.
static func decode_snapshot(packed: PackedByteArray) -> Dictionary:
	_table()
	if packed.size() < 2 or packed[0] != VERSION: return {}
	var raw: PackedByteArray
	if packed[1] & FLAG_DEFLATE:
		if packed.size() < 4: return {}
		var size: int = packed.decode_u16(2)
		raw = packed.slice(4).decompress(size, FileAccess.COMPRESSION_DEFLATE)
		if raw.size() != size: return {}
	else: raw = packed.slice(2)
	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	buffer.data_array = raw
	var data: Dictionary = {}
	data.t = buffer.get_double();data.remaining = buffer.get_float();data.phase = _get_text(buffer)
	data.lms = buffer.get_u8() != 0;data.door = buffer.get_32();data.serial = buffer.get_u32()
	var rows: Array = []
	for i: int in range(buffer.get_u8()):
		if buffer.get_position() >= raw.size(): return {}
		var row: Dictionary = {}
		row.id = buffer.get_32()
		var flags: int = buffer.get_u8()
		row.flags = flags
		row.pos = _get_pos(buffer);row.vel = _get_vel(buffer);row.aim = _get_dir(buffer)
		row.epoch = buffer.get_u8() if flags & ROW_FOLLOWED else -1
		row.hp = buffer.get_float();row.max_hp = buffer.get_float()
		if flags & ROW_OM_STAMINA: row.stamina = -1.0;row.max_stamina = -1.0
		else: row.stamina = buffer.get_float();row.max_stamina = buffer.get_float()
		var mask: int = buffer.get_u8()
		var cooldowns: Dictionary = {}
		for slot: int in range(6): cooldowns[slot] = buffer.get_u16() / 100.0 if mask & (1 << slot) else 0.0
		row.cooldowns = cooldowns
		var fx: Dictionary = {}
		for k: int in range(buffer.get_u8()):
			var index: int = buffer.get_u8()
			var name: String = _get_text(buffer) if index == KEY_STRING else (str(_keys[index]) if index < _keys.size() else "")
			var value: Variant = _get_value(buffer)
			if not name.is_empty(): fx[name] = value
		row.effects = fx
		rows.append(row)
	if buffer.get_position() > raw.size(): return {}
	data.rows = rows
	return data


# --- Message de mouvement du client -------------------------------------------------------------

# frame : numéro du pas physique du client (son horloge, exacte) ; tv : instant de l'hôte affiché.
static func encode_report(seq: int, epoch: int, flags: int, frame: int, tv: float, pos: Vector3, vel: Vector3, move: Vector3, aim: Vector3, jumps: int, rolls: int) -> PackedByteArray:
	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	buffer.put_u16(seq & 0xFFFF)
	buffer.put_u8(epoch & 255)
	buffer.put_u8(flags)
	buffer.put_u32(frame & 0xFFFFFFFF)
	buffer.put_float(tv)
	if flags & PaperNetMotion.REPORT_FLAG_POSITION:
		_put_pos(buffer, pos)
		_put_vel(buffer, vel)
	buffer.put_8(clampi(int(round(move.x * 127.0)), -127, 127))
	buffer.put_8(clampi(int(round(move.z * 127.0)), -127, 127))
	_put_dir(buffer, aim)
	buffer.put_u8(jumps & 255)
	buffer.put_u8(rolls & 255)
	return buffer.data_array


static func decode_report(packed: PackedByteArray) -> Dictionary:
	if packed.size() < 22 or packed.size() > 96: return {}
	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	buffer.data_array = packed
	var report: Dictionary = {}
	report.seq = buffer.get_u16()
	report.epoch = buffer.get_u8()
	report.flags = buffer.get_u8()
	report.frame = buffer.get_u32()
	report.tc = float(report.frame) / float(Engine.physics_ticks_per_second)
	report.tv = float(buffer.get_float())
	report.has_position = (int(report.flags) & PaperNetMotion.REPORT_FLAG_POSITION) != 0
	if report.has_position:
		if packed.size() < 40: return {}
		report.pos = _get_pos(buffer)
		report.vel = _get_vel(buffer)
	else:
		report.pos = Vector3.ZERO;report.vel = Vector3.ZERO
	report.move = Vector3(buffer.get_8() / 127.0, 0.0, buffer.get_8() / 127.0)
	report.aim = _get_dir(buffer)
	report.jumps = buffer.get_u8()
	report.rolls = buffer.get_u8()
	for key: String in ["tc", "tv"]:
		if not is_finite(float(report[key])): return {}
	if report.has_position and not (Vector3(report.pos).is_finite() and Vector3(report.vel).is_finite()): return {}
	return report
