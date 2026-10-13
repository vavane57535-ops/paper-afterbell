class_name PaperRules
extends RefCounted

const IDS: Array[String] = ["om"]
const LABELS: Dictionary = {"om": "OM"}
const PROTOCOL: int = 16

static func normalize(value: String) -> String:
	return "om"

static func is_om(value: String) -> bool:
	return normalize(value) == "om"


const OM_SURVIVOR_SPRINT: float = 10.2
const OM_KILLER_SPRINT: float = 12.2
const OM_JUMP_COOLDOWN: float = 2.0
const OM_JUMP_VELOCITY: float = 12.4
const OM_GRAVITY: float = 24.0
const OM_CRAWL_SPEED: float = 0.7
const OM_BOOST_FACTOR: float = 2.0
const OM_BOOST_DURATION: float = 4.0
const OM_BOOST_COOLDOWN: float = 40.0
const TRUE_FORM_SECONDS: float = 30.0
const TRUE_FORM_STUNS: int = 15
const TRUE_FORM_SPEED_FACTOR: float = 1.7
