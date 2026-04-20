class_name PuzzleCatalog
extends Object

## Hand-crafted puzzles for Puzzle Mode.
## Each puzzle defines a board (possibly irregular), pre-placed marks,
## a fixed bomb inventory, a move budget, and a win length.
## Every puzzle is designed to require multiple moves to solve.

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
			"name": "Build and Blast",
			"description": "A blocker stands between you and the rest of your line. Place a mark, then break the wall.",
			"difficulty": 1,
			"width": 6,
			"height": 1,
			"win_length": 3,
			"board": [
				[TILE_X, TILE_X, TILE_O, TILE_EMPTY, TILE_EMPTY, TILE_X],
			],
			"bombs": [BOMB_COLUMN],
			"max_moves": 2,
		},
		{
			"id": 2,
			"name": "Tower Setup",
			"description": "Same idea, standing tall. Reinforce your column, then crack the wall.",
			"difficulty": 1,
			"width": 1,
			"height": 6,
			"win_length": 3,
			"board": [
				[TILE_X],
				[TILE_X],
				[TILE_O],
				[TILE_EMPTY],
				[TILE_EMPTY],
				[TILE_X],
			],
			"bombs": [BOMB_ROW],
			"max_moves": 2,
		},
		{
			"id": 3,
			"name": "The Pin",
			"description": "One X, one wall, one stray X behind it. Place a mark, then blast through.",
			"difficulty": 1,
			"width": 4,
			"height": 1,
			"win_length": 3,
			"board": [
				[TILE_EMPTY, TILE_X, TILE_O, TILE_X],
			],
			"bombs": [BOMB_COLUMN],
			"max_moves": 2,
		},
		{
			"id": 4,
			"name": "Heads Up",
			"description": "The Pin, vertical. Stack the line, drop the wall.",
			"difficulty": 1,
			"width": 1,
			"height": 4,
			"win_length": 3,
			"board": [
				[TILE_EMPTY],
				[TILE_X],
				[TILE_O],
				[TILE_X],
			],
			"bombs": [BOMB_ROW],
			"max_moves": 2,
		},
		{
			"id": 5,
			"name": "Double Trouble",
			"description": "Two blockers stand between two pairs. Two bombs are exactly enough.",
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
			"id": 6,
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
			"id": 7,
			"name": "Patience",
			"description": "Two empties, a wall, and one X on the far side. The bomb is a trap — find the cleaner path.",
			"difficulty": 2,
			"width": 5,
			"height": 1,
			"win_length": 3,
			"board": [
				[TILE_X, TILE_EMPTY, TILE_EMPTY, TILE_O, TILE_X],
			],
			"bombs": [BOMB_COLUMN],
			"max_moves": 2,
		},
		{
			"id": 8,
			"name": "Split the Board",
			"description": "Your line is broken. Bridge it however you can.",
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
			"id": 9,
			"name": "Sandwich",
			"description": "Four X's, three walls, three bombs. No room to spare — anything left standing breaks the chain.",
			"difficulty": 2,
			"width": 7,
			"height": 1,
			"win_length": 3,
			"board": [
				[TILE_X, TILE_X, TILE_O, TILE_O, TILE_O, TILE_X, TILE_X],
			],
			"bombs": [BOMB_COLUMN, BOMB_COLUMN, BOMB_COLUMN],
			"max_moves": 3,
		},
		{
			"id": 10,
			"name": "Stockpile",
			"description": "One X to start, a wall in the middle, and an empty stretch. Build up before you blast.",
			"difficulty": 2,
			"width": 5,
			"height": 1,
			"win_length": 3,
			"board": [
				[TILE_X, TILE_EMPTY, TILE_O, TILE_EMPTY, TILE_EMPTY],
			],
			"bombs": [BOMB_COLUMN],
			"max_moves": 3,
		},
		{
			"id": 11,
			"name": "Three Steps",
			"description": "Two X's pinned by walls, with a clear column down the middle. Two routes — both take three moves.",
			"difficulty": 2,
			"width": 5,
			"height": 3,
			"win_length": 3,
			"board": [
				[TILE_O, TILE_EMPTY, TILE_EMPTY, TILE_EMPTY, TILE_O],
				[TILE_X, TILE_O,     TILE_EMPTY, TILE_O,     TILE_X],
				[TILE_O, TILE_EMPTY, TILE_EMPTY, TILE_EMPTY, TILE_O],
			],
			"bombs": [BOMB_COLUMN, BOMB_COLUMN],
			"max_moves": 3,
		},
		{
			"id": 12,
			"name": "Bridge Out",
			"description": "Two pieces sit on opposite sides, with a wall between them. Three deliberate moves.",
			"difficulty": 3,
			"width": 5,
			"height": 3,
			"win_length": 3,
			"board": [
				[TILE_EMPTY, TILE_EMPTY, TILE_EMPTY, TILE_EMPTY, TILE_EMPTY],
				[TILE_X,     TILE_EMPTY, TILE_O,     TILE_EMPTY, TILE_X],
				[TILE_EMPTY, TILE_EMPTY, TILE_EMPTY, TILE_EMPTY, TILE_EMPTY],
			],
			"bombs": [BOMB_COLUMN],
			"max_moves": 3,
		},
		{
			"id": 13,
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
		{
			"id": 14,
			"name": "Cracked Open",
			"description": "A diagonal almost reaches across. Set the keystone, then split the wall — but mind where the bomb lands.",
			"difficulty": 3,
			"width": 4,
			"height": 4,
			"win_length": 3,
			"board": [
				[TILE_X,     TILE_EMPTY, TILE_EMPTY, TILE_EMPTY],
				[TILE_EMPTY, TILE_O,     TILE_EMPTY, TILE_EMPTY],
				[TILE_EMPTY, TILE_EMPTY, TILE_EMPTY, TILE_EMPTY],
				[TILE_EMPTY, TILE_EMPTY, TILE_EMPTY, TILE_X],
			],
			"bombs": [BOMB_DIAGONAL],
			"max_moves": 2,
		},
		{
			"id": 15,
			"name": "Cracked Wider",
			"description": "Two walls on the diagonal, two bombs in your pocket. Choose targets that don't take your own X's with them.",
			"difficulty": 3,
			"width": 5,
			"height": 5,
			"win_length": 3,
			"board": [
				[TILE_X,     TILE_EMPTY, TILE_EMPTY, TILE_EMPTY, TILE_EMPTY],
				[TILE_EMPTY, TILE_O,     TILE_EMPTY, TILE_EMPTY, TILE_EMPTY],
				[TILE_EMPTY, TILE_EMPTY, TILE_EMPTY, TILE_EMPTY, TILE_EMPTY],
				[TILE_EMPTY, TILE_EMPTY, TILE_EMPTY, TILE_O,     TILE_EMPTY],
				[TILE_EMPTY, TILE_EMPTY, TILE_EMPTY, TILE_EMPTY, TILE_X],
			],
			"bombs": [BOMB_DIAGONAL, BOMB_DIAGONAL],
			"max_moves": 3,
		},
		{
			"id": 16,
			"name": "Long Reach",
			"description": "Four in a row this time. Plan all three moves before you commit.",
			"difficulty": 3,
			"width": 7,
			"height": 1,
			"win_length": 4,
			"board": [
				[TILE_X, TILE_EMPTY, TILE_O, TILE_EMPTY, TILE_EMPTY, TILE_EMPTY, TILE_X],
			],
			"bombs": [BOMB_COLUMN],
			"max_moves": 3,
		},
		{
			"id": 17,
			"name": "The Spread",
			"description": "Two walls, two bombs, two X's needed in the middle. Five moves with no slack.",
			"difficulty": 3,
			"width": 7,
			"height": 1,
			"win_length": 4,
			"board": [
				[TILE_X, TILE_EMPTY, TILE_O, TILE_EMPTY, TILE_O, TILE_EMPTY, TILE_X],
			],
			"bombs": [BOMB_COLUMN, BOMB_COLUMN],
			"max_moves": 5,
		},
		{
			"id": 18,
			"name": "The Long March",
			"description": "Seven in a row across thirteen cells. Every gap is a placement, every wall is a bomb. Eleven moves, no slack.",
			"difficulty": 3,
			"width": 13,
			"height": 1,
			"win_length": 7,
			"board": [
				[
					TILE_X, TILE_EMPTY, TILE_O, TILE_EMPTY, TILE_O,
					TILE_EMPTY, TILE_O, TILE_EMPTY, TILE_O, TILE_EMPTY,
					TILE_O, TILE_EMPTY, TILE_X,
				],
			],
			"bombs": [BOMB_COLUMN, BOMB_COLUMN, BOMB_COLUMN, BOMB_COLUMN, BOMB_COLUMN],
			"max_moves": 11,
		},
		{
			"id": 19,
			"name": "The Iron Spire",
			"description": "The same gauntlet, standing tall. Row bombs only — pick your sequence carefully.",
			"difficulty": 3,
			"width": 1,
			"height": 13,
			"win_length": 7,
			"board": [
				[TILE_X],
				[TILE_EMPTY],
				[TILE_O],
				[TILE_EMPTY],
				[TILE_O],
				[TILE_EMPTY],
				[TILE_O],
				[TILE_EMPTY],
				[TILE_O],
				[TILE_EMPTY],
				[TILE_O],
				[TILE_EMPTY],
				[TILE_X],
			],
			"bombs": [BOMB_ROW, BOMB_ROW, BOMB_ROW, BOMB_ROW, BOMB_ROW],
			"max_moves": 11,
		},
		{
			"id": 20,
			"name": "Marathon",
			"description": "Eight in a row across seventeen cells. Seven placements, six bombs, zero room for waste.",
			"difficulty": 3,
			"width": 17,
			"height": 1,
			"win_length": 8,
			"board": [
				[
					TILE_X, TILE_EMPTY, TILE_O, TILE_EMPTY, TILE_O,
					TILE_EMPTY, TILE_O, TILE_EMPTY, TILE_O, TILE_EMPTY,
					TILE_O, TILE_EMPTY, TILE_O, TILE_EMPTY, TILE_O,
					TILE_EMPTY, TILE_X,
				],
			],
			"bombs": [
				BOMB_COLUMN, BOMB_COLUMN, BOMB_COLUMN,
				BOMB_COLUMN, BOMB_COLUMN, BOMB_COLUMN,
			],
			"max_moves": 13,
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
