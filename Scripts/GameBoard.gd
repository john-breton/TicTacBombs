extends Node2D

# --- Preload & References ---
@onready var tile_scene = preload("res://Scenes/Tile.tscn")
@onready var grid_container = $GridContainer
@onready var hud = $HUD

@export var x_texture : Texture2D
@export var o_texture : Texture2D
@export var num_bombs = 5

# --- Game State ---
enum Player { NONE, X, O, DESTROYED }
var current_player = Player.X
var game_over = false

# --- Board Data ---
var board_data = []

# --- Bomb Data ---
enum BombType { ROW, COLUMN, DIAGONAL }
var bomb_data = []
var player_x_bombs = []
var player_o_bombs = []

# --- Bomb Usage State ---
enum GameMode { PLACING_MARK, USING_BOMB }
var current_game_mode = GameMode.PLACING_MARK
var armed_bomb_type = null

# --- Constants (read from GameSettings at startup) ---
var BOARD_WIDTH = 7
var BOARD_HEIGHT = 7
var WIN_LENGTH = 3

# --- CPU ---
var vs_cpu = false
var cpu_thinking = false
var cpu_player: Node = null
const CPU_DELAY_MIN = 0.4
const CPU_DELAY_MAX = 0.8

# --- Gravity ---
var _processing_bomb = false
const NEW_TILE_BOMB_CHANCE = 0.08  # 8% chance for new tiles to contain a hidden bomb
const GRAVITY_ANIM_BASE = 0.2     # Base tween duration for 1-row fall
const GRAVITY_ANIM_PER_ROW = 0.04 # Extra time per additional row


# --- Main Setup Function ---
func _ready():
	# Dark background
	RenderingServer.set_default_clear_color(Color(0.1, 0.1, 0.13))

	# Read settings
	BOARD_WIDTH = GameSettings.board_size
	BOARD_HEIGHT = GameSettings.board_size
	WIN_LENGTH = GameSettings.win_length
	num_bombs = GameSettings.num_bombs
	grid_container.columns = BOARD_WIDTH

	# CPU setup
	vs_cpu = (GameSettings.play_mode == GameSettings.PlayMode.VS_CPU)
	if vs_cpu:
		var cpu_script = load("res://Scripts/CPUPlayer.gd")
		cpu_player = Node.new()
		cpu_player.set_script(cpu_script)
		add_child(cpu_player)
		cpu_player.setup(self)

	create_board_data()
	place_hidden_bombs()
	create_board()
	_center_board()

	# Re-center and rescale when window resizes
	get_tree().root.size_changed.connect(_center_board)

	# Wire up the HUD
	hud.setup(x_texture, o_texture)
	hud.update_turn(current_player)
	hud.bomb_selected.connect(_on_hud_bomb_selected)
	hud.bomb_cancelled.connect(_on_hud_bomb_cancelled)
	hud.restart_requested.connect(_on_restart)
	hud.menu_requested.connect(_on_main_menu)

	# In CPU mode, disable O's bomb clicks (CPU handles its own bombs)
	if vs_cpu:
		hud.set_cpu_mode(true)


# --- Center and scale the board to fit the viewport ---
var _initial_center_done = false

func _center_board():
	if not _initial_center_done:
		_initial_center_done = true
		await get_tree().process_frame

	var viewport_size = get_viewport_rect().size
	var base_board_size = grid_container.size

	# Reserve space for HUD elements (top bar + bottom inventory panels)
	var hud_padding = Vector2(60, 260)
	var available = viewport_size - hud_padding

	# Scale uniformly to fit
	var scale_factor = min(available.x / base_board_size.x, available.y / base_board_size.y)
	grid_container.scale = Vector2(scale_factor, scale_factor)

	# Center using scaled dimensions
	var scaled_size = base_board_size * scale_factor
	grid_container.position = (viewport_size - scaled_size) / 2


# --- Board Data Setup ---
func create_board_data():
	board_data.resize(BOARD_HEIGHT)
	bomb_data.resize(BOARD_HEIGHT)
	for y in range(BOARD_HEIGHT):
		board_data[y] = []
		board_data[y].resize(BOARD_WIDTH)

		bomb_data[y] = []
		bomb_data[y].resize(BOARD_WIDTH)

		for x in range(BOARD_WIDTH):
			board_data[y][x] = Player.NONE
			bomb_data[y][x] = null


# --- Board Creation ---
func create_board():
	for y in range(BOARD_HEIGHT):
		for x in range(BOARD_WIDTH):
			var new_tile = tile_scene.instantiate()

			new_tile.grid_position = Vector2i(x, y)
			new_tile.tile_clicked.connect(_on_tile_clicked)
			grid_container.add_child(new_tile)


# --- Bomb Placement ---
func place_hidden_bombs():
	var bomb_types = [BombType.ROW, BombType.COLUMN, BombType.DIAGONAL]
	var placed_bombs = 0

	while placed_bombs < num_bombs:
		var rand_x = randi() % BOARD_WIDTH
		var rand_y = randi() % BOARD_HEIGHT

		if bomb_data[rand_y][rand_x] == null:
			var rand_type = bomb_types[randi() % bomb_types.size()]

			bomb_data[rand_y][rand_x] = rand_type
			placed_bombs += 1

			print("Hiding a %s bomb at (%s, %s)" % [BombType.keys()[rand_type], rand_x, rand_y])


func check_for_hidden_bomb(pos: Vector2i, player: Player):
	var found_bomb_type = bomb_data[pos.y][pos.x]
	if found_bomb_type != null:
		var bomb_name = BombType.keys()[found_bomb_type]
		print("Player %s found a %s bomb!" % [Player.keys()[player], bomb_name])

		if player == Player.X:
			player_x_bombs.append(found_bomb_type)
			print("Player X inventory: ", player_x_bombs)
		else:
			player_o_bombs.append(found_bomb_type)
			print("Player O inventory: ", player_o_bombs)

		var tile_node = grid_container.get_child(pos.y * BOARD_WIDTH + pos.x)
		tile_node.play_found_effect()
		hud.add_bomb(player, found_bomb_type)

		bomb_data[pos.y][pos.x] = null


# --- The Win-Checking Algorithm ---
func check_for_win(last_move_pos: Vector2i, player: Player) -> bool:
	var directions = [
		Vector2i(1, 0),  # Horizontal
		Vector2i(0, 1),  # Vertical
		Vector2i(1, 1),  # Diagonal Down-Right
		Vector2i(1, -1)  # Diagonal Up-Right
	]

	for dir in directions:
		var count = 1

		for i in range(1, BOARD_WIDTH):
			var check_pos = last_move_pos + dir * i
			if not _is_valid_pos(check_pos):
				break
			var tile_state = board_data[check_pos.y][check_pos.x]
			if tile_state == player:
				count += 1
			elif tile_state == Player.DESTROYED:
				continue
			else:
				break

		for i in range(1, BOARD_WIDTH):
			var check_pos = last_move_pos - dir * i
			if not _is_valid_pos(check_pos):
				break
			var tile_state = board_data[check_pos.y][check_pos.x]
			if tile_state == player:
				count += 1
			elif tile_state == Player.DESTROYED:
				continue
			else:
				break

		if count >= WIN_LENGTH:
			return true

	return false


# --- Draw Detection ---
func _check_for_draw() -> bool:
	for y in range(BOARD_HEIGHT):
		for x in range(BOARD_WIDTH):
			if board_data[y][x] == Player.NONE:
				return false
	return true


# --- Full-Board Win Scan ---
func _check_board_for_any_win() -> Player:
	for y in range(BOARD_HEIGHT):
		for x in range(BOARD_WIDTH):
			var state = board_data[y][x]
			if state == Player.X or state == Player.O:
				if check_for_win(Vector2i(x, y), state):
					return state
	return Player.NONE


# --- Helper for Win Check ---
func _is_valid_and_matching(pos: Vector2i, player: Player) -> bool:
	if pos.y < 0 or pos.y >= BOARD_HEIGHT:
		return false
	if pos.x < 0 or pos.x >= BOARD_WIDTH:
		return false
	return board_data[pos.y][pos.x] == player


# --- Click Handling ---
func _on_tile_clicked(pos: Vector2i):
	if game_over:
		return

	# Block clicks during CPU turn or bomb/gravity animation
	if cpu_thinking or _processing_bomb:
		return

	# In CPU mode, block clicks when it's O's turn
	if vs_cpu and current_player == Player.O:
		return

	if current_game_mode == GameMode.PLACING_MARK and board_data[pos.y][pos.x] != Player.NONE:
		return

	if current_game_mode == GameMode.USING_BOMB:
		if board_data[pos.y][pos.x] == Player.DESTROYED:
			return

		_use_bomb_on_tile(pos)
		hud.hide_armed()

		current_game_mode = GameMode.PLACING_MARK
		armed_bomb_type = null

		# Run post-bomb sequence: gravity → refill → animate → win check
		await _post_bomb_sequence()

		if not game_over:
			_switch_player()

	elif current_game_mode == GameMode.PLACING_MARK:
		_place_mark(pos, current_player)


# --- Core mark placement ---
func _place_mark(pos: Vector2i, player: Player):
	var tile_node = grid_container.get_child(pos.y * BOARD_WIDTH + pos.x)

	if player == Player.X:
		board_data[pos.y][pos.x] = Player.X
		tile_node.set_mark(x_texture)
	else:
		board_data[pos.y][pos.x] = Player.O
		tile_node.set_mark(o_texture)

	if check_for_win(pos, player):
		print("Player %s Wins!" % Player.keys()[player])
		hud.show_winner("Player %s" % Player.keys()[player])
		game_over = true

	check_for_hidden_bomb(pos, player)

	if not game_over:
		if _check_for_draw():
			print("It's a Draw!")
			hud.show_draw()
			game_over = true
		else:
			_switch_player()


# --- Switch turns ---
func _switch_player():
	if current_player == Player.X:
		current_player = Player.O
	else:
		current_player = Player.X
	hud.update_turn(current_player)
	print("It's now %s's turn." % Player.keys()[current_player])

	if vs_cpu and current_player == Player.O and not game_over:
		_start_cpu_turn()


# ============================================================
#  CPU TURN
# ============================================================

func _start_cpu_turn():
	cpu_thinking = true
	hud.show_cpu_thinking(true)

	var delay = randf_range(CPU_DELAY_MIN, CPU_DELAY_MAX)
	await get_tree().create_timer(delay).timeout

	if game_over:
		cpu_thinking = false
		hud.show_cpu_thinking(false)
		return

	var move = cpu_player.decide_move()
	await _execute_cpu_move(move)

	cpu_thinking = false
	hud.show_cpu_thinking(false)


func _execute_cpu_move(move):
	if move.action == cpu_player.Action.PLACE_MARK:
		if board_data[move.position.y][move.position.x] == Player.NONE:
			_place_mark(move.position, Player.O)
		else:
			print("CPU tried to place on occupied tile, falling back to random")
			_place_mark(_find_random_empty(), Player.O)

	elif move.action == cpu_player.Action.USE_BOMB:
		await _execute_cpu_bomb(move.bomb_type, move.position)


func _execute_cpu_bomb(bomb_type: int, target: Vector2i):
	var idx = player_o_bombs.find(bomb_type)
	if idx < 0:
		_place_mark(_find_random_empty(), Player.O)
		return

	player_o_bombs.remove_at(idx)
	hud.remove_bomb(Player.O, bomb_type)

	hud.show_armed(bomb_type)
	await get_tree().create_timer(0.3).timeout

	if game_over:
		return

	armed_bomb_type = bomb_type
	_use_bomb_on_tile(target)
	hud.hide_armed()
	armed_bomb_type = null

	# Run post-bomb sequence: gravity → refill → animate → win check
	await _post_bomb_sequence()

	if not game_over:
		_switch_player()


func _find_random_empty() -> Vector2i:
	var empty: Array = []
	for y in range(BOARD_HEIGHT):
		for x in range(BOARD_WIDTH):
			if board_data[y][x] == Player.NONE:
				empty.append(Vector2i(x, y))
	if empty.is_empty():
		return Vector2i(0, 0)
	return empty[randi() % empty.size()]


# --- HUD Signal Handlers ---

func _on_hud_bomb_selected(bomb_type: int):
	if game_over or current_game_mode == GameMode.USING_BOMB or _processing_bomb:
		return
	if vs_cpu and current_player == Player.O:
		return

	var bombs = player_x_bombs if current_player == Player.X else player_o_bombs
	var idx = bombs.find(bomb_type)
	if idx >= 0:
		bombs.remove_at(idx)
		armed_bomb_type = bomb_type
		current_game_mode = GameMode.USING_BOMB
		print("Armed a %s bomb!" % BombType.keys()[bomb_type])


func _on_hud_bomb_cancelled():
	if armed_bomb_type == null:
		return

	var bombs = player_x_bombs if current_player == Player.X else player_o_bombs
	bombs.append(armed_bomb_type)
	print("Cancelled %s bomb, returned to inventory." % BombType.keys()[armed_bomb_type])

	hud.add_bomb(current_player, armed_bomb_type)

	armed_bomb_type = null
	current_game_mode = GameMode.PLACING_MARK


func _on_restart():
	get_tree().reload_current_scene()


func _on_main_menu():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")


# --- Bomb Use Logic ---
func _use_bomb_on_tile(clicked_pos: Vector2i):
	print("Using %s bomb at %s" % [BombType.keys()[armed_bomb_type], clicked_pos])

	match armed_bomb_type:
		BombType.ROW:
			_explode_row(clicked_pos.y)
		BombType.COLUMN:
			_explode_column(clicked_pos.x)
		BombType.DIAGONAL:
			_explode_diagonal(clicked_pos, Vector2i(1, 1))
			_explode_diagonal(clicked_pos, Vector2i(1, -1))


func _explode_row(row_y: int):
	for x in range(BOARD_WIDTH):
		_destroy_tile(Vector2i(x, row_y))


func _explode_column(col_x: int):
	for y in range(BOARD_HEIGHT):
		_destroy_tile(Vector2i(col_x, y))


func _explode_diagonal(start_pos: Vector2i, direction: Vector2i):
	for i in range(BOARD_WIDTH):
		var pos = start_pos + direction * i
		if not _is_valid_pos(pos):
			break
		_destroy_tile(pos)

	for i in range(1, BOARD_WIDTH):
		var pos = start_pos - direction * i
		if not _is_valid_pos(pos):
			break
		_destroy_tile(pos)


func _destroy_tile(pos: Vector2i):
	if not _is_valid_pos(pos):
		return

	if board_data[pos.y][pos.x] == Player.DESTROYED:
		return

	print("Destroying tile at %s" % pos)
	board_data[pos.y][pos.x] = Player.DESTROYED

	if bomb_data[pos.y][pos.x] != null:
		print("A hidden bomb was destroyed!")
		bomb_data[pos.y][pos.x] = null

	var tile_node = grid_container.get_child(pos.y * BOARD_WIDTH + pos.x)
	tile_node.vanish()


func _is_valid_pos(pos: Vector2i) -> bool:
	if pos.y < 0 or pos.y >= BOARD_HEIGHT:
		return false
	if pos.x < 0 or pos.x >= BOARD_WIDTH:
		return false
	return true


# ============================================================
#  POST-BOMB SEQUENCE: Gravity → Refill → Animate → Win Check
# ============================================================

func _post_bomb_sequence():
	_processing_bomb = true

	# 1. Wait for explosion animations to finish
	await get_tree().create_timer(0.45).timeout

	if game_over:
		_processing_bomb = false
		return

	# 2. Apply gravity: pack surviving tiles down, fill top with new empties
	var fall_info = _apply_gravity_and_refill()

	if fall_info.is_empty():
		# Nothing fell — board had no destroyed tiles (shouldn't happen, but safe)
		_processing_bomb = false
		return

	# 3. Wait one frame for GridContainer to settle layout after visual updates
	await get_tree().process_frame

	# 4. Calculate row height from actual tile dimensions
	var first_tile = grid_container.get_child(0)
	var tile_h = first_tile.size.y
	var v_sep = grid_container.get_theme_constant("v_separation")
	var row_height = tile_h + v_sep

	# 5. Animate each tile dropping from its pre-gravity position to its new position
	var max_duration = 0.0
	for info in fall_info:
		var node: Control = info["node"]
		var rows: int = info["rows"]

		# Remember where the container placed this tile (its correct final position)
		var target_y = node.position.y

		# Offset it upward so it appears at its old row
		node.position.y = target_y - rows * row_height

		# Tween it down to the correct position
		var duration = GRAVITY_ANIM_BASE + rows * GRAVITY_ANIM_PER_ROW
		max_duration = max(max_duration, duration)

		var tween = create_tween()
		tween.tween_property(node, "position:y", target_y, duration) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# 6. Wait for all fall animations to complete
	if max_duration > 0:
		await get_tree().create_timer(max_duration + 0.05).timeout

	# 7. Check if gravity/refill created a winning line
	var winner = _check_board_for_any_win()
	if winner != Player.NONE:
		print("Player %s Wins (gravity created a line)!" % Player.keys()[winner])
		hud.show_winner("Player %s" % Player.keys()[winner])
		game_over = true

	# 8. Check for draw
	if not game_over and _check_for_draw():
		print("It's a Draw!")
		hud.show_draw()
		game_over = true

	_processing_bomb = false


# ============================================================
#  GRAVITY + REFILL LOGIC
# ============================================================

func _apply_gravity_and_refill() -> Array:
	## For each column, pack non-destroyed tiles to the bottom and
	## fill the top with new empty tiles.
	## Returns an array of {"node": tile_node, "rows": fall_distance}
	## describing which tiles need drop animations.

	var fall_info: Array = []
	var bomb_types = [BombType.ROW, BombType.COLUMN, BombType.DIAGONAL]

	for col_x in range(BOARD_WIDTH):
		# Collect surviving (non-destroyed) tiles, preserving top-to-bottom order
		var surviving: Array = []
		for y in range(BOARD_HEIGHT):
			if board_data[y][col_x] != Player.DESTROYED:
				surviving.append({
					"state": board_data[y][col_x],
					"bomb": bomb_data[y][col_x],
					"from_row": y
				})

		var num_new = BOARD_HEIGHT - surviving.size()

		if num_new == 0:
			continue  # No destroyed tiles in this column

		# Rebuild the column: new empty tiles at top, surviving packed to bottom
		for y in range(BOARD_HEIGHT):
			var tile_node = grid_container.get_child(y * BOARD_WIDTH + col_x)

			if y < num_new:
				# --- New tile dropping in from above ---
				board_data[y][col_x] = Player.NONE
				bomb_data[y][col_x] = null

				# Small chance this new tile hides a bomb
				if randf() < NEW_TILE_BOMB_CHANCE:
					var rand_type = bomb_types[randi() % bomb_types.size()]
					bomb_data[y][col_x] = rand_type
					print("New tile at (%s, %s) has a hidden %s bomb!" % [col_x, y, BombType.keys()[rand_type]])

				# Revive the tile node (in case it was vanished) and clear any mark
				tile_node.revive()
				tile_node.clear_mark()

				# New tiles drop from off-screen above the board
				# Top new tile (y=0) falls the furthest, bottom new tile (y=num_new-1) the least
				fall_info.append({"node": tile_node, "rows": num_new - y + 1})

			else:
				# --- Surviving tile, possibly shifted downward ---
				var entry = surviving[y - num_new]
				var fall_rows = y - entry["from_row"]

				# Update data arrays
				board_data[y][col_x] = entry["state"]
				bomb_data[y][col_x] = entry["bomb"]

				# Sync this tile node's visual to match its new data
				_sync_tile_visual(tile_node, entry["state"])

				if fall_rows > 0:
					fall_info.append({"node": tile_node, "rows": fall_rows})

	return fall_info


func _sync_tile_visual(tile_node, state):
	## Set a tile node's appearance to match a board data state.
	## Revives the node first in case it was visually destroyed.
	tile_node.revive()

	match state:
		Player.X:
			tile_node.set_mark(x_texture)
		Player.O:
			tile_node.set_mark(o_texture)
		Player.NONE:
			tile_node.clear_mark()
