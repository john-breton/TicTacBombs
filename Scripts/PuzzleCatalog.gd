class_name PuzzleCatalog
extends Object

## Hand-crafted puzzles for Puzzle Mode.
## Each puzzle defines a board (possibly irregular), pre-placed marks,
## a fixed bomb inventory, a move budget, and a win length.

# Tile states used in puzzle board definitions.
const TILE_DISABLED = -1  # Cell doesn't exist (wall — blocks wins, unplayable)
const TILE_EMPTY = 0
const TILE_X = 1
const TILE_O = 2

# Bomb types — must match GameBoard.BombType ordering.
const BOMB_ROW = 0
const BOMB_COLUMN = 1
const BOMB_DIAGONAL = 2


static func get_puzzles() -> Array:
	return [
		{
			"id": 1,
			"name": "Explosive Entry",
			"description": "Two pairs of X, separated by a single O. One well-placed bomb is all it takes.",
			"difficulty": 1,
			"width": 5,
			"height": 1,
			"win_length": 3,
			"board": [
				[TILE_X, TILE_X, TILE_O, TILE_X, TILE_X],
			],
			"bombs": [BOMB_COLUMN],
			"max_moves": 1,
		},
		{
			"id": 2,
			"name": "Tower",
			"description": "The same idea, turned on its side.",
			"difficulty": 1,
			"width": 1,
			"height": 5,
			"win_length": 3,
			"board": [
				[TILE_X],
				[TILE_X],
				[TILE_O],
				[TILE_X],
				[TILE_X],
			],
			"bombs": [BOMB_ROW],
			"max_moves": 1,
		},
		{
			"id": 3,
			"name": "Double Trouble",
			"description": "Two blockers, two bombs. No placements available.",
			"difficulty": 2,
			"width": 5,
			"height": 1,
			"win_length": 3,
			"board": [
				[TILE_X, TILE_X, TILE_O, TILE_O, TILE_X],
			],
			"bombs": [BOMB_COLUMN, BOMB_COLUMN],
			"max_moves": 2,
		},
		{
			"id": 4,
			"name": "Setup Shot",
			"description": "A mark to reinforce, a bomb to finish the job.",
			"difficulty": 2,
			"width": 5,
			"height": 1,
			"win_length": 3,
			"board": [
				[TILE_X, TILE_EMPTY, TILE_O, TILE_X, TILE_X],
			],
			"bombs": [BOMB_COLUMN],
			"max_moves": 2,
		},
		{
			"id": 5,
			"name": "Split the Board",
			"description": "Your line is broken. Break the blocker, bridge the gap.",
			"difficulty": 2,
			"width": 5,
			"height": 3,
			"win_length": 3,
			"board": [
				[TILE_EMPTY, TILE_EMPTY, TILE_EMPTY, TILE_EMPTY, TILE_EMPTY],
				[TILE_X,     TILE_X,     TILE_O,     TILE_EMPTY, TILE_EMPTY],
				[TILE_EMPTY, TILE_EMPTY, TILE_EMPTY, TILE_EMPTY, TILE_EMPTY],
			],
			"bombs": [BOMB_COLUMN],
			"max_moves": 2,
		},
		{
			"id": 6,
			"name": "Cross Quest",
			"description": "A cross, a central obstacle, and one diagonal bomb. Find the three moves.",
			"difficulty": 3,
			"width": 5,
			"height": 5,
			"win_length": 3,
			"board": [
				[TILE_DISABLED, TILE_DISABLED, TILE_X,        TILE_DISABLED, TILE_DISABLED],
				[TILE_DISABLED, TILE_DISABLED, TILE_EMPTY,    TILE_DISABLED, TILE_DISABLED],
				[TILE_X,        TILE_EMPTY,    TILE_O,        TILE_EMPTY,    TILE_X],
				[TILE_DISABLED, TILE_DISABLED, TILE_EMPTY,    TILE_DISABLED, TILE_DISABLED],
				[TILE_DISABLED, TILE_DISABLED, TILE_X,        TILE_DISABLED, TILE_DISABLED],
			],
			"bombs": [BOMB_DIAGONAL],
			"max_moves": 3,
		},
	]


## Return a puzzle by ID, or the first puzzle if not found.
static func get_puzzle(id: int) -> Dictionary:
	var puzzles = get_puzzles()
	for p in puzzles:
		if p["id"] == id:
			return p
	return puzzles[0] if puzzles.size() > 0 else {}


## Return the next puzzle after `id`, or {} if there is none.
static func get_next_puzzle(id: int) -> Dictionary:
	var puzzles = get_puzzles()
	for i in range(puzzles.size()):
		if puzzles[i]["id"] == id and i + 1 < puzzles.size():
			return puzzles[i + 1]
	return {}
