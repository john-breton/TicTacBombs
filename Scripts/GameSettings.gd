extends Node

## Global game settings — autoloaded as "GameSettings".

enum PlayMode { LOCAL, VS_CPU }
enum CPUDifficulty { EASY, MEDIUM, HARD }

# --- Game Settings ---
var board_size: int = 7
var num_bombs: int = 5
var win_length: int = 3
var play_mode: int = PlayMode.LOCAL
var cpu_difficulty: int = CPUDifficulty.MEDIUM

# --- Graphics Settings ---
var fullscreen: bool = false
var vsync: bool = true
var window_size_index: int = 1  # 0=720p, 1=900p, 2=1080p, 3=1440p
var sound_enabled: bool = true

const WINDOW_SIZES = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const WINDOW_SIZE_LABELS = ["1280×720", "1600×900", "1920×1080", "2560×1440"]

const SETTINGS_PATH = "user://settings.cfg"


func _ready():
	load_settings()
	apply_graphics()


# ============================================================
#  APPLY GRAPHICS
# ============================================================

func apply_graphics():
	# Fullscreen
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# Get the screen the window is currently on
		var current_screen = DisplayServer.window_get_current_screen()
		var screen_size = DisplayServer.screen_get_size(current_screen)
		var screen_pos = DisplayServer.screen_get_position(current_screen)

		# Clamp window size to fit on current screen
		var win_size = WINDOW_SIZES[window_size_index]
		win_size.x = mini(win_size.x, screen_size.x - 40)
		win_size.y = mini(win_size.y, screen_size.y - 80)

		get_window().size = win_size
		# Center window on the current screen (not just primary)
		var offset = (screen_size - win_size) / 2
		get_window().position = screen_pos + Vector2i(max(offset.x, 0), max(offset.y, 0))

	# V-Sync
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


# ============================================================
#  SAVE / LOAD
# ============================================================

func save_settings():
	var config = ConfigFile.new()

	config.set_value("graphics", "fullscreen", fullscreen)
	config.set_value("graphics", "vsync", vsync)
	config.set_value("graphics", "window_size_index", window_size_index)
	config.set_value("audio", "sound_enabled", sound_enabled)

	config.save(SETTINGS_PATH)
	print("Settings saved to %s" % SETTINGS_PATH)


func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err != OK:
		print("No settings file found, using defaults.")
		return

	fullscreen = config.get_value("graphics", "fullscreen", fullscreen)
	vsync = config.get_value("graphics", "vsync", vsync)
	window_size_index = config.get_value("graphics", "window_size_index", window_size_index)
	sound_enabled = config.get_value("audio", "sound_enabled", sound_enabled)

	# Clamp to valid range
	window_size_index = clampi(window_size_index, 0, WINDOW_SIZES.size() - 1)

	print("Settings loaded.")
