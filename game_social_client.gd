class_name PaperGameSocialClient
extends Node

signal notice(message: String, error: bool)
signal identity_changed
var service_url: String = ""
var token: String = ""
var profile: Dictionary = {}
var pending: int = 0
var generation: int = 0
var last_latency_ms: int = -1

func load_config() -> void :
	var config: ConfigFile = ConfigFile.new()
	if config.load("user://server.cfg") == OK:
		var saved: String = str(config.get_value("online", "service_url", ""))
		if valid_service(saved): service_url = saved.trim_suffix("/")

static func valid_service(value: String) -> bool:
	if value.is_empty(): return true
	if value.contains("@") or value.contains("?") or value.contains("#") or value.contains("\\") or value.contains(" "): return false
	var pattern: RegEx = RegEx.new()
	pattern.compile("^https://[a-zA-Z0-9.-]+(:[0-9]{1,5})?(/[a-zA-Z0-9_./-]*)?$")
	if pattern.search(value) != null: return true
	pattern.compile("^http://(127\\.0\\.0\\.1|localhost):[0-9]{1,5}(/[a-zA-Z0-9_./-]*)?$")
	return pattern.search(value) != null

func configure(value: String) -> bool:
	var cleaned: String = value.strip_edges().trim_suffix("/")
	if not valid_service(cleaned): notice.emit("Utilise une adresse HTTPS, ou localhost pour un essai sur cet appareil.", true);return false
	if service_url != cleaned:
		service_url = cleaned;token = "";profile.clear();generation += 1;identity_changed.emit()
	var config: ConfigFile = ConfigFile.new()
	config.load("user://server.cfg")
	config.set_value("online", "service_url", service_url)
	var result: Error = config.save("user://server.cfg")
	if result != OK: notice.emit("L’adresse n’a pas pu être enregistrée sur cet appareil.", true)
	return result == OK

func api(path: String, data: Dictionary = {}, method: int = HTTPClient.METHOD_GET) -> Dictionary:
	if service_url.is_empty(): return _failure("Aucun service en ligne configuré.")
	if not path.begins_with("/") or path.contains("://") or path.contains("..") or path.contains("\\"): return _failure("Adresse de service invalide.")
	var epoch: int = generation
	var request: HTTPRequest = HTTPRequest.new()
	request.timeout = 18;request.body_size_limit = 2 * 1024 * 1024;request.max_redirects = 0;add_child(request)
	var headers: PackedStringArray = ["Content-Type: application/json"]
	if not token.is_empty(): headers.append("Authorization: Bearer " + token)
	pending += 1
	var started: int = Time.get_ticks_msec()
	var err: Error = request.request(service_url + path, headers, method, JSON.stringify(data) if method != HTTPClient.METHOD_GET else "")
	if err != OK: request.queue_free();pending -= 1;return _failure("Connexion au service impossible.")
	var response: Array = await request.request_completed
	request.queue_free();pending -= 1
	if epoch != generation: return {"error": "Le service a changé.", "status": 0}
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS: return _failure("Le service ne répond pas. Vérifie ta connexion et son adresse.")
	last_latency_ms = Time.get_ticks_msec() - started
	var parsed: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	if not parsed is Dictionary: return _failure("Le service a renvoyé une réponse illisible.")
	parsed["status"] = int(response[1])
	if int(response[1]) >= 400:
		if int(response[1]) == 401 and not path.begins_with("/v1/auth/"): token = "";profile.clear();identity_changed.emit()
		notice.emit(str(parsed.get("error", "Demande refusée par le service.")), true)
	return parsed

func _failure(message: String) -> Dictionary:
	notice.emit(message, true)
	return {"error": message, "status": 0}

func authenticate(username: String, password: String, nickname: String, register: bool) -> bool:
	if pending > 0: return false
	var response: Dictionary = await api("/v1/auth/register" if register else "/v1/auth/login", {"username": username, "password": password, "nickname": nickname}, HTTPClient.METHOD_POST)
	if not response.get("user") is Dictionary or str(response.get("token", "")).is_empty(): return false
	token = str(response.token);profile = response.user;identity_changed.emit()
	return true

func logout() -> void :
	if not token.is_empty(): await api("/v1/auth/logout", {}, HTTPClient.METHOD_POST)
	token = "";profile.clear();generation += 1;identity_changed.emit()

func refresh_profile() -> bool:
	if token.is_empty(): return false
	var response: Dictionary = await api("/v1/me")
	if response.get("user") is Dictionary: profile = response.user;identity_changed.emit();return true
	return false
