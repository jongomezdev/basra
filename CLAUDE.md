# Basra

A Lebanese Basra card game in Godot 4.7 (GDScript): one human against an AI,
first to 101. Live at https://jongomez.dev/basra/ (GitHub Pages, `gh-pages`
branch). Repo: github.com/jongomezdev/basra, GPL-3.0.

## Rules as played here

These are the owner's corrections, so they override any rules found online:

- **Basra** is any capture that clears the whole table, by matching, adding up,
  or both. A jack sweep is never a Basra.
- **Jacks** are the only sweepers. The 7 of diamonds is an ordinary 7.
- **Adding up:** a number card takes groups of table cards summing to its value
  (ace = 1). It also takes same-rank matches, and takes every group it can,
  choosing the combination with the most cards. Queens and kings only match
  rank.
- **Opening table:** a jack is never left on it. The first is put at the bottom
  of the deck, a second in the middle, any more at random in the lower half,
  and each is replaced from the top.
- **Deal:** 4 to the table, 6 to each player, then 6 more each with no new
  table cards until the deck runs out.
- **Scoring:** 10 of diamonds 3, 2 of clubs 2, each ace 1, each jack 1, most
  cards 3 (nobody on a tie), each Basra 10.
- **End of round:** the last player to capture takes the leftover cards (no
  Basra for that). The match ends only at the end of a round: if someone has
  101 or more, the higher score wins, and an exact tie plays another round.

## Code layout

- `scripts/core/`: no UI. `card.gd`, `basra_rules.gd` (capture, Basra and
  scoring), `basra_game.gd` (match state; `play_card()` returns a result
  dictionary that the UI animates), `basra_ai.gd`, and
  `achievement_tracker.gd`. Core scripts are `@tool` so editor tests can run
  them.
- `scripts/ui/`: `main.gd` (the game screen: animations, layout, scoring
  reveal, felt palettes, achievement reporting), `card_view.gd` (cards drawn in
  code, including the back designs), `pixel_glyphs.gd` (hand-drawn rank
  letters), `pause_menu.gd`, `achievement_toast.gd`, `rotate_prompt.gd`,
  `sfx.gd` (sounds synthesised at startup).
- `scenes/main.tscn`, `theme/basra_theme.tres`, `shaders/` (marbled felt, card
  tilt), `assets/fonts/` (Pixelify Sans, OFL).
- `tests/test_*.gd`: rules, game and achievement suites (`McpTestSuite`).
- `tools/deploy_web.sh` publishes the web build. `tools/ui_smoke_test.gd` is
  the headless UI test.
- `addons/godot_ai/`: the Godot AI editor plugin (MCP). It is excluded from
  exports, along with `tests/` and `tools/`.

### Adding things

- **Achievement:** add an entry to `ACHIEVEMENTS` in `achievement_tracker.gd`,
  check for it in the matching `on_*` method, and add a test in
  `tests/test_achievements.gd`. The pause menu lists it automatically.
- **Card back:** add a style to `BACK_STYLES` in `card_view.gd` and an entry
  to `CARD_BACKS` in the tracker, in the same position in both lists. The
  `unlock` value is an achievement id.
- **Table palette:** add an entry to `FELT_PALETTES` in `main.gd` (dark, mid,
  light colors).

## Testing

Work in this order, and don't skip the headless run:

1. **Rules tests:** run the Godot AI MCP `test_run` tool (all suites). Rescan
   first with `filesystem_manage` op `scan` after adding or renaming any
   `class_name` script, or the new class won't be found.
2. **Headless UI test** (always before launching from the editor):
   ```bash
   perl -e 'alarm 200; exec @ARGV' /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/ui_smoke_test.gd
   ```
   It should print 20 PASS lines and `FAILURES 0`, and exit with 0. A script
   error in the game makes the editor's `project_run` hang until the MCP times
   out (30 minutes), so catch errors here first, under the time limit.
3. **In the running game:** use `project_run`, then `game_eval` and
   `editor_screenshot` (source `game`). `game_eval` can call into the scene,
   for example `get_tree().current_scene._pause_menu.open()`.
4. **Web:** export to `build/web` and serve it with the `web-build` entry in
   `.claude/launch.json` (port 8060), then check it in the browser pane.

## Publishing

```bash
tools/deploy_web.sh
```

This exports the Web preset (single-threaded, so no special server headers are
needed) and force-pushes the build as a single commit to `gh-pages`. Pages
rebuilds in about a minute. Then load https://jongomez.dev/basra/ to confirm.
The account has a custom domain, so `jongomezdev.github.io/basra/` redirects
there. The Web export templates for Godot 4.7.2 are installed. The `gh` CLI is
logged in as jongomezdev.

## Gotchas

- **Font sizes must be multiples of 11** (22, 33, 44, 55, 88). Pixelify Sans
  only lands on the pixel grid at those sizes, and other sizes blur or distort.
  Font ligatures are off because the "fi" ligature read as "A". Card ranks use
  `pixel_glyphs.gd`, not the font.
- **Edit open scenes through Godot.** If `scenes/main.tscn` is open in the
  editor and its file changes on disk, Godot asks whether to reload, and
  "Ignore" would later overwrite the change. Use the MCP node and scene tools,
  or tell the user to choose "Reload from disk".
- **Protect the real progress file.** `user://progress.cfg` holds the player's
  real achievements. Test harnesses must set `main.progress_path` to another
  file before adding the scene to the tree, as `ui_smoke_test.gd` does.
  Running the game from the editor writes the real file.
- **Timers must pause:** use `get_tree().create_timer(t, false)`. The default
  keeps running while the game is paused.
- **A new match mid-animation** waits for a safe point (`_restart_pending`) so
  that old coroutines never touch the new match.

## Working with the owner

- The owner usually tests changes before committing. After a change, ask
  whether to commit, and don't commit or push until they say so. They usually
  want "commit and publish" together for game changes.
- Report what was verified and what wasn't, such as audio or a real phone.
- Commit messages end with the co-author line the session's instructions give.
