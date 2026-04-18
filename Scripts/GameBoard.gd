extends Node2D

# --- Preload & References ---
@onready var tile_scene = preload("res://Scenes/Tile.tscn")
@onready var grid_container = $GridContainer
@onready var hud = $HUD

@export var x_texture : Texture2D
@export var o_texture : Texture2D
@export var num_bombs = 5

# --- Game State ---
enum Player { NONE, X, O, DESTROYED, DISABLED }
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

# --- Puzzle Mode ---
var puzzle_mode = false
var current_puzzle: Dictionary = {}
var moves_used: int = 0
var max_moves: int = 0

# --- Gravity ---
var _processing_bomb = false
const NEW_TILE_BOMB_CHANCE = 0.08
const GRAVITY_ANIM_BASE = 0.2
const GRAVITY_ANIM_PER_ROW = 0.04

# --- Bomb Preview ---
var _hovered_pos: Vector2i = Vector2i(-1, -1)
var _previewed_tiles: Array = []


# --- Main Setup Function ---
func _ready():
	RenderingServer.set_default_clear_color(Color(0.1, 0.1, 0.13))

	puzzle_mode = (GameSettings.play_mode == GameSettings.PlayMode.PUZZLE)

	if puzzle_mode:
		_setup_puzzle_dimensions()
	else:
		BOARD_WIDTH = GameSettings.board_size
		BOARD_HEIGHT = GameSettings.board_size
		WIN_LENGTH = GameSettings.win_length
		num_bombs = GameSettings.num_bombs

	grid_container.columns = BOARD_WIDTH

	vs_cpu = (GameSettings.play_mode == GameSettings.PlayMode.VS_CPU)
	if vs_cpu:
		var cpu_script = load("res://Scripts/CPUPlayer.gd")
		cpu_player = Node.new()
		cpu_player.set_script(cpu_script)
		add_child(cpu_player)
		cpu_player.setup(self)

	create_board_data()
	if puzzle_mode:
		_apply_puzzle_board()
	else:
		place_hidden_bombs()
	create_board()
	if puzzle_mode:
		_apply_puzzle_visuals()
	_center_board()

	get_tree().root.size_changed.connect(_center_board)

	hud.setup(x_texture, o_texture)
	hud.bomb_selected.connect(_on_hud_bomb_selected)
	hud.bomb_cancelled.connect(_on_hud_bomb_cancelled)
	hud.restart_requested.connect(_on_restart)
	hud.menu_requested.connect(_on_main_menu)
	hud.next_puzzle_requested.connect(_on_next_puzzle)

	if puzzle_mode:
		hud.setup_puzzle_mode(current_puzzle["name"], max_moves)
		_populate_puzzle_bombs()
		hud.update_puzzle_moves(moves_used)
	else:
		hud.update_turn(current_player)

	if vs_cpu:
		hud.set_cpu_mode(true)


# ============================================================
#  PUZZLE MODE SETUP
# ============================================================

func _setup_puzzle_dimensions():
	var catalog = load("res://Scripts/PuzzleCatalog.gd")
	current_puzzle = catalog.get_puzzle(GameSettings.current_puzzle_id)
	BOARD_WIDTH = current_puzzle.get("width", 3)
	BOARD_HEIGHT = current_puzzle.get("height", 3)
	WIN_LENGTH = current_puzzle.get("win_length", 3)
	max_moves = current_puzzle.get("max_moves", 1)
	moves_used = 0


func _apply_puzzle_board():
	var board: Array = current_puzzle.get("board", [])
	for y in range(BOARD_HEIGHT):
		for x in range(BOARD_WIDTH):
			var cell = _puzzle_cell_at(board, x, y)
			match cell:
				-1:  # TILE_DISABLED
					board_data[y][x] = Player.DISABLED
				1:   # TILE_X
					board_data[y][x] = Player.X
				2:   # TILE_O
					board_data[y][x] = Player.O
				_:   # TILE_EMPTY
					board_data[y][x] = Player.NONE


func _apply_puzzle_visuals():
	for y in range(BOARD_HEIGHT):
		for x in range(BOARD_WIDTH):
			var tile_node = grid_container.get_child(y * BOARD_WIDTH + x)
			match board_data[y][x]:
				Player.DISABLED:
					tile_node.set_disabled()
				Player.X:
					tile_node.set_mark(x_texture)
				Player.O:
					tile_node.set_mark(o_texture)


func _populate_puzzle_bombs():
	player_x_bombs.clear()
	for bomb_type in current_puzzle.get("bombs", []):
		player_x_bombs.append(bomb_type)
		hud.add_bomb(Player.X, bomb_type)


func _puzzle_cell_at(board: Array, x: int, y: int) -> int:
	if y < 0 or y >= board.size():
		return 0
	var row = board[y]
	if x < 0 or x >= row.size():
		return 0
	return row[x]


# --- Center and scale the board to fit the viewport ---
var _initial_center_done = false

func _center_board():
	if not _initial_center_done:
		_initial_center_done = true
		await get_tree().process_frame

	var viewport_size = get_viewport_rect().size
	var base_board_size = grid_container.size

	var hud_padding = Vector2(60, 260)
	var available = viewport_size - hud_padding

	var scale_factor = min(available.x / base_board_size.x, available.y / base_board_size.y)
	grid_container.scale = Vector2(scale_factor, scale_factor)

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
			new_tile.tile_hovered.connect(_on_tile_hovered)
			new_tile.tile_unhovered.connect(_on_tile_unhovered)
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
		else:
			player_o_bombs.append(found_bomb_type)

		var tile_node = grid_container.get_child(pos.y * BOARD_WIDTH + pos.x)
		tile_node.play_found_effect()
		hud.add_bomb(player, found_bomb_type)
		bomb_data[pos.y][pos.x] = null

		SoundManager.play_bomb_found()


# ============================================================
#  WIN CHECKING
# ============================================================

func check_for_win(last_move_pos: Vector2i, player: Player) -> bool:
	var directions = [
		Vector2i(1, 0), Vector2i(0, 1),
		Vector2i(1, 1), Vector2i(1, -1)
	]
	var max_len = max(BOARD_WIDTH, BOARD_HEIGHT)

	for dir in directions:
		var count = 1

		for i in range(1, max_len):
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

		for i in range(1, max_len):
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


## Return the positions forming a winning line through `start_pos` for `player`.
func get_winning_positions(start_pos: Vector2i, player: Player) -> Array:
	var directions = [
		Vector2i(1, 0), Vector2i(0, 1),
		Vector2i(1, 1), Vector2i(1, -1)
	]
	var max_len = max(BOARD_WIDTH, BOARD_HEIGHT)

	for dir in directions:
		var positions: Array = [start_pos]

		for i in range(1, max_len):
			var check_pos = start_pos + dir * i
			if not _is_valid_pos(check_pos):
				break
			var tile_state = board_data[check_pos.y][check_pos.x]
			if tile_state == player:
				positions.append(check_pos)
			elif tile_state == Player.DESTROYED:
				continue
			else:
				break

		for i in range(1, max_len):
			var check_pos = start_pos - dir * i
			if not _is_valid_pos(check_pos):
				break
			var tile_state = board_data[check_pos.y][check_pos.x]
			if tile_state == player:
				positions.append(check_pos)
			elif tile_state == Player.DESTROYED:
				continue
			else:
				break

		if positions.size() >= WIN_LENGTH:
			return positions

	return []


## Highlight winning tiles visually.
func _highlight_win_line(player: Player):
	# Find all winning positions for this player
	for y in range(BOARD_HEIGHT):
		for x in range(BOARD_WIDTH):
			if board_data[y][x] == player:
				var positions = get_winning_positions(Vector2i(x, y), player)
				if positions.size() >= WIN_LENGTH:
					for pos in positions:
						var tile = grid_container.get_child(pos.y * BOARD_WIDTH + pos.x)
						tile.show_win_highlight()
					return  # Highlight first winning line found


## Highlight winning tiles for both players (draw case after bomb).
func _highlight_all_win_lines():
	for player in [Player.X, Player.O]:
		for y in range(BOARD_HEIGHT):
			for x in range(BOARD_WIDTH):
				if board_data[y][x] == player:
					var positions = get_winning_positions(Vector2i(x, y), player)
					if positions.size() >= WIN_LENGTH:
						for pos in positions:
							var tile = grid_container.get_child(pos.y * BOARD_WIDTH + pos.x)
							tile.show_win_highlight()


# --- Draw Detection ---
func _check_for_draw() -> bool:
	for y in range(BOARD_HEIGHT):
		for x in range(BOARD_WIDTH):
			if board_data[y][x] == Player.NONE:
				return false
	return true


# --- Full-Board Win Scan (draw-aware) ---
func _check_board_for_any_win() -> Player:
	var x_wins = false
	var o_wins = false

	for y in range(BOARD_HEIGHT):
		for x in range(BOARD_WIDTH):
			var state = board_data[y][x]
			if state == Player.X and not x_wins:
				if check_for_win(Vector2i(x, y), Player.X):
					x_wins = true
			elif state == Player.O and not o_wins:
				if check_for_win(Vector2i(x, y), Player.O):
					o_wins = true

	if x_wins and o_wins:
		return Player.NONE
	elif x_wins:
		return Player.X
	elif o_wins:
		return Player.O
	return Player.NONE


func _handle_post_bomb_winner():
	var x_wins = false
	var o_wins = false

	for y in range(BOARD_HEIGHT):
		for x in range(BOARD_WIDTH):
			var state = board_data[y][x]
			if state == Player.X and not x_wins:
				if check_for_win(Vector2i(x, y), Player.X):
					x_wins = true
			elif state == Player.O and not o_wins:
				if check_for_win(Vector2i(x, y), Player.O):
					o_wins = true

	if x_wins and o_wins:
		print("Both players win — it's a draw!")
		_highlight_all_win_lines()
		hud.show_draw()
		game_over = true
		SoundManager.play_draw()
	elif x_wins:
		_highlight_win_line(Player.X)
		hud.show_winner("Player X")
		game_over = true
		SoundManager.play_win()
	elif o_wins:
		_highlight_win_line(Player.O)
		hud.show_winner("Player O")
		game_over = true
		SoundManager.play_win()


func _is_valid_and_matching(pos: Vector2i, player: Player) -> bool:
	if pos.y < 0 or pos.y >= BOARD_HEIGHT:
		return false
	if pos.x < 0 or pos.x >= BOARD_WIDTH:
		return false
	return board_data[pos.y][pos.x] == player


# ============================================================
#  BOMB PREVIEW
# ============================================================

func _on_tile_hovered(pos: Vector2i):
	_hovered_pos = pos
	if current_game_mode == GameMode.USING_BOMB and armed_bomb_type != null:
		if board_data[pos.y][pos.x] != Player.DESTROYED:
			_show_bomb_preview(pos)


func _on_tile_unhovered(pos: Vector2i):
	if _hovered_pos == pos:
		_hovered_pos = Vector2i(-1, -1)
	_clear_bomb_preview()


func _show_bomb_preview(target_pos: Vector2i):
	_clear_bomb_preview()

	var positions = _get_bomb_affected_positions(armed_bomb_type, target_pos)
	for pos in positions:
		var tile = grid_container.get_child(pos.y * BOARD_WIDTH + pos.x)
		tile.show_bomb_preview()
		_previewed_tiles.append(tile)


func _clear_bomb_preview():
	for tile in _previewed_tiles:
		if is_instance_valid(tile):
			tile.hide_bomb_preview()
	_previewed_tiles.clear()


## Get all non-destroyed positions a bomb would affect.
func _get_bomb_affected_positions(bomb_type, target_pos: Vector2i) -> Array:
	var positions: Array = []

	match bomb_type:
		BombType.ROW:
			for bx in range(BOARD_WIDTH):
				var state = board_data[target_pos.y][bx]
				if state != Player.DESTROYED and state != Player.DISABLED:
					positions.append(Vector2i(bx, target_pos.y))
		BombType.COLUMN:
			for by in range(BOARD_HEIGHT):
				var state = board_data[by][target_pos.x]
				if state != Player.DESTROYED and state != Player.DISABLED:
					positions.append(Vector2i(target_pos.x, by))
		BombType.DIAGONAL:
			for dir in [Vector2i(1, 1), Vector2i(1, -1)]:
				for i in range(-BOARD_WIDTH, BOARD_WIDTH):
					var p = target_pos + dir * i
					if _is_valid_pos(p):
						var state = board_data[p.y][p.x]
						if state != Player.DESTROYED and state != Player.DISABLED:
							if not p in positions:
								positions.append(p)

	return positions


# ============================================================
#  CLICK HANDLING
# ============================================================

func _on_tile_clicked(pos: Vector2i):
	if game_over:
		return

	if cpu_thinking or _processing_bomb:
		return

	if vs_cpu and current_player == Player.O:
		return

	if current_game_mode == GameMode.PLACING_MARK and board_data[pos.y][pos.x] != Player.NONE:
		return

	if current_game_mode == GameMode.USING_BOMB:
		if board_data[pos.y][pos.x] == Player.DESTROYED:
			return
		if board_data[pos.y][pos.x] == Player.DISABLED:
			return

		_clear_bomb_preview()
		_use_bomb_on_tile(pos)
		hud.hide_armed()

		current_game_mode = GameMode.PLACING_MARK
		armed_bomb_type = null

		if puzzle_mode:
			moves_used += 1
			hud.update_puzzle_moves(moves_used)

		await _post_bomb_sequence()

		if puzzle_mode:
			_check_puzzle_state()
		elif not game_over:
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

	SoundManager.play_place_mark()

	if puzzle_mode:
		moves_used += 1
		hud.update_puzzle_moves(moves_used)

	if check_for_win(pos, player):
		print("Player %s Wins!" % Player.keys()[player])
		if puzzle_mode:
			_on_puzzle_solved()
		else:
			_highlight_win_line(player)
			hud.show_winner("Player %s" % Player.keys()[player])
			game_over = true
			SoundManager.play_win()

	check_for_hidden_bomb(pos, player)

	if game_over:
		return

	if puzzle_mode:
		_check_puzzle_state()
	elif _check_for_draw():
		print("It's a Draw!")
		hud.show_draw()
		game_over = true
		SoundManager.play_draw()
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
		SoundManager.play_bomb_arm()
		print("Armed a %s bomb!" % BombType.keys()[bomb_type])

		# Show preview if already hovering a tile
		if _hovered_pos != Vector2i(-1, -1) and _is_valid_pos(_hovered_pos):
			if board_data[_hovered_pos.y][_hovered_pos.x] != Player.DESTROYED:
				_show_bomb_preview(_hovered_pos)


func _on_hud_bomb_cancelled():
	if armed_bomb_type == null:
		return

	_clear_bomb_preview()

	var bombs = player_x_bombs if current_player == Player.X else player_o_bombs
	bombs.append(armed_bomb_type)
	print("Cancelled %s bomb, returned to inventory." % BombType.keys()[armed_bomb_type])

	hud.add_bomb(current_player, armed_bomb_type)

	armed_bomb_type = null
	current_game_mode = GameMode.PLACING_MARK
	SoundManager.play_bomb_cancel()


func _on_restart():
	get_tree().reload_current_scene()


func _on_main_menu():
	if puzzle_mode:
		get_tree().change_scene_to_file("res://Scenes/PuzzleSelect.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")


func _on_next_puzzle():
	var catalog = load("res://Scripts/PuzzleCatalog.gd")
	var next_puzzle = catalog.get_next_puzzle(current_puzzle.get("id", 0))
	if not next_puzzle.is_empty():
		GameSettings.current_puzzle_id = next_puzzle["id"]
		get_tree().reload_current_scene()


# ============================================================
#  PUZZLE STATE RESOLUTION
# ============================================================

func _check_puzzle_state():
	if game_over:
		return

	if _puzzle_x_has_won():
		_on_puzzle_solved()
	elif moves_used >= max_moves:
		_on_puzzle_failed()


func _puzzle_x_has_won() -> bool:
	for y in range(BOARD_HEIGHT):
		for x in range(BOARD_WIDTH):
			if board_data[y][x] == Player.X:
				if check_for_win(Vector2i(x, y), Player.X):
					return true
	return false


func _on_puzzle_solved():
	if game_over:
		return
	game_over = true
	_highlight_win_line(Player.X)
	SoundManager.play_win()
	var catalog = load("res://Scripts/PuzzleCatalog.gd")
	var has_next = not catalog.get_next_puzzle(current_puzzle.get("id", 0)).is_empty()
	hud.show_puzzle_solved(has_next)


func _on_puzzle_failed():
	if game_over:
		return
	game_over = true
	SoundManager.play_draw()
	hud.show_puzzle_failed()


# ============================================================
#  BOMB DETONATION
# ============================================================

func _use_bomb_on_tile(clicked_pos: Vector2i):
	print("Using %s bomb at %s" % [BombType.keys()[armed_bomb_type], clicked_pos])
	SoundManager.play_explosion()

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
	if board_data[pos.y][pos.x] == Player.DISABLED:
		return

	board_data[pos.y][pos.x] = Player.DESTROYED

	if bomb_data[pos.y][pos.x] != null:
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

	await get_tree().create_timer(0.45).timeout

	if game_over:
		_processing_bomb = false
		return

	# Puzzle mode: no gravity, no refill — destroyed tiles stay destroyed.
	# The caller runs _check_puzzle_state() once this returns.
	if puzzle_mode:
		_processing_bomb = false
		return

	var fall_info = _apply_gravity_and_refill()

	if fall_info.is_empty():
		_processing_bomb = false
		return

	await get_tree().process_frame

	var first_tile = grid_container.get_child(0)
	var tile_h = first_tile.size.y
	var v_sep = grid_container.get_theme_constant("v_separation")
	var row_height = tile_h + v_sep

	var max_duration = 0.0
	for info in fall_info:
		var node: Control = info["node"]
		var rows: int = info["rows"]

		var target_y = node.position.y
		node.position.y = target_y - rows * row_height

		var duration = GRAVITY_ANIM_BASE + rows * GRAVITY_ANIM_PER_ROW
		max_duration = max(max_duration, duration)

		var tween = create_tween()
		tween.tween_property(node, "position:y", target_y, duration) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	if max_duration > 0:
		await get_tree().create_timer(max_duration + 0.05).timeout
		SoundManager.play_gravity_land()

	# Check if gravity/refill created a win or mutual draw
	_handle_post_bomb_winner()

	if not game_over and _check_for_draw():
		print("It's a Draw!")
		hud.show_draw()
		game_over = true
		SoundManager.play_draw()

	_processing_bomb = false


# ============================================================
#  GRAVITY + REFILL LOGIC
# ============================================================

func _apply_gravity_and_refill() -> Array:
	var fall_info: Array = []
	var bomb_types = [BombType.ROW, BombType.COLUMN, BombType.DIAGONAL]

	for col_x in range(BOARD_WIDTH):
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
			continue

		for y in range(BOARD_HEIGHT):
			var tile_node = grid_container.get_child(y * BOARD_WIDTH + col_x)

			if y < num_new:
				board_data[y][col_x] = Player.NONE
				bomb_data[y][col_x] = null

				if randf() < NEW_TILE_BOMB_CHANCE:
					var rand_type = bomb_types[randi() % bomb_types.size()]
					bomb_data[y][col_x] = rand_type

				tile_node.revive()
				tile_node.clear_mark()

				fall_info.append({"node": tile_node, "rows": num_new - y + 1})

			else:
				var entry = surviving[y - num_new]
				var fall_rows = y - entry["from_row"]

				board_data[y][col_x] = entry["state"]
				bomb_data[y][col_x] = entry["bomb"]

				_sync_tile_visual(tile_node, entry["state"])

				if fall_rows > 0:
					fall_info.append({"node": tile_node, "rows": fall_rows})

	return fall_info


func _sync_tile_visual(tile_node, state):
	tile_node.revive()

	match state:
		Player.X:
			tile_node.set_mark(x_texture)
		Player.O:
			tile_node.set_mark(o_texture)
		Player.NONE:
			tile_node.clear_mark()
