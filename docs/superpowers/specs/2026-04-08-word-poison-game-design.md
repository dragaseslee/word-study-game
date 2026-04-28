# Word Poison Game Design

## Goal

Add a game hub scene and implement a reusable word-poison mini-game flow inside the Godot project. The game lets players select a local word-set file, configure up to 10 players, play turn-by-turn on a random word grid with one hidden poison cell per player, and finish on a ranked scoreboard with top-three effects.

## Project Context

The project is currently an empty Godot 4.6 application with only `project.godot`, an icon resource, and an empty `scenes/` directory. There is no existing gameplay, scene hierarchy, or script structure to preserve beyond keeping the project lightweight and Godot-native.

## Scope

This design covers two layers:

1. A top-level game selection scene that can host multiple mini-games later.
2. The first mini-game, a word-poison game, with four internal phases:
   - word-set selection and upload
   - player setup
   - gameplay
   - scoreboard

The first version is strictly local and single-device.

## Architecture

### Scene Hierarchy

- `GameHubScene`
  - project entry scene
  - lists available mini-games
  - starts the word-poison game

- `WordPoisonGameScene`
  - container scene for this mini-game
  - owns runtime state and phase transitions
  - hosts four child panels that are shown and hidden instead of switching root scenes

- `WordSourcePanel`
  - shows locally saved word-set files
  - supports file upload into the local game data directory
  - lets the user choose a file before continuing

- `PlayerSetupPanel`
  - manages player count, default names, and editable names
  - lets the user choose board size from `3x3`, `4x4`, `5x5`

- `GameplayPanel`
  - shows the board, current player, and sidebar status
  - runs one player turn at a time

- `ScoreboardPanel`
  - ranks players by safe clicks
  - highlights top three places with lightweight UI effects

### State Ownership

`WordPoisonGameScene` owns the game state and updates panels with fresh derived data. Panels stay dumb where practical and emit signals upward for actions like `word_set_selected`, `upload_requested`, `players_confirmed`, `cell_pressed`, and `restart_requested`.

This keeps scene responsibilities clear while avoiding a large amount of cross-panel coupling.

## Data Model

### Word Entry

Each parsed word entry contains:

- `english: String`
- `chinese: String`

### Word Set File Summary

Displayed in the selection list:

- `file_name: String`
- `file_path: String`
- `word_count: int`

### Player State

- `id: int`
- `name: String`
- `safe_click_count: int`
- `is_eliminated: bool`
- `poison_word_index: int`
- `clicked_indices: Array[int]`
- `finish_order: int`

### Board Cell State

- `cell_index: int`
- `english: String`
- `chinese: String`

Board cell content is shared across the whole match. Clicked state is not global; it is interpreted per active player turn using that player's `clicked_indices`.

## Word Set System

### Storage Location

Uploaded and persisted files live in `user://word_sets/`.

Reasons:

- persists across sessions
- supports local file browsing and upload refresh cleanly
- avoids writing user data back into `res://`

### File Format

Supported format is line-based text with one word pair per line.

Allowed separators:

- tab: `english<TAB>中文`
- comma: `english,中文`

Parsing rules:

1. trim line whitespace
2. skip empty lines
3. prefer tab splitting if present
4. otherwise split on the first comma
5. require both sides to be non-empty
6. discard invalid rows

### Word Set UI Rules

1. Read and display all files from `user://word_sets/` on panel open.
2. Show filename and parsed word count.
3. Let the user select one file as the source for the current match.
4. Let the user upload a new text file.
5. Copy uploaded files into `user://word_sets/`.
6. Refresh the list immediately after a successful upload.
7. Prevent continuing until a valid file is selected.

### Error Handling

- empty file: show a descriptive error
- no valid lines: show a format error
- duplicate uploaded filename: auto-rename instead of blocking the user

## Player Setup

Rules:

- minimum 1 player
- maximum 10 players
- default names are `玩家1`, `玩家2`, and so on
- users may edit names before confirming
- empty edited names fall back to the default generated value
- duplicate names are allowed in version 1

Board size options:

- `3x3`
- `4x4`
- `5x5`

The selected size determines the board cell count for the next phase.

## Gameplay Rules

### Board Generation

When gameplay starts:

1. calculate required cell count from board size
2. randomly select that many entries from the chosen word set
3. if the word set is smaller than required, allow repeated entries until the board is full
4. create fixed board cells for the whole match

The board content order stays stable across all players in the match.

### Turn Start

For each player turn:

1. clear the player's clicked indices for this turn
2. choose one random board index as that player's poison index
3. display the shared board with all cells face-up as English initially

### Cell Click Behavior

If the player clicks a normal cell:

- add the cell index to the player's clicked list
- increment `safe_click_count`
- disable the cell for the remainder of that player's turn
- permanently reveal the Chinese translation on that cell for that player view
- refresh the sidebar and board immediately

If the player clicks the poison cell:

- add the cell index to the player's clicked list
- disable the cell
- reveal the Chinese translation
- mark the player eliminated
- end the turn immediately

### Per-Player View Rule

Clicked and revealed state is per player turn, not global. The next player sees the same board words in the same positions, but starts with all cells available again and gets a newly randomized poison index.

## Sidebar and Scoreboard

### Gameplay Sidebar

The right sidebar displays:

- all players
- current player highlight
- each player's current safe click count
- each player's eliminated or finished status
- match-best click count so far

### Ranking

Players are ranked by:

1. `safe_click_count` descending
2. `finish_order` ascending as the tie-breaker

This keeps the requested primary score metric while producing a stable leaderboard.

### Scoreboard Actions

The scoreboard shows:

- final ranking
- player names
- safe click counts
- poisoned status
- top-three visual treatment
- button to replay the game flow
- button to return to the game hub

Replay returns to the word-set step so the player can change file, size, or player list without hidden state carrying over.

## Visual Design Constraints

Version 1 should avoid art dependencies and use built-in Godot UI only.

Top-three effects should be lightweight and achievable with style overrides and tweens:

- first place: gold tint and stronger emphasis
- second place: silver tint
- third place: bronze tint

No particle system or custom art is required for the initial delivery.

## Navigation Flow

1. enter `GameHubScene`
2. choose the word-poison game
3. open `WordSourcePanel`
4. select or upload a valid word set
5. open `PlayerSetupPanel`
6. confirm players and board size
7. open `GameplayPanel`
8. play each player turn in sequence
9. open `ScoreboardPanel` when all players are finished
10. replay the mini-game or return to the hub

## Boundaries and Edge Cases

- no files available: block continue and prompt upload
- invalid file selected: show error and keep the user on the word-set panel
- too few words: repeat entries until the board is full
- one-word file: still valid, even if many cells repeat
- name cleared by user: restore generated default name
- board size changed before start: only affects next board generation
- already clicked cell in a turn: remains disabled and keeps showing Chinese

## Testing Focus

Critical behavior to verify:

- parsing tab and comma formats correctly
- persisting uploads into `user://word_sets/`
- refreshing the file list after upload
- player add or remove limits
- default and edited player names
- board generation counts for all three sizes
- repeated fill when source word count is insufficient
- poison selection per player turn
- per-player clicked state reset while board content stays fixed
- scoreboard ranking by safe clicks

## Out of Scope for Version 1

- online word set downloads
- long-term score history
- advanced audiovisual polish
- simultaneous multiplayer interaction
- complex game catalog systems beyond one hub entry point

## Implementation Summary

The implementation should create a reusable game hub and a self-contained word-poison mini-game built from one container scene plus four phase panels. Runtime state lives in the container, persisted word files live under `user://word_sets/`, and the gameplay loop uses a fixed board with per-player hidden poison and per-player revealed click state.
