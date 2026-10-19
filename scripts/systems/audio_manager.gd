extends Node
## 音频管理（script_patch 热重载；autoload 名：AudioManager）。
##
## 约定：素材不存在时静默降级，返回 false，不影响游戏逻辑。
##   assets/audio/sfx/<id>.ogg|wav|mp3
##   assets/audio/music/<id>.ogg|wav|mp3

const SFX_DIR := "res://assets/audio/sfx"
const MUSIC_DIR := "res://assets/audio/music"
const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"
const SFX_VOICES := 8
const EXTENSIONS := ["ogg", "wav", "mp3"]

var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _music_id := ""
var _next_voice := 0
var _warned: Dictionary = {}


func _ready() -> void:
	_ensure_bus(SFX_BUS)
	_ensure_bus(MUSIC_BUS)
	for i in SFX_VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		player.name = "Sfx%d" % i
		add_child(player)
		_sfx_players.append(player)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	_music_player.name = "Music"
	add_child(_music_player)
	apply_volumes()


func _ensure_bus(bus_name: String) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		return
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


func apply_volumes() -> void:
	var progress: Node = null
	if is_inside_tree():
		progress = get_node_or_null("/root/GameProgress")
	var music := 0.7
	var sfx := 0.8
	var music_muted := false
	var sfx_muted := false
	if progress != null:
		music = float(progress.music_volume)
		sfx = float(progress.sfx_volume)
		music_muted = bool(progress.music_muted)
		sfx_muted = bool(progress.sfx_muted)
	_apply_bus(MUSIC_BUS, music, music_muted)
	_apply_bus(SFX_BUS, sfx, sfx_muted)


func _apply_bus(bus_name: String, volume: float, muted: bool) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var silent := muted or volume <= 0.001
	AudioServer.set_bus_mute(index, silent)
	AudioServer.set_bus_volume_db(index, linear_to_db(clampf(volume, 0.001, 1.0)))


func play_sfx(id: String) -> bool:
	if String(id).is_empty() or _sfx_players.is_empty():
		return false
	var stream := _find_stream(SFX_DIR, id)
	if stream == null:
		_warn_missing("sfx", id)
		return false
	var player := _sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx_players.size()
	player.stream = stream
	player.play()
	return true


func play_music(id: String) -> bool:
	if String(id).is_empty() or _music_player == null:
		return false
	if id == _music_id and _music_player.playing:
		return true
	var stream := _find_stream(MUSIC_DIR, id)
	if stream == null:
		_warn_missing("music", id)
		return false
	_music_id = id
	_music_player.stream = stream
	_music_player.play()
	return true


func stop_music() -> void:
	_music_id = ""
	if _music_player != null:
		_music_player.stop()


func _find_stream(directory: String, id: String) -> AudioStream:
	for extension in EXTENSIONS:
		var path := "%s/%s.%s" % [directory, id, extension]
		if ResourceLoader.exists(path):
			var resource := load(path)
			if resource is AudioStream:
				return resource as AudioStream
	return null


func _warn_missing(kind: String, id: String) -> void:
	var key := "%s:%s" % [kind, id]
	if _warned.has(key):
		return
	_warned[key] = true
	print("[AudioManager] 缺少%s素材：%s（静默降级）" % [kind, id])
