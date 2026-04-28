# Game Setting And Word Poison Separation Design

## Goal

Move all pre-game setup responsibilities into `scenes/game_setting.tscn` and keep `scenes/word_poison_game.tscn` focused on gameplay only.

After this change, the player should complete all setup from the redesigned game-setting page, press `开始`, and enter the Word Poison game directly without seeing any additional internal setup screens.

## Project Context

- `scripts/game_setting.gd` still contains the previous settings logic, but the entire file is commented out and no longer drives the current refactored scene.
- `scenes/game_setting.tscn` has already been visually restructured. Its node tree no longer matches the older script or the older test expectations.
- `scripts/word_poison_game.gd` currently owns four stages of flow: word source, player setup, gameplay, and scoreboard.
- The user wants `GameSetting` to become the only place for setup. `WordPoison` should act as the game screen and runtime controller only.

## Scope

This design covers:

1. Restoring full setup behavior inside `scripts/game_setting.gd` against the current refactored `scenes/game_setting.tscn` structure.
2. Moving word-set selection, layout choice, player editing, import, and start validation entirely into `GameSetting`.
3. Updating `scripts/word_poison_game.gd` so gameplay can start from externally supplied configuration.
4. Removing or bypassing the internal setup flow from `WordPoison`.
5. Updating scene tests to match the new structure and start flow.

This design does not cover:

- redesigning the gameplay screen visuals
- changing gameplay rules, scoring rules, or board-generation rules
- changing the word-set storage format

## Recommended Approach

Use `GameSetting` as a dedicated setup controller and `WordPoison` as a dedicated runtime controller.

- `GameSetting` owns all editable pre-game state
- `WordPoison` accepts a normalized startup payload and immediately initializes gameplay
- scene transition happens only after setup is complete and validated

This is the best option because it matches the new UX requirement, preserves the existing gameplay code that already works after setup, and avoids keeping setup responsibilities split across two scenes.

## Alternatives Considered

### Option A: Recommended

Refactor `word_poison_game.gd` to accept startup configuration and skip its own setup panels.

Pros:

- clear ownership boundary between setup and gameplay
- minimal duplication of gameplay logic
- easier to test because configuration is explicit

Cons:

- requires a small scene-to-scene handoff mechanism

### Option B

Keep `word_poison_game.gd` mostly unchanged and simulate its internal setup from `game_setting.gd`.

Pros:

- less immediate surgery inside `word_poison_game.gd`

Cons:

- setup remains split across scenes
- user-visible flow and code ownership stay inconsistent
- harder to reason about future changes

### Option C

Use global singleton state to pass setup into `WordPoison` implicitly.

Pros:

- quick to wire

Cons:

- hidden coupling
- harder to test and debug
- state lifetime becomes less obvious

## Architecture

### Game Setting Responsibilities

`scripts/game_setting.gd` becomes the single owner of these responsibilities:

1. load and refresh available word sets from `WordSetStore`
2. select the active word set
3. import a new word set through `FileDialog`
4. select board size
5. add, remove, and rename players
6. compute start readiness
7. hand off a normalized configuration to gameplay

The script should adapt to the current scene tree instead of trying to force the scene back to the old node structure.

### Word Poison Responsibilities

`scripts/word_poison_game.gd` becomes the owner of these runtime-only responsibilities:

1. accept startup configuration supplied before or during scene initialization
2. parse the selected word set into `_all_words`
3. convert player seeds into gameplay player state
4. generate board cells
5. run turn progression and elimination logic
6. render gameplay and scoreboard
7. return to `game_setting.tscn` when replaying or leaving

`WordPoison` should no longer require the player to interact with `word_source_panel` or `player_setup_panel` during normal entry from `GameSetting`.

## Startup Data Contract

The setup-to-game handoff should use a single normalized dictionary:

```gdscript
{
	"word_set": Dictionary,
	"board_size": int,
	"players": Array[Dictionary]
}
```

Required expectations:

- `word_set.file_path` is a valid imported or stored word-list path
- `word_set.file_name` is the display label shown in gameplay
- `board_size` is one of `3`, `4`, or `5`
- each player entry contains at least `id` and `name`

The receiving side should defensively normalize values but should not try to reconstruct a missing setup step.

## Game Setting Design

### Node Adaptation

The current `game_setting.tscn` structure differs from the older script and tests. The implementation should bind against the current refactored nodes, including:

- the word-set selector section under `WordSetSection`
- the layout controls under `LayoutSection`
- the player area under `PlayerSettingSection`
- the action buttons and `UploadFileDialog`

If a current node is decorative only, the script should not depend on it for state.

### Word Set Behavior

`GameSetting` must restore the original feature set for word-set handling:

1. load all available word sets from `WordSetStore`
2. show them in the current selector UI
3. preserve selection across refresh when the selected file still exists
4. clear or fall back safely when the selected file no longer exists
5. support import through `UploadFileDialog`
6. show import failure or parse failure through the main status surface used by the page

The UI can be visually different from the old implementation, but the behavior must remain equivalent.

### Layout Behavior

`GameSetting` should expose `3x3`, `4x4`, and `5x5` as the only board-size options.

Behavior rules:

- one size is always selected
- default remains `4x4` unless the current scene already encodes a different intended default
- visual toggle state must stay synchronized with `_board_size`

### Player Behavior

`GameSetting` should restore dynamic player management with the same logical rules as before:

- minimum players: `1`
- maximum players: `10`
- default players: one seeded player named `玩家1`
- adding a player appends a new player with the next default name
- removing a player reindexes IDs
- blank names are normalized back to the default player name for that slot before handoff

Because the scene is refactored, the visible player UI may be rebuilt differently than before, but the final behavior should remain equivalent.

### Start Validation And Navigation

`StartButton` should remain disabled unless a valid word set is selected.

On start:

1. validate that a word set exists
2. parse the selected word file before leaving the settings scene
3. normalize player names and IDs
4. build the startup payload
5. open `word_poison_game.tscn`
6. hand the payload to the game controller

If parsing fails, the scene should remain on `GameSetting` and surface the failure message.

## Word Poison Design

### Entry Flow

`WordPoison` should support a direct-entry mode driven by external setup data.

Normal flow after this change:

1. scene loads
2. startup data is available to the controller
3. controller parses words and builds runtime state
4. gameplay panel is shown immediately

The old internal setup panels may remain in the scene temporarily if removing them would be unnecessarily disruptive, but they must not participate in the normal player-facing flow.

### Runtime Initialization

`scripts/word_poison_game.gd` should separate "receive setup data" from "start gameplay".

The initialization sequence should be:

1. accept setup payload
2. validate the payload
3. load words from `word_set.file_path`
4. build `_players` from the provided player seeds
5. set `_board_size`
6. generate cells
7. start the first player turn
8. show gameplay panel

This separation keeps startup testable and prevents the controller from depending on UI-based setup events.

### Replay And Exit Behavior

After a match ends:

- replay should return the player to `game_setting.tscn` for a fresh setup pass
- back-to-hub should still return to `game_hub.tscn`

This keeps setup centralized and avoids reintroducing configuration inside `WordPoison`.

## Error Handling

The implementation should explicitly handle:

1. selected word file missing on disk
2. selected word file parsing to an empty list
3. imported file failing validation
4. invalid board size in incoming payload
5. empty or whitespace-only player names
6. missing startup payload when `WordPoison` is opened directly during development

For direct scene runs without payload, the controller should fail safely. The exact fallback can be either:

- show a developer-friendly message and return to `GameSetting`, or
- keep a guarded development fallback path

The implementation plan should choose one path explicitly and test it.

## Testing Strategy

### TDD Expectations

Implementation should follow test-first changes:

1. update or add `GameSetting` scene tests for the refactored node tree and restored behavior
2. add a failing test for the start handoff into `WordPoison`
3. add a failing test for `WordPoison` direct gameplay initialization from external setup

### Required Coverage

At minimum, tests should verify:

1. `game_setting.tscn` still instantiates with the current refactored structure
2. the settings controller script is active and seeds one default player
3. start remains disabled until a valid word set is selected
4. importing or refreshing updates the available word-set choices
5. board-size selection updates internal state
6. player add or remove behavior preserves min and max rules
7. starting the game uses the selected word set, board size, and player list
8. `word_poison_game.gd` enters gameplay directly from supplied setup data
9. `WordPoison` no longer relies on internal setup panels for normal entry

## Implementation Notes

The implementation should prefer minimal changes that preserve working gameplay logic.

In practice, that means:

- do not rewrite turn progression or scoreboard behavior unless needed for the separation
- isolate scene-handoff code from gameplay code
- keep setup normalization close to the boundary between the two scenes
- adapt to the refactored `game_setting.tscn` instead of trying to recreate removed nodes

## Non-Goals

- no new game modes
- no new board sizes
- no new player metadata fields
- no visual redesign of `word_poison_game.tscn`
- no migration to a global app-state architecture
