# Word Poison Refactored Runtime Design

## Goal

Adapt `scenes/word_poison_game.tscn` to the newly refactored node tree while preserving the existing gameplay behavior.

After this change, `WordPoisonGame` should work as a pure runtime gameplay scene that receives setup data from `GameSetting`, renders board cells using `scenes/components/word_panel.tscn`, and transitions to a separate result scene when the match ends.

## Project Context

- `GameSetting` is already the only setup entry point and passes startup configuration into `WordPoisonGame`.
- `word_poison_game.tscn` has been restructured and now contains only gameplay-facing nodes.
- The old runtime script still expects removed nodes such as `WordSourcePanel`, `PlayerSetupPanel`, `ScoreboardPanel`, and `UploadFileDialog`.
- `word_panel.tscn` now exists as the intended single-word card component for board cells.
- The user wants the end of the match to navigate to a newly created result page instead of showing results inside `WordPoisonGame`.

## Scope

This design covers:

1. updating `scripts/word_poison_game.gd` to bind to the new `word_poison_game.tscn` structure
2. updating `scripts/gameplay_panel.gd` to the new label and button node names
3. rendering board cells with `scenes/components/word_panel.tscn`
4. creating a minimal dedicated result scene for match completion
5. updating tests so the GameSetting-to-WordPoison flow still works against the new scene tree

This design does not cover:

- redesigning `GameSetting`
- changing gameplay rules, poison logic, or scoring rules
- polishing the new result scene beyond a minimal functional version

## Recommended Approach

Treat `WordPoisonGame` as a pure runtime controller with one visible phase: active gameplay.

- `GameSetting` remains the only setup owner
- `WordPoisonGame` accepts normalized startup data and immediately starts the match
- a new `WordPoisonResult` scene owns post-match presentation and navigation
- `gameplay_panel.gd` becomes a thin renderer for the refactored gameplay UI only

This is the best fit for the refactored scene because it matches the user requirement, avoids reintroducing removed setup nodes, and keeps end-of-match responsibilities out of the gameplay scene.

## Alternatives Considered

### Option A: Recommended

Refactor the runtime script to the new node tree and create a dedicated result scene.

Pros:

- clean separation between gameplay and results
- aligns with the user’s refactor direction
- preserves current setup ownership in `GameSetting`

Cons:

- requires a new result scene and one more scene transition

### Option B

Keep the result UI inside `WordPoisonGame` and only adapt node names.

Pros:

- fewer files changed immediately

Cons:

- conflicts with the new requirement to enter a separate result page
- pushes multiple responsibilities back into one scene

### Option C

Partially restore removed old nodes to make the old script work again.

Pros:

- short-term script compatibility

Cons:

- fights the refactor instead of adapting to it
- increases long-term maintenance cost

## Architecture

### WordPoisonGame Responsibilities

`scripts/word_poison_game.gd` should own only runtime gameplay:

1. receive startup config from `GameSetting`
2. validate and normalize the config
3. parse the chosen word set
4. initialize player runtime state
5. generate board cell data
6. process clicks, poison resolution, and turn progression
7. transition to the result scene when all players are finished

It should no longer try to manage setup or internal setup fallbacks based on removed scene sections.

### GameplayPanel Responsibilities

`scripts/gameplay_panel.gd` should become a rendering adapter for the refactored gameplay UI.

It should:

1. write current-player text into `CurrentPlayerName`
2. write status text into `CurrentGameInfo`
3. render cells into `BoardGrid`
4. update sidebar labels and player summaries
5. connect `NextPlayerButton`
6. connect `EndGameButton`

It should not own any gameplay state.

### Result Scene Responsibilities

A new result scene should own only post-match presentation.

It should:

1. receive sorted result rows from `WordPoisonGame`
2. display ranking and score summary
3. provide `再玩一次` and `返回游戏选择` style navigation
4. return to `GameSetting` for replay and `game_hub.tscn` for back navigation

## Runtime Data Contract

The startup payload remains:

```gdscript
{
	"word_set": Dictionary,
	"board_size": int,
	"players": Array[Dictionary]
}
```

The result payload should be a normalized array of player dictionaries, each containing at least:

```gdscript
{
	"id": int,
	"name": String,
	"safe_click_count": int,
	"finish_order": int,
	"is_eliminated": bool
}
```

## WordPoison Node Mapping

The new scene tree changes the expected bindings.

Old runtime references to removed nodes must be replaced with the new nodes:

- old `CurrentPlayerLabel` → new `CurrentPlayerName`
- old `GameplayStatusLabel` → new `CurrentGameInfo`
- old in-scene scoreboard flow → new external result scene transition
- old plain button cell rendering → `word_panel.tscn` instances inside `BoardGrid`
- old `ScoreboardPanel` usage → removed
- old setup-related nodes and file dialog usage → removed

The new `EndGameButton` should act as an immediate manual transition to result flow using the current runtime standings.

## Board Cell Rendering

`BoardGrid` should render each cell by instantiating `res://scenes/components/word_panel.tscn`.

Behavior rules:

1. the visible label shows English before click and Chinese after click
2. the card becomes non-interactive after it has been clicked in the active turn
3. the card should emit the corresponding `cell_index` back to `WordPoisonGame`
4. the card scene should be treated as a visual shell, not a state owner

The simplest implementation is to bind click handling on the root control or a transparent button wrapper added in code if the component itself has no built-in button node.

## Turn And Endgame Behavior

Gameplay behavior should remain logically unchanged:

1. each player gets a hidden poison index for their turn
2. safe clicks increase `safe_click_count`
3. clicking the poison word ends the current player turn
4. `NextPlayerButton` advances to the next unfinished player
5. once all players are finished, runtime state is sorted and handed to the result scene

Additional behavior:

6. `EndGameButton` ends the session early and still transitions to the result scene using current standings

## Result Scene Design

The first version should be minimal and functional.

Required content:

1. title label
2. vertically listed result rows in rank order
3. replay button that returns to `game_setting.tscn`
4. back-to-hub button that returns to `game_hub.tscn`

The result scene does not need advanced animation or design polish in this pass.

## Error Handling

The implementation should explicitly handle:

1. startup payload missing or invalid
2. selected word file missing or empty
3. board size outside supported values
4. empty players array after normalization
5. board cell component failing to instantiate

For invalid startup config, `WordPoisonGame` should fail safely and return to `GameSetting` rather than trying to rebuild old setup behavior.

## Testing Strategy

### TDD Expectations

Implementation should follow test-first changes:

1. update the GameSetting-to-WordPoison integration test to the new runtime node tree
2. add a focused test for board cell rendering using `word_panel.tscn`
3. add a focused test for end-of-match transition into the new result scene

### Required Coverage

At minimum, tests should verify:

1. `WordPoisonGame` can instantiate from startup config using the new node tree
2. the current-player and status labels update through the renamed nodes
3. board cells render in `BoardGrid` using `word_panel.tscn`
4. clicking cells still drives the original turn logic
5. `NextPlayerButton` still advances turns correctly
6. `EndGameButton` transitions to the new result scene
7. all-finished flow transitions to the same result scene
8. replay from result returns to `GameSetting`
9. back-to-hub from result returns to `game_hub.tscn`

## Implementation Notes

The implementation should stay minimal:

- keep gameplay state logic in `scripts/word_poison_game.gd`
- keep rendering details in `scripts/gameplay_panel.gd`
- avoid reintroducing setup-related code into `WordPoisonGame`
- avoid adding stateful logic to `word_panel.tscn`

## Non-Goals

- no new game rules
- no changes to word parsing format
- no multiplayer network behavior
- no visual redesign of the new gameplay scene beyond what is needed for functionality
