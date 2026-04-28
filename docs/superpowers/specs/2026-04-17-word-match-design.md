# Word Match Design

## Goal

Add a new `word match` game flow that starts from the existing game hub, enters a dedicated `word match` settings scene, runs inside its own gameplay scene, and finishes on its own result scene.

The new game should reuse the existing word-set, layout, and player-setup capabilities where they make sense, but it must keep a separate visual style from `word poison`. `word match` also needs one game-specific setting that `word poison` does not have: the allowed mistake count.

## Project Context

- `scenes/game_hub.tscn` already shows two game cards: `WitchsPotionPanel` and `WordMatchPanel`.
- `scripts/game_hub.gd` currently wires only the `word poison` card into navigation.
- `scenes/game_setting.tscn` and `scripts/game_setting.gd` now act as the dedicated setup flow for `word poison`.
- `scenes/word_poison_game.tscn` and `scripts/word_poison_game.gd` already follow the right runtime boundary: they accept startup configuration and go straight into gameplay.
- `scripts/word_set_store.gd` already provides reusable word-set storage, import, listing, and parsing for tab- or comma-separated `english,chinese` style pairs.
- The user wants `word match` to have different visual design assets and scene structure from `word poison`, even though both games share much of the same setup behavior.
- The user confirmed `word match` should be a multiplayer turn-based game, not single-player and not simultaneous play.

## Scope

This design covers:

1. adding a dedicated `word match` route from `game hub`
2. creating a dedicated `word_match_setting` scene with its own art/style
3. reusing only shared setup logic, not the `word poison` settings scene itself
4. creating a dedicated `word_match_game` runtime scene and controller
5. creating a dedicated `word_match_result` scene and controller
6. defining the startup data contract for the new game
7. defining board generation, matching, error counting, turn progression, and result ranking rules
8. defining validation and test coverage for the new flow

This design does not cover:

- redesigning the existing `word poison` scenes
- changing `word poison` gameplay rules
- changing the word-set file format
- adding online multiplayer or persistence of scores across sessions

## Recommended Approach

Use separate scenes per game for visuals and flow, but share a minimal setup helper layer for common data shaping and validation.

- `game_hub` routes each game card into that game's own settings scene
- `word poison` keeps `scenes/game_setting.tscn` as-is for its own flow
- `word match` gets a new `scenes/word_match_setting.tscn`
- both games use shared helper code for common setup concerns such as player normalization and startup payload construction
- `word_match_game.gd` follows the same broad runtime contract as `word_poison_game.gd`: accept startup configuration first, then initialize gameplay immediately

This is the best option because it matches the user's need for distinct game presentation, avoids turning one settings scene into a multi-game switchboard, and still prevents avoidable logic duplication.

## Alternatives Considered

### Option A: Recommended

Separate settings scenes plus shared helper logic.

Pros:

- clean ownership boundaries
- each game keeps its own visual identity
- common setup logic stays reusable
- easier to extend to a third game later

Cons:

- requires a small amount of new shared infrastructure

### Option B

Create a completely standalone `word match` stack with no shared setup logic.

Pros:

- fastest to brute-force initially
- lowest coupling between the two games

Cons:

- duplicates word-set, layout, and player setup behavior
- fixes to shared setup behavior would need to be implemented twice
- higher long-term maintenance cost

### Option C

Use one unified settings scene that switches art, fields, and destination scene by game type.

Pros:

- one settings entry point
- one scene to route through

Cons:

- mixes multiple visual directions into one controller and one scene tree
- makes scene bindings more fragile
- grows complexity quickly as game-specific settings diverge

## Architecture

### Scene Flow

The new flow should be:

1. open `scenes/game_hub.tscn`
2. click the `word match` card
3. open `scenes/word_match_setting.tscn`
4. complete setup and press `开始`
5. open `scenes/word_match_game.tscn`
6. complete all player turns
7. open `scenes/word_match_result.tscn`

`word poison` continues to use its existing route:

1. open `scenes/game_hub.tscn`
2. click the `witch's potion` card
3. open `scenes/game_setting.tscn`
4. start `scenes/word_poison_game.tscn`

### Shared Setup Layer

Only pure setup logic should be shared. Scenes and node-path bindings should remain game-specific.

The shared layer should be a small helper script with responsibilities such as:

1. normalizing player seeds into `{ id, name }`
2. validating board-size values against an allowed set
3. validating game-specific rule inputs such as `max_errors`
4. building a normalized startup payload dictionary

The helper should not:

- own UI nodes
- reference scene paths
- assume one specific game's art or node tree
- perform navigation

`scripts/word_set_store.gd` remains the shared word-set source for both games.

### Game-Specific Ownership

`word_match_setting.gd` should own:

1. binding to the `word match` settings scene tree
2. rendering the game-specific visual style and controls
3. loading and selecting word sets
4. board-size selection
5. player add/remove/rename behavior
6. allowed-mistake selection and validation
7. start-button enablement and error display
8. building and passing startup config into `word_match_game`

`word_match_game.gd` should own:

1. accepting startup config
2. validating startup config and recovering safely if invalid
3. generating the shared board layout for the match
4. maintaining per-player progress and error state
5. handling selection and match resolution
6. handling player turn progression
7. determining success, failure, and final ranking
8. navigating to the `word match` result scene

`word_match_result.gd` should own:

1. rendering ranked player results
2. replay navigation back to `word_match_setting.tscn`
3. back-to-hub navigation to `game_hub.tscn`

## Startup Data Contract

The setup-to-game handoff should use one normalized dictionary:

```gdscript
{
	"game_type": "word_match",
	"word_set": {
		"file_name": String,
		"file_path": String,
		"word_count": int,
	},
	"board_size": int,
	"players": Array[Dictionary],
	"rules": {
		"max_errors": int,
	}
}
```

Required expectations:

- `game_type` must be `word_match`
- `word_set.file_path` points to a valid parseable word file
- `board_size` is one of the sizes supported by `word match`
- each player contains at least `id` and `name`
- `rules.max_errors` is an integer greater than or equal to `0`

The runtime side should normalize defensively, but it should not invent missing configuration if the payload is malformed.

## Word Match Setting Design

### Separate Scene Requirement

`word match` needs a dedicated settings scene because the user wants different design language and assets from `word poison`.

This scene may share the same broad sections as `word poison`, but the node tree, assets, and presentation are allowed to differ.

### Required Setting Sections

`word_match_setting.tscn` must include:

1. word-set selection
2. board-layout selection
3. player settings
4. allowed-mistake selection
5. back and start actions

### Word Set Behavior

The `word match` settings controller should:

1. list all valid word sets from `WordSetStore`
2. preserve the prior selection when refreshing if the file still exists
3. support importing new word sets through `FileDialog`
4. disable start when no valid word set is selected
5. validate that the selected word set contains enough pairs for the selected board size

Minimum pair requirement should be:

`floor(board_size * board_size / 2)` valid word pairs.

Examples:

- `3x3` requires `4` pairs plus `1` blank cell
- `4x4` requires `8` pairs
- `5x5` requires `12` pairs plus `1` blank cell

### Layout Behavior

`word match` should expose the same visible layout choices as the current project: `3x3`, `4x4`, and `5x5`.

Behavior rules:

- one size is always selected
- default is `4x4`
- UI toggle state must stay synchronized with the stored board size
- validation logic must account for odd-sized boards using a blank slot

### Player Behavior

Player setup should follow the same logical rules as `word poison`:

- minimum players: `1`
- maximum players: `10`
- default players: one seeded player named `玩家1`
- added players receive the next default name
- removed players are reindexed
- blank names are normalized before startup handoff

### Allowed Mistake Behavior

`word match` needs one extra setup field: allowed mistakes.

Behavior rules:

- it is required input
- it should be stored as a non-negative integer
- it must be included under `rules.max_errors` in startup config
- the settings scene should make the chosen value visible before start

### Start Validation And Navigation

On start:

1. ensure a valid word set is selected
2. parse the selected word file
3. ensure the file contains enough pairs for the selected board size
4. normalize players
5. validate `max_errors`
6. build the startup payload
7. instantiate `word_match_game.tscn`
8. pass the payload through `set_startup_config`

If validation fails, the scene should stay on the settings page and surface a clear message.

## Word Match Runtime Design

### Entry Flow

`word_match_game.gd` should behave as a pure runtime controller.

Normal flow:

1. scene loads
2. startup config is already available
3. controller validates the config
4. controller parses the selected word file
5. controller builds board state and per-player state
6. first player turn starts immediately

If the scene is opened directly without valid startup data, it should fail safely by returning to `word_match_setting.tscn`.

### Board Model

The runtime board should be based on a shared fixed layout for the whole match.

Each board cell should carry data equivalent to:

```gdscript
{
	"cell_index": int,
	"kind": "word" | "blank",
	"pair_id": int,
	"text": String,
	"language": "english" | "chinese"
}
```

Rules:

- the same board content and positions are reused for every player in the match
- only player progress differs between turns
- a blank cell has `kind == "blank"` and should not participate in matching logic

### Board Generation

Cell count is `board_size * board_size`.

Pair count is `floor(cell_count / 2)`.

Board generation should:

1. randomly select `pair_count` word pairs from the parsed word list
2. create one English card and one Chinese card for each selected pair
3. shuffle those cards across the board
4. if `cell_count` is odd, add exactly one blank cell
5. shuffle the blank cell together with the cards so its position is not fixed

The blank cell should render as an empty slot or non-playable blank card.

### Player Runtime State

Each runtime player should track at least:

```gdscript
{
	"id": int,
	"name": String,
	"matched_pair_count": int,
	"error_count": int,
	"matched_cell_indices": Array[int],
	"is_cleared": bool,
	"is_failed": bool,
	"finish_order": int,
}
```

Each player's `matched_cell_indices` belongs only to that player. One player clearing a pair must not clear it for the next player.

### Turn Structure

The game is multiplayer and turn-based.

Each player gets an independent turn on the same underlying board.

Turn start should:

1. set the current player index
2. clear the current in-turn selection buffer
3. render the board using that player's matched state
4. show the current player's mistake count and progress

When a player clears all real word pairs, that player finishes successfully and the turn ends.

When a player exceeds the configured mistake limit, that player fails and the turn ends.

The next player then starts on a fresh personal board state against the same board layout.

### Selection And Match Resolution

The active player may select up to two non-blank, non-cleared cells.

Interaction rules:

1. clicking a blank cell does nothing
2. clicking a cleared cell does nothing
3. clicking the same uncleared cell twice ignores the second click
4. first click stores a temporary selection and highlights the card
5. second click triggers pair validation

A match is valid only when:

- both cells share the same `pair_id`
- one cell is English and the other is Chinese

If valid:

- both cell indices are added to the current player's matched indices
- `matched_pair_count` increases by `1`
- the temporary selection is cleared

If invalid:

- `error_count` increases by `1`
- the temporary selection is cleared

### Failure Rule

The user confirmed that allowed mistakes means the player may make exactly `X` mistakes safely.

Failure happens on the `X + 1`th mistake.

Examples:

- `max_errors = 0`: first wrong match fails the turn
- `max_errors = 3`: mistakes `1`, `2`, and `3` are allowed; mistake `4` fails the turn

### Success Rule

Success happens when the player has matched all real word pairs on the board.

The blank cell does not need to be interacted with and does not count toward completion.

### Turn Completion And Match Completion

When a player finishes or fails:

1. mark that player's terminal state
2. assign `finish_order`
3. show a transition state or action prompt
4. move to the next player if any remain

When all players are terminal, open `word_match_result.tscn` with the ranked results.

## Word Match Result Design

The result scene should render a ranking view specific to `word match`.

Each player row should show at least:

1. player name
2. matched pair count
3. error count
4. cleared/failed status
5. final position

### Ranking Rule

Players should be sorted by:

1. `is_cleared == true` first
2. higher `matched_pair_count` first
3. lower `error_count` first
4. lower `finish_order` first

### Result Actions

The result scene should provide:

- `再玩一次`: return to `word_match_setting.tscn`
- `返回游戏选择`: return to `game_hub.tscn`

## Error Handling

The implementation should explicitly handle:

1. no available word sets in the settings scene
2. imported file failing parse or validation
3. selected word set no longer existing on disk
4. selected word set not containing enough pairs for the requested board size
5. invalid or missing `max_errors`
6. invalid board size in startup config
7. empty player list in startup config
8. blank or whitespace-only player names
9. direct opening of `word_match_game.tscn` without startup config
10. direct opening of `word_match_result.tscn` without results

Safe behavior should be explicit:

- settings errors keep the user on the settings scene and show a message
- invalid runtime entry returns to `word_match_setting.tscn`
- invalid result entry returns to `word_match_setting.tscn`

## Testing Strategy

### Game Hub Test Coverage

Tests should verify:

1. `game_hub.tscn` instantiates successfully
2. the `word match` card is wired to navigation
3. clicking the `word match` card opens `word_match_setting.tscn`

### Word Match Setting Test Coverage

Tests should verify:

1. `word_match_setting.tscn` instantiates successfully
2. one default player is seeded
3. players can be added and removed within limits
4. blank player names normalize correctly before startup
5. board size selection updates internal state
6. allowed mistake selection updates internal state
7. start stays disabled without a valid word set
8. start stays blocked when the selected word set is too small for the chosen layout
9. start succeeds when configuration is valid
10. startup payload contains `game_type`, `word_set`, `board_size`, `players`, and `rules.max_errors`

### Word Match Runtime Test Coverage

Tests should verify:

1. valid startup config opens directly into gameplay
2. `4x4` produces `8` pairs and no blank cell
3. `3x3` and `5x5` produce exactly one blank cell
4. matching an English card with its Chinese partner clears the pair
5. choosing a wrong pair increments `error_count`
6. the player fails on the `max_errors + 1`th mistake
7. the player clears successfully after matching every real pair
8. the next player starts with independent matched state on the same board layout
9. all players finishing opens `word_match_result.tscn`

### Word Match Result Test Coverage

Tests should verify:

1. result scene renders ranked rows from supplied results
2. ranking order follows the agreed rule
3. replay returns to `word_match_setting.tscn`
4. back-to-hub returns to `game_hub.tscn`

## Implementation Notes

- Keep the shared setup helper minimal and data-oriented.
- Do not force `word poison` and `word match` to share the same node tree.
- Reuse the existing word-set storage format and parsing behavior.
- Preserve the project's current direct scene-instantiation startup pattern rather than introducing global singleton handoff.
