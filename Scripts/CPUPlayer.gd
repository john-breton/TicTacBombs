extends Node

## CPU opponent logic for TicTacBombs.
## Call decide_move() to get the CPU's chosen action.

# Reference to GameBoard — set by GameBoard on setup
var board: Node = null

enum Action { PLACE_MARK, USE_BOMB }

# The result of a CPU decision
class CPUMove:
	var action: int  # Action enum
	var position: Vector2i
	var bomb_type: int  # Only relevant if action == USE_BOMB
	
	func _init(a: int, pos: Vector2i, bt: int = -1):
		action = a
		position = pos
		bomb_type = bt


func setup(game_board: Node):
	board = game_board


## Main entry point — returns a CPUMove.
func decide_move() -> CPUMove:
	var difficulty = GameSettings.cpu_difficulty
	
	match difficulty:
		0: return _decide_easy()
		1: return _decide_medium()
		2: return _decide_hard()
		_: return _decide_medium()


# ============================================================
#  EASY — Pure random
# ============================================================

func _decide_easy() -> CPUMove:
	# Small chance to use a bomb if available
	if board.player_o_bombs.size() > 0 and randf() < 0.2:
		var bomb_move = _random_bomb_move()
		if bomb_move:
			return bomb_move
	
	return _random_placement()


# ============================================================
#  MEDIUM — Wins, blocks, then random
# ============================================================

func _decide_medium() -> CPUMove:
	var cpu = board.Player.O
	var human = board.Player.X
	
	# 1. Can I win right now?
	var win_pos = _find_winning_move(cpu)
	if win_pos != Vector2i(-1, -1):
		return CPUMove.new(Action.PLACE_MARK, win_pos)
	
	# 2. Can opponent win? Block it.
	var block_pos = _find_winning_move(human)
	if block_pos != Vector2i(-1, -1):
		return CPUMove.new(Action.PLACE_MARK, block_pos)
	
	# 3. Consider using a bomb to disrupt opponent lines
	if board.player_o_bombs.size() > 0 and randf() < 0.35:
		var bomb_move = _smart_bomb_move()
		if bomb_move:
			return bomb_move
	
	# 4. Random placement
	return _random_placement()


# ============================================================
#  HARD — Positional scoring + smart bombs
# ============================================================

func _decide_hard() -> CPUMove:
	var cpu = board.Player.O
	var human = board.Player.X
	
	# 1. Immediate win
	var win_pos = _find_winning_move(cpu)
	if win_pos != Vector2i(-1, -1):
		return CPUMove.new(Action.PLACE_MARK, win_pos)
	
	# 2. Block opponent win
	var block_pos = _find_winning_move(human)
	if block_pos != Vector2i(-1, -1):
		return CPUMove.new(Action.PLACE_MARK, block_pos)
	
	# 3. Consider bomb if opponent has strong lines
	if board.player_o_bombs.size() > 0:
		var threat = _evaluate_opponent_threat(human)
		if threat >= board.WIN_LENGTH - 1:
			var bomb_move = _smart_bomb_move()
			if bomb_move:
				return bomb_move
	
	# 4. Score all positions and pick the best
	var best_pos = _score_positions(cpu, human)
	if best_pos != Vector2i(-1, -1):
		return CPUMove.new(Action.PLACE_MARK, best_pos)
	
	return _random_placement()


# ============================================================
#  PLACEMENT HELPERS
# ============================================================

func _random_placement() -> CPUMove:
	var empty_tiles: Array = []
	for y in range(board.BOARD_HEIGHT):
		for x in range(board.BOARD_WIDTH):
			if board.board_data[y][x] == board.Player.NONE:
				empty_tiles.append(Vector2i(x, y))
	
	if empty_tiles.is_empty():
		return CPUMove.new(Action.PLACE_MARK, Vector2i(0, 0))
	
	return CPUMove.new(Action.PLACE_MARK, empty_tiles[randi() % empty_tiles.size()])


func _find_winning_move(player) -> Vector2i:
	## Check every empty tile to see if placing there would win.
	for y in range(board.BOARD_HEIGHT):
		for x in range(board.BOARD_WIDTH):
			if board.board_data[y][x] == board.Player.NONE:
				# Simulate placement
				board.board_data[y][x] = player
				var wins = board.check_for_win(Vector2i(x, y), player)
				board.board_data[y][x] = board.Player.NONE  # Undo
				if wins:
					return Vector2i(x, y)
	return Vector2i(-1, -1)


func _score_positions(cpu, human) -> Vector2i:
	var best_score = -999.0
	var best_pos = Vector2i(-1, -1)
	var center = Vector2(board.BOARD_WIDTH / 2.0, board.BOARD_HEIGHT / 2.0)
	
	for y in range(board.BOARD_HEIGHT):
		for x in range(board.BOARD_WIDTH):
			if board.board_data[y][x] != board.Player.NONE:
				continue
			
			var score = 0.0
			var pos = Vector2i(x, y)
			
			# Centrality bonus (closer to center = better)
			var dist = Vector2(x, y).distance_to(center)
			var max_dist = center.length()
			score += (1.0 - dist / max_dist) * 3.0
			
			# Count friendly and enemy neighbors in all directions
			var directions = [
				Vector2i(1, 0), Vector2i(0, 1),
				Vector2i(1, 1), Vector2i(1, -1)
			]
			
			for dir in directions:
				var my_count = _count_in_direction(pos, dir, cpu)
				var opp_count = _count_in_direction(pos, dir, human)
				
				# Offensive: extend own lines
				score += my_count * 2.5
				# Defensive: block opponent lines
				score += opp_count * 2.0
			
			# Small randomness to avoid predictability
			score += randf() * 0.5
			
			if score > best_score:
				best_score = score
				best_pos = pos
	
	return best_pos


func _count_in_direction(pos: Vector2i, dir: Vector2i, player) -> int:
	## Count consecutive marks of `player` in both directions from pos, skipping destroyed.
	var count = 0
	
	for sign in [1, -1]:
		for i in range(1, board.WIN_LENGTH):
			var check = pos + dir * i * sign
			if not board._is_valid_pos(check):
				break
			var state = board.board_data[check.y][check.x]
			if state == player:
				count += 1
			elif state == board.Player.DESTROYED:
				continue
			else:
				break
	
	return count


# ============================================================
#  BOMB HELPERS
# ============================================================

func _random_bomb_move() -> CPUMove:
	var bomb_type = board.player_o_bombs[0]
	var non_destroyed = _get_non_destroyed_positions()
	if non_destroyed.is_empty():
		return null
	var target = non_destroyed[randi() % non_destroyed.size()]
	return CPUMove.new(Action.USE_BOMB, target, bomb_type)


func _smart_bomb_move() -> CPUMove:
	## Pick the bomb that destroys the most opponent marks.
	var human = board.Player.X
	var best_bomb_move: CPUMove = null
	var best_destruction = 0
	
	for bomb_type in board.player_o_bombs:
		var result = _evaluate_bomb(bomb_type, human)
		if result["score"] > best_destruction:
			best_destruction = result["score"]
			best_bomb_move = CPUMove.new(Action.USE_BOMB, result["pos"], bomb_type)
	
	# Only use bomb if it actually destroys some opponent marks
	if best_destruction >= 2:
		return best_bomb_move
	return null


func _evaluate_bomb(bomb_type: int, target_player) -> Dictionary:
	## Find the best position to use this bomb type, maximizing opponent mark destruction.
	var best_pos = Vector2i(0, 0)
	var best_score = 0
	
	for y in range(board.BOARD_HEIGHT):
		for x in range(board.BOARD_WIDTH):
			if board.board_data[y][x] == board.Player.DESTROYED:
				continue
			
			var pos = Vector2i(x, y)
			var score = 0
			
			match bomb_type:
				board.BombType.ROW:
					score = _count_player_in_row(y, target_player)
				board.BombType.COLUMN:
					score = _count_player_in_column(x, target_player)
				board.BombType.DIAGONAL:
					score = _count_player_on_diagonals(pos, target_player)
			
			# Penalize destroying own marks
			var own_loss = 0
			match bomb_type:
				board.BombType.ROW:
					own_loss = _count_player_in_row(y, board.Player.O)
				board.BombType.COLUMN:
					own_loss = _count_player_in_column(x, board.Player.O)
				board.BombType.DIAGONAL:
					own_loss = _count_player_on_diagonals(pos, board.Player.O)
			
			score -= own_loss
			
			if score > best_score:
				best_score = score
				best_pos = pos
	
	return {"pos": best_pos, "score": best_score}


func _count_player_in_row(row_y: int, player) -> int:
	var count = 0
	for x in range(board.BOARD_WIDTH):
		if board.board_data[row_y][x] == player:
			count += 1
	return count


func _count_player_in_column(col_x: int, player) -> int:
	var count = 0
	for y in range(board.BOARD_HEIGHT):
		if board.board_data[y][col_x] == player:
			count += 1
	return count


func _count_player_on_diagonals(pos: Vector2i, player) -> int:
	var count = 0
	for dir in [Vector2i(1, 1), Vector2i(1, -1)]:
		# Forward
		for i in range(-board.BOARD_WIDTH, board.BOARD_WIDTH):
			var check = pos + dir * i
			if board._is_valid_pos(check) and board.board_data[check.y][check.x] == player:
				count += 1
	return count


func _evaluate_opponent_threat(human) -> int:
	## Return the longest line the opponent currently has.
	var max_line = 0
	var directions = [
		Vector2i(1, 0), Vector2i(0, 1),
		Vector2i(1, 1), Vector2i(1, -1)
	]
	
	for y in range(board.BOARD_HEIGHT):
		for x in range(board.BOARD_WIDTH):
			if board.board_data[y][x] == human:
				for dir in directions:
					var count = 1
					for i in range(1, board.BOARD_WIDTH):
						var check = Vector2i(x, y) + dir * i
						if not board._is_valid_pos(check):
							break
						var state = board.board_data[check.y][check.x]
						if state == human:
							count += 1
						elif state == board.Player.DESTROYED:
							continue
						else:
							break
					max_line = max(max_line, count)
	
	return max_line


func _get_non_destroyed_positions() -> Array:
	var positions: Array = []
	for y in range(board.BOARD_HEIGHT):
		for x in range(board.BOARD_WIDTH):
			if board.board_data[y][x] != board.Player.DESTROYED:
				positions.append(Vector2i(x, y))
	return positions
