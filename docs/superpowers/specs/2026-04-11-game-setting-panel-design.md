# Game Setting Panel Design

## Goal

Build a single-page, custom-styled game settings scene for the Godot project so the user can bind existing image assets and immediately see the intended in-game menu layout. The panel must support word-set selection, layout selection, and player-count management inside one decorated main panel.

## Project Context

The project already uses Godot 4.6 and has an established image-first menu style:

- `scenes/game_hub.tscn` uses a full-screen background plus cropped texture assets for game cards.
- `scenes/word_poison_game.tscn` currently uses standard container-driven UI for word source, player setup, gameplay, and scoreboard.
- `scenes/game_setting.tscn` exists as a minimal proof of concept that displays a cropped region from `asserts/panel_design.png`.
- Existing art assets include `panel_design.png`, `button_general.png`, `layout_choose.png`, and other UI textures that are suitable for atlas cropping.

The new work should preserve the current game logic while introducing a scene that is visually ready for asset hookup.

## Scope

This design covers:

1. An upgraded `scenes/game_setting.tscn` single-page settings scene built around one large decorated panel.
2. A left-right split layout inside the panel.
3. A word-set selector with a custom visual dropdown area and preview block.
4. A layout selector with a matching custom visual dropdown area and preview block.
5. A player-count stepper with a player list under it.
6. Clear asset attachment points so existing textures can be wired in without reworking the scene structure.

This design does not yet cover:

- replacing gameplay or scoreboard visuals
- authoring final production art
- adding new gameplay rules

## Recommended Approach

Use a hybrid scene layout:

- keep a small number of `MarginContainer`, `HBoxContainer`, and `VBoxContainer` nodes for responsive structure
- use dedicated `TextureRect`, `NinePatchRect`, `PanelContainer`, `Button`, and `OptionButton` wrappers for decorated UI pieces
- separate logical controls from decorative art so assets can be swapped without changing script paths

This approach is better than a pure container layout because it supports heavy image styling, and better than full manual coordinates because it remains stable across window sizes.

## Scene Architecture

### Root Structure

The settings UI should be implemented by directly upgrading the existing `scenes/game_setting.tscn` scene rather than creating a parallel scene. The scene remains a standalone `Control` with this top-level structure:

1. `Background`
2. `ScreenMargin`
3. `MainPanelShell`

`Background` handles the full-screen backdrop. `ScreenMargin` keeps the panel away from screen edges. `MainPanelShell` centers and sizes the decorated settings panel.

### Main Panel Layout

Inside `MainPanelShell`, the main content is split into two columns:

- `LeftColumn`
- `RightColumn`

The left column contains content-selection modules. The right column contains player setup and action buttons.

Each module should use the same pattern:

1. decorative background node
2. content margin node
3. title label
4. interactive controls
5. helper or status label

This keeps art and logic loosely coupled.

## Detailed Module Design

### Left Column

#### Word Set Module

Purpose: choose the active word set and preview its metadata.

Contents:

1. module title label: `选择词表`
2. custom dropdown shell
3. actual `OptionButton` or equivalent interactive selector layered inside the shell
4. preview text block showing:
   - selected file name
   - word count
   - current availability or validation status
5. secondary actions row:
   - refresh button
   - import button

Design rule: the decorative dropdown background must be independent from the real selection control. The user should be able to swap the dropdown image without affecting logic.

#### Layout Module

Purpose: choose board layout size for the next match.

Contents:

1. module title label: `选择布局`
2. custom dropdown shell
3. real `OptionButton` with values `3x3`, `4x4`, `5x5`
4. preview area showing the current choice, either as text or a small decorative image region

Terminology rule: use player-facing language such as `布局` or `版式大小`, not low-level terms like `矩阵尺寸`, unless the rest of the game also uses that wording.

### Right Column

#### Player Count Module

Purpose: quickly control the number of active players.

Contents:

1. module title label: `玩家数量`
2. horizontal stepper row:
   - minus image button
   - count display label
   - plus image button
3. helper label: `支持 1 - 10 人`

Behavior:

- plus adds one player until `10`
- minus removes one player from the tail until `1`
- count label is the authoritative visible number

#### Player List Module

Purpose: show and edit the current player slots.

Contents:

1. scroll container or clipped list area
2. repeated player row entries

Each row contains:

1. decorative slot background
2. player index badge or label
3. `LineEdit` for player name
4. dedicated remove button for direct row removal

The list should remain visually tied to the count stepper:

- increasing count appends rows
- decreasing count removes rows from the end
- each row must include its own remove button
- row removal should immediately decrement the visible player count
- if only one player remains, the final row's remove button should be disabled rather than hidden

#### Action Module

Purpose: expose the primary exit and confirm actions.

Contents:

1. primary button: `开始游戏`
2. secondary button: `返回`
3. status line summarizing selected word set, layout, and player count

## Asset Binding Strategy

The scene should be built so each visual layer has a dedicated node for asset replacement.

### Asset Categories

#### A. Main Panel Background

Use for:

- large central panel frame
- ornamental body texture

Recommended node type:

- `TextureRect` if using a fixed atlas region
- `NinePatchRect` if the panel needs scalable corners and edges

Expected source:

- `asserts/panel_design.png`

#### B. Module Background Plates

Use for:

- the word-set module frame
- the layout module frame
- the player module frame

Recommended node type:

- `TextureRect` or `PanelContainer` with stylebox texture

These backgrounds should not own interaction. They are visual shells only.

#### C. General Buttons

Use for:

- refresh
- import
- return
- start
- plus and minus if no dedicated stepper art exists

Recommended node type:

- `Button` with theme overrides or stylebox textures
- `TextureButton` for fully image-driven buttons

Expected source:

- `asserts/button_general.png`

#### D. Dropdown Backgrounds

Use for:

- word-set selector shell
- layout selector shell

Recommended node type:

- decorative `TextureRect` behind a transparent or lightly styled `OptionButton`

Expected source:

- `asserts/layout_choose.png` or another dedicated dropdown image

#### E. Player Row Backgrounds

Use for:

- each player slot in the list

Recommended node type:

- `PanelContainer` with textured stylebox
- `TextureRect` inside each row root

### Binding Rules

1. Every decorative image node should have a descriptive name such as `MainPanelBg`, `WordSetDropdownBg`, or `StartButtonArt`.
2. Every interactive logic node should remain separately named, such as `WordSetOption`, `LayoutOption`, or `StartButton`.
3. If a decorative image and interactive control overlap, the image should be non-interactive and the real control should be on top.
4. Any atlas-cropped asset should be assigned through a dedicated subresource or documented texture slot so the user can replace the crop later.

## Proposed Node Map

The scene should roughly follow this node hierarchy:

- `GameSetting` (`Control`)
- `BackgroundLayer` (`TextureRect`)
- `ScreenMargin` (`MarginContainer`)
- `PanelCenter` (`CenterContainer`)
- `MainPanelRoot` (`Control`)
- `MainPanelBg` (`TextureRect` or `NinePatchRect`)
- `PanelContentMargin` (`MarginContainer`)
- `ContentColumns` (`HBoxContainer`)
- `LeftColumn` (`VBoxContainer`)
- `WordSetSection` (`Control` or `PanelContainer`)
- `WordSetSectionBg`
- `WordSetSectionContent`
- `WordSetDropdownShell`
- `WordSetDropdownBg`
- `WordSetOption`
- `WordSetPreview`
- `WordSetActions`
- `RefreshButton`
- `ImportButton`
- `LayoutSection`
- `LayoutSectionBg`
- `LayoutDropdownShell`
- `LayoutDropdownBg`
- `LayoutOption`
- `LayoutPreview`
- `RightColumn` (`VBoxContainer`)
- `PlayerCountSection`
- `PlayerCountSectionBg`
- `MinusButton`
- `PlayerCountValue`
- `PlusButton`
- `PlayerListSection`
- `PlayerListSectionBg`
- `PlayerListScroll`
- `PlayerList`
- `ActionSection`
- `ActionSectionBg`
- `StatusLabel`
- `BackButton`
- `StartButton`

This hierarchy is descriptive rather than absolute. The important part is preserving a one-to-one mapping between visual shells and logic controls.

## Script Integration

The current project already separates word-set selection and player setup logic into scripts. The new scene should preserve those responsibilities instead of rewriting gameplay state flow.

Recommended integration path:

1. keep the data flow currently handled by `word_source_panel.gd` and `player_setup_panel.gd`
2. either adapt those scripts to target the new single-page node paths, or move their logic into a thin parent controller for the upgraded `game_setting.tscn` scene
3. keep exported or onready references stable and explicit

Recommendation: create a dedicated controller script for the new settings scene and let it orchestrate:

- word-set loading and preview update
- layout selection update
- player count stepper update
- player row rendering
- start and back actions

This is cleaner than forcing two old panel scripts into one scene with overlapping ownership.

## Responsiveness

The panel should stay centered and readable on common desktop aspect ratios.

Rules:

1. Use outer margins so the panel never touches the screen edge.
2. Let the main panel scale within a safe max width rather than stretching endlessly.
3. Keep the left and right columns proportioned, with the right column slightly narrower than the left.
4. Let the player list become scrollable before the whole panel overflows vertically.

## Error and Empty States

The scene must visually support:

1. no word sets available
2. invalid or empty word set selected
3. player count at min or max
4. missing player names falling back to defaults

These states should use existing labels inside the panel, not modal popups.

## Implementation Notes

To make asset hookup easy, the first implementation should prefer placeholders over final art assumptions:

1. all background image nodes should exist even if they temporarily reuse the same source texture
2. buttons should work with either text-only or image-backed styles
3. dropdown shells should exist before final dropdown art is chosen
4. player rows should render with a clear placeholder background if final slot art is not yet assigned

This ensures the user can open the scene, attach real images, and immediately evaluate the result.

## Success Criteria

The work is successful when:

1. the project contains a usable single-page settings scene
2. word set, layout, and player count all appear inside one decorated main panel
3. the scene has explicit image attachment points for panel, dropdown, button, and player-row art
4. the user can replace placeholder textures with existing assets without restructuring the scene
5. the scene is visually coherent enough to preview the intended final style before all art is finalized
