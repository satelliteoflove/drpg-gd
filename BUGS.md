# Known Bugs

(No known bugs at this time)

---

# Fixed Bugs

## Back Row Doesn't Advance When Front Row Dies (FIXED)

**Fix:** Added `advance_back_row_if_front_wiped()` method to `resources/party.gd` that swaps rows when the entire front row is dead. Called from `combat_system.gd` after party member deaths. Also added enemy row advancement via `_check_enemy_row_advance()`.

**Behavior:**
- Rows advance as a complete unit, never individual characters
- When the ENTIRE front row is dead, the back row becomes the new front row (all at once)
- Same logic applies to enemy ranks

---

## Formation Management - Enter Key Not Working Properly (FIXED)

**Fix:** Set `focus_mode = Control.FOCUS_NONE` on formation slot buttons in `scenes/common/party_menu.gd` so they don't intercept keyboard input. All keyboard navigation is now handled through `_handle_formation_input()`. Added visual highlighting: yellow for current selection, green for selected-for-swap.

**Behavior:**
1. Navigate with arrow keys (current slot shown in yellow)
2. Press Enter to select a character (selected slot shown in green)
3. Navigate to target position
4. Press Enter to confirm swap
