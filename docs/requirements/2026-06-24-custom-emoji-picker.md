# Custom Emoji Picker Design

## Background

The timer editor previously used the macOS Character Viewer through `NSApp.orderFrontCharacterPalette(_)`. That system panel sends the selected character to the current first responder. In the timer editor this caused selected emoji to be inserted into the title field when the title text field had focus.

The app now uses an in-app SwiftUI popover for timer emoji selection. This keeps focus and selection behavior inside the editor and avoids depending on global input-panel behavior.

## Goals

- Replace the system Character Viewer for timer emoji selection.
- Select an emoji with one click and immediately update `TimerItem.emoji`.
- Support search by Unicode English name and a small Chinese keyword layer for reminder scenarios.
- Persist recently used emoji for faster repeated selection.
- Keep code and bundled data small enough for a menu bar utility.

## Non-Goals

- Provide a complete Unicode emoji browser in the first version.
- Maintain full alias, localization, skin tone, or variant metadata.
- Add a third-party picker dependency.

## Implementation

### Data Model

`EmojiCatalogItem` stores:

- `symbol`: the rendered emoji character.
- `unicodeName`: the English Unicode-style name used for lightweight search.
- `group`: a local category used by the picker tabs.
- `keywords`: small Chinese keyword coverage for reminder-centric searches.

`EmojiCatalog` currently uses an embedded Swift catalog. The structure intentionally matches a future generated catalog so it can later be replaced by data generated from Unicode `emoji-test.txt` or another source.

### Picker UI

`EmojiPickerPopover` is presented from `NotificationContentEditor` when the emoji button is clicked. It contains:

- a selected emoji preview,
- a search field,
- a recent emoji row,
- a category selector,
- a fixed-size grid of emoji buttons.

Selecting an emoji calls the editor callback, updates `timer.emoji`, records the emoji as recent, and closes the popover.

### Recent Emoji Persistence

`AppSettings.recentEmojis` stores recently selected emoji in `UserDefaults` under `recentEmojis`.

`EmojiSelection.recentEmojis(afterSelecting:existing:limit:)` handles:

- moving the selected emoji to the front,
- de-duplicating entries,
- limiting the stored list to 20 values.

## Size and Maintenance

The current catalog is intentionally medium-small: it covers common reminder scenarios such as hydration, medicine, work, rest, exercise, commute, and household tasks. This avoids a large JSON bundle while still improving the Chinese search experience.

Future expansion should prefer one of these paths:

1. Add a few targeted `EmojiCatalogItem` entries when users report missing reminder scenarios.
2. Generate a larger static catalog from Unicode `emoji-test.txt`, keeping only `symbol`, `unicodeName`, and `group`.
3. Add a separate Chinese keyword overlay only for app-specific terms instead of trying to localize all emoji names.

## Verification

Current automated coverage:

- `EmojiCatalogTests`: Chinese keyword search, English name search, and blank recommended results.
- `EmojiSelectionTests`: first composed character extraction, whitespace rejection, and recent emoji ordering.

Manual behavior to check when editing the picker:

- Clicking the emoji button should not focus or modify the title field.
- Selecting an emoji should update only the icon.
- The selected emoji should appear at the front of recent items after reopening the picker.
