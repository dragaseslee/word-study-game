# Game Setting Word Set Dropdown Simplification Design

## Goal

Replace the game-setting word-set selector area with the existing `custom_dropdown.tscn` as the only selector UI, and remove the extra preview/status lines below it.

## Scope

- Keep the `选择词表` title
- Keep the existing `WordSetDropdownShell` and `WordSetDropdown`
- Remove the extra `WordSetPreview` block that shows file name, word count, and status
- Keep `RefreshButton` and `ImportButton`
- Keep the existing word-set import and refresh flows
- Keep start-button enablement based on whether a valid word set is selected

## Scene Changes

In `scenes/game_setting.tscn`:

- Keep the `WordSetSection` structure
- Keep `WordSetDropdownShell` with the instantiated `custom_dropdown.tscn`
- Delete `WordSetPreview`, including:
  - `WordSetFileLabel`
  - `WordSetCountLabel`
  - `WordSetStatusLabel`
- Leave the action row under the dropdown so refresh and import remain available

## Script Changes

In `scripts/game_setting.gd`:

- Remove `@onready` references for the deleted preview labels
- Stop calling `_update_word_set_preview()`
- Remove the `_update_word_set_preview()` function
- Keep `_setup_word_set_options()` feeding items into `word_set_dropdown`
- Keep `_on_word_set_selected()` updating `_selected_word_set`
- Keep `_update_status()` and `start_button.disabled = _selected_word_set.is_empty()`
- On import failure, report the error through the existing global `status_label` instead of the deleted word-set status label

## Behavior

- When word sets exist, the custom dropdown shows them and selection updates `_selected_word_set`
- When no word sets exist, the custom dropdown remains the single source of truth for the empty state
- Refresh reloads the dropdown items
- Import reloads the dropdown items after a successful import
- No duplicate file/count/status text is shown below the dropdown

## Testing

Update `scripts/tests/test_game_setting_scene.gd` to verify:

- `WordSetDropdown` still exists in the word-set section
- `WordSetPreview` no longer exists
- The custom dropdown still renders selected text
- Start button remains disabled before a valid selection exists

## Non-Goals

- No changes to layout selection UI
- No changes to player setup UI
- No redesign of the custom dropdown visuals
- No changes to word-set storage format or import format
