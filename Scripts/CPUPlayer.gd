extends Node

## CPU opponent logic for TicTacBombs.
## Call decide_move() to get the CPU's chosen action.

var board: Node = null

enum Action { PLACE_MARK, USE_BOMB }

class CPUMove:
	var action: int
	var position: Vector2i
	var bomb_type: int

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
#  EASY — Random with occasional lucky plays
# ============================================================

func _decide_easy() -> CPUMove:
	# 15% chance to play smart (win if possible)
	if randf() < 0.15:
		var win_pos = _find_winning_move(board.Player.O)
		if win_pos != Vector2i(-1, -1):
			return CPUMove.new(Action.PLACE_MARK, win_pos)

	# 20% chance to use a random bomb
	if board.player_o_bombs.size() > 0 and randf() < 0.2:
		var bomb_move = _random_bomb_move()
		if bomb_move:
			return bomb_move

	return _random_placement()


# ============================================================
#  MEDIUM — Wins, blocks, basic positioning
# ============================================================

func _decide_medium() -> CPUMove:
	var cpu = board.Player.O
	var human = board.Player.X

	# 1. Win if possible
	var win_pos = _find_winning_move(cpu)
	if win_pos != Vector2i(-1, -1):
		return CPUMove.new(Action.PLACE_MARK, win_pos)

	# 2. Block opponent win
	var block_pos = _find_winning_move(human)
	if block_pos != Vector2i(-1, -1):
		return CPUMove.new(Action.PLACE_MARK, block_pos)

	# 3. Try to create a fork (40% chance of seeing it)
	if randf() < 0.4:
		var fork_pos = _find_fork_move(cpu)
		if fork_pos != Vector2i(-1, -1):
			return CPUMove.new(Action.PLACE_MARK, fork_pos)

	# 4. Strategic bomb use
	if board.player_o_bombs.size() > 0 and randf() < 0.4:
		var bomb_move = _smart_bomb_move()
		if bomb_move:
			return bomb_move

	# 5. Basic positional scoring (not pure random)
	var scored_pos = _score_positions(cpu, human, false)
	if scored_pos != Vector2i(-1, -1):
		return CPUMove.new(Action.PLACE_MARK, scored_pos)

	return _random_placement()


# ============================================================
#  HARD — Full evaluation with forks and strategic bombs
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

	# 3. Create a fork (two+ ways to win next turn)
	var fork_pos = _find_fork_move(cpu)
	if fork_pos != Vector2i(-1, -1):
		return CPUMove.new(Action.PLACE_MARK, fork_pos)

	# 4. Block opponent fork
	var opp_fork = _find_fork_move(human)
	if opp_fork != Vector2i(-1, -1):
		return CPUMove.new(Action.PLACE_MARK, opp_fork)

	# 5. Consider bomb to create a win or disrupt threats
	if board.player_o_bombs.size() > 0:
		var bomb_move = _offensive_bomb_move(cpu, human)
		if bomb_move:
			return bomb_move

	# 6. Full positional scoring
	var scored_pos = _score_positions(cpu, human, true)
	if scored_pos != Vector2i(-1, -1):
		return CPUMove.new(Action.PLACE_MARK, scored_pos)

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
	for y in range(board.BOARD_HEIGHT):
		for x in range(board.BOARD_WIDTH):
			if board.board_data[y][x] == board.Player.NONE:
				board.board_data[y][x] = player
				var wins = board.check_for_win(Vector2i(x, y), player)
				board.board_data[y][x] = board.Player.NONE
				if wins:
					return Vector2i(x, y)
	return Vector2i(-1, -1)


## Find a "fork" — a move that creates 2+ winning threats at once.
func _find_fork_move(player) -> Vector2i:
	var best_pos = Vector2i(-1, -1)
	var best_threats = 0

	for y in range(board.BOARD_HEIGHT):
		for x in range(board.BOARD_WIDTH):
			if board.board_data[y][x] != board.Player.NONE:
				continue

			# Simulate placing here
			board.board_data[y][x] = player
			var threats = _count_near_wins(Vector2i(x, y), player)
			board.board_data[y][x] = board.Player.NONE

			if threats >= 2 and threats > best_threats:
				best_threats = threats
				best_pos = Vector2i(x, y)

	return best_pos


## Count how many directions from `pos` are one move away from a win for `player`.
func _count_near_wins(pos: Vector2i, player) -> int:
	var threats = 0
	var directions = [
		Vector2i(1, 0), Vector2i(0, 1),
		Vector2i(1, 1), Vector2i(1, -1)
	]

	for dir in directions:
		# After placing at pos, check if this direction has WIN_LENGTH-1 marks
		# with at least one open end to complete to WIN_LENGTH
		var count = 1
		var open_ends = 0

		# Scan forward
		var blocked_fwd = false
		for i in range(1, board.BOARD_WIDTH):
			var check = pos + dir * i
			if not board._is_valid_pos(check):
				blocked_fwd = true
				break
			var state = board.board_data[check.y][check.x]
			if state == player:
				count += 1
			elif state == board.Player.DESTROYED:
				continue
			elif state == board.Player.NONE:
				open_ends += 1
				break
			else:
				blocked_fwd = true
				break

		# Scan backward
		for i in range(1, board.BOARD_WIDTH):
			var check = pos - dir * i
			if not board._is_valid_pos(check):
				break
			var state = board.board_data[check.y][check.x]
			if state == player:
				count += 1
			elif state == board.Player.DESTROYED:
				continue
			elif state == board.Player.NONE:
				open_ends += 1
				break
			else:
				break

		# A "near win" = one more mark would complete WIN_LENGTH, and there's room
		if count >= board.WIN_LENGTH - 1 and open_ends >= 1:
			threats += 1

	return threats


func _score_positions(cpu, human, advanced: bool) -> Vector2i:
	var best_score = -999.0
	var best_pos = Vector2i(-1, -1)
	var center = Vector2(board.BOARD_WIDTH / 2.0, board.BOARD_HEIGHT / 2.0)
	var directions = [
		Vector2i(1, 0), Vector2i(0, 1),
		Vector2i(1, 1), Vector2i(1, -1)
	]

	for y in range(board.BOARD_HEIGHT):
		for x in range(board.BOARD_WIDTH):
			if board.board_data[y][x] != board.Player.NONE:
				continue

			var score = 0.0
			var pos = Vector2i(x, y)

			# Centrality bonus
			var dist = Vector2(x, y).distance_to(center)
			var max_dist = center.length()
			score += (1.0 - dist / max_dist) * 2.0

			for dir in directions:
				var line = _analyze_line(pos, dir, cpu, human)

				# Offensive scoring (exponential for longer lines)
				if line["my_count"] > 0 and line["blocked_by_opponent"] < 2:
					score += pow(line["my_count"], 2.2) * 2.0
					# Bonus for open ends
					score += line["my_open_ends"] * 1.5

				# Defensive scoring
				if line["opp_count"] > 0 and line["blocked_by_me"] < 2:
					score += pow(line["opp_count"], 2.0) * 1.5
					score += line["opp_open_ends"] * 1.0

				if advanced:
					# Near-win bonus: if placing here gets us to WIN_LENGTH-1 with open ends
					if line["my_count"] >= board.WIN_LENGTH - 2 and line["my_open_ends"] >= 1:
						score += 5.0
					# Blocking a near-win
					if line["opp_count"] >= board.WIN_LENGTH - 2 and line["opp_open_ends"] >= 1:
						score += 4.0

			# Small randomness to avoid predictability
			score += randf() * 0.3

			if score > best_score:
				best_score = score
				best_pos = pos

	return best_pos


## Analyze a line through `pos` in a given direction for both players.
func _analyze_line(pos: Vector2i, dir: Vector2i, me, opponent) -> Dictionary:
	var result = {
		"my_count": 0, "my_open_ends": 0, "blocked_by_opponent": 0,
		"opp_count": 0, "opp_open_ends": 0, "blocked_by_me": 0,
	}

	for sign in [1, -1]:
		var my_run = 0
		var opp_run = 0
		var hit_wall = false

		for i in range(1, board.WIN_LENGTH):
			var check = pos + dir * i * sign
			if not board._is_valid_pos(check):
				hit_wall = true
				break
			var state = board.board_data[check.y][check.x]
			if state == me:
				my_run += 1
			elif state == opponent:
				opp_run += 1
				break
			elif state == board.Player.DESTROYED:
				continue
			else:  # NONE = open end
				if my_run > 0:
					result["my_open_ends"] += 1
				if opp_run > 0:
					result["opp_open_ends"] += 1
				break

		result["my_count"] += my_run
		result["opp_count"] += opp_run
		if opp_run > 0:
			result["blocked_by_opponent"] += 1
		if my_run > 0 and hit_wall:
			result["blocked_by_me"] += 1  # This direction is walled off

	return result


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


## Smart bomb: maximize opponent destruction while minimizing self-damage.
func _smart_bomb_move() -> CPUMove:
	var human = board.Player.X
	var best_bomb_move: CPUMove = null
	var best_score = 0

	for bomb_type in board.player_o_bombs:
		var result = _evaluate_bomb_destruction(bomb_type, human)
		if result["score"] > best_score:
			best_score = result["score"]
			best_bomb_move = CPUMove.new(Action.USE_BOMB, result["pos"], bomb_type)

	if best_score >= 2:
		return best_bomb_move
	return null


## Offensive bomb: consider whether a bomb can create a winning position.
## Check if removing blockers from a line would create a near-win or win.
func _offensive_bomb_move(cpu, human) -> CPUMove:
	# First try smart destruction (targeting opponent lines)
	var smart = _smart_bomb_move()

	# Also check if a bomb can set up a win for us
	var best_offensive: CPUMove = null
	var best_offensive_score = 0.0

	for bomb_type in board.player_o_bombs:
		var result = _evaluate_bomb_offensive(bomb_type, cpu, human)
		if result["score"] > best_offensive_score:
			best_offensive_score = result["score"]
			best_offensive = CPUMove.new(Action.USE_BOMB, result["pos"], bomb_type)

	# Prefer offensive bombs if they set up wins, otherwise use smart destruction
	if best_offensive and best_offensive_score >= 4.0:
		return best_offensive
	if smart:
		return smart
	if best_offensive and best_offensive_score >= 2.0:
		return best_offensive
	return null


func _evaluate_bomb_destruction(bomb_type: int, target_player) -> Dictionary:
	var best_pos = Vector2i(0, 0)
	var best_score = 0

	for y in range(board.BOARD_HEIGHT):
		for x in range(board.BOARD_WIDTH):
			if board.board_data[y][x] == board.Player.DESTROYED:
				continue

			var pos = Vector2i(x, y)
			var opp_marks = _count_bomb_hits(bomb_type, pos, target_player)
			var own_marks = _count_bomb_hits(bomb_type, pos, board.Player.O)

			var score = opp_marks * 2 - own_marks * 3  # Heavily penalize self-damage

			if score > best_score:
				best_score = score
				best_pos = pos

	return {"pos": best_pos, "score": best_score}


## Evaluate if a bomb creates a winning setup by removing opponent blockers.
func _evaluate_bomb_offensive(bomb_type: int, cpu, human) -> Dictionary:
	var best_pos = Vector2i(0, 0)
	var best_score = 0.0

	for y in range(board.BOARD_HEIGHT):
		for x in range(board.BOARD_WIDTH):
			if board.board_data[y][x] == board.Player.DESTROYED:
				continue

			var pos = Vector2i(x, y)

			# Count opponent marks this bomb would remove
			var opp_removed = _count_bomb_hits(bomb_type, pos, human)
			# Count own marks we'd lose
			var own_removed = _count_bomb_hits(bomb_type, pos, cpu)

			# Heavy penalty for self-damage
			if own_removed > 0:
				continue

			# Bonus if this removes marks that are blocking our lines
			var blocking_score = _count_bomb_unblocks(bomb_type, pos, cpu, human)

			var score = opp_removed + blocking_score * 2.0

			if score > best_score:
				best_score = score
				best_pos = pos

	return {"pos": best_pos, "score": best_score}


## Count how many of `player`'s marks would be hit by this bomb.
func _count_bomb_hits(bomb_type: int, pos: Vector2i, player) -> int:
	var positions = _get_bomb_target_positions(bomb_type, pos)
	var count = 0
	for p in positions:
		if board.board_data[p.y][p.x] == player:
			count += 1
	return count


## Count how many of our near-win lines this bomb would unblock.
func _count_bomb_unblocks(bomb_type: int, pos: Vector2i, me, opponent) -> int:
	var destroyed_positions = _get_bomb_target_positions(bomb_type, pos)
	var unblock_count = 0

	# Check each of our marks to see if destroying nearby opponent marks helps
	for y in range(board.BOARD_HEIGHT):
		for x in range(board.BOARD_WIDTH):
			if board.board_data[y][x] != me:
				continue

			var my_pos = Vector2i(x, y)
			var directions = [
				Vector2i(1, 0), Vector2i(0, 1),
				Vector2i(1, 1), Vector2i(1, -1)
			]

			for dir in directions:
				var my_count = 1
				var blocker_in_blast = false

				for sign_val in [1, -1]:
					for i in range(1, board.WIN_LENGTH):
						var check = my_pos + dir * i * sign_val
						if not board._is_valid_pos(check):
							break
						var state = board.board_data[check.y][check.x]
						if state == me:
							my_count += 1
						elif state == opponent:
							if check in destroyed_positions:
								blocker_in_blast = true
							break
						elif state == board.Player.DESTROYED:
							continue
						else:
							break

				if my_count >= board.WIN_LENGTH - 2 and blocker_in_blast:
					unblock_count += 1

	return unblock_count


## Get all positions that a bomb of the given type would destroy.
func _get_bomb_target_positions(bomb_type: int, pos: Vector2i) -> Array:
	var positions: Array = []

	match bomb_type:
		board.BombType.ROW:
			for bx in range(board.BOARD_WIDTH):
				var p = Vector2i(bx, pos.y)
				if board.board_data[p.y][p.x] != board.Player.DESTROYED:
					positions.append(p)
		board.BombType.COLUMN:
			for by in range(board.BOARD_HEIGHT):
				var p = Vector2i(pos.x, by)
				if board.board_data[p.y][p.x] != board.Player.DESTROYED:
					positions.append(p)
		board.BombType.DIAGONAL:
			for dir in [Vector2i(1, 1), Vector2i(1, -1)]:
				for i in range(-board.BOARD_WIDTH, board.BOARD_WIDTH):
					var p = pos + dir * i
					if board._is_valid_pos(p) and board.board_data[p.y][p.x] != board.Player.DESTROYED:
						if not p in positions:
							positions.append(p)

	return positions


func _get_non_destroyed_positions() -> Array:
	var positions: Array = []
	for y in range(board.BOARD_HEIGHT):
		for x in range(board.BOARD_WIDTH):
			if board.board_data[y][x] != board.Player.DESTROYED:
				positions.append(Vector2i(x, y))
	return positions
