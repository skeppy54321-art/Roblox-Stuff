# Tests

These run the game's **real scripts** outside Roblox, using [Lune](https://github.com/lune-org/lune)
(a standalone Luau runtime that can load Roblox place files). A small fake engine (`engine.luau`)
supplies what Lune doesn't have: events, remotes, tweens, pivots, mock DataStores, a player and
a character. It is not Roblox, so passing here doesn't replace a Studio playtest, but it catches
runtime errors and broken game logic before you ever open Studio.

## Run

```sh
rojo build default.project.json -o build/BrewAPotion.rbxlx   # always test the current code
mkdir -p out
lune run tests/server_test.luau build/BrewAPotion.rbxlx out   # server: ~170 checks, ~70s
lune run tests/client_test.luau build/BrewAPotion.rbxlx       # server + client "play solo": ~110 checks
```

Both print `ok` / `FAIL` per check and exit non-zero on any failure, error or warning.

**Server test** boots `ServerScriptService.Main`, then a scripted player joins and: collects,
brews, stirs, discovers a recipe, sells to the first customer (double press sells once), tries
junk remote arguments, buys every upgrade (from the panel remote and the in-shop "for sale"
sign), then a second player joins: leaderstats, cheering (own shop, too far, once per visit),
market news, the Market Stars board. Then it brews a specific recipe, leaves mid-brew (keeps
the potion), and rejoins to check the save round-trip through ProfileStore's mock store.

**Client test** runs the server and the real `ClientMain` LocalScript together on a phone-sized
screen: HUD, scaling, sounds (preload, broken-asset fallback, music ducking), goal banner +
arrow, custom prompts (cheer prompt only on other players' shops), popups, the cauldron menu
(tapping a card brews), celebrations, social toasts, keyboard shortcuts, buying from the
Upgrades panel, and all twelve potion effects on real customer models (drinking first).

## Pacing bot

```sh
lune run tests/pacing_bot.luau build/BrewAPotion.rbxlx 12   # plays for 12 real minutes
```

A bot plays through the real server scripts like a quick, focused player: it walks at
Roblox's default speed, pauses between actions, stirs every brew, sells across the counter
and buys whatever the goal banner suggests. It prints a timeline (first sale, every upgrade)
and the coins earned each minute. Run it after changing numbers in `Config` to see how the
pacing moved. (It found a softlock: a full shelf of the wrong potions froze the shop.)

## 3D preview of the world

`server_test.luau` writes `out/parts.json` (the world after boot) and `out/parts_upgraded.json`
(the owner's shop with everything bought and two customers). To look at them:

```sh
cp out/*.json tests/preview/
cd tests/preview && npm install
node shoot.mjs shots overview plaza fountain front:parts_upgraded.json inside customer:parts_upgraded.json
```

Views are defined at the top of `render.html`. It's an approximation (no Roblox materials,
text or real lighting) that is good for checking layout, sizes and colors.

## HUD and board previews

`ui_snapshots.luau` dumps the HUD at a few moments, and `server_test.luau` dumps the Market
Stars board (`out/ui_board.json`), the Hall of Fame (`out/ui_fame.json`) and a big-order
speech bubble (`out/ui_bubble_big.json`). `ui.html` draws those trees with Roblox-like layout rules:

```sh
lune run tests/ui_snapshots.luau build/BrewAPotion.rbxlx out 844 390 phone
cp out/ui_*.json tests/preview/
cd tests/preview && node shoot-ui.mjs shots - ui_phone_start.json ui_board.json
```

## Differences from Roblox worth knowing

* Lune's `CFrame.lookAt` points away from the target; `engine.luau` swaps in Roblox's behavior.
* Lune doesn't derive `Position` from `CFrame`; the engine keeps them in sync on a timer.
* Tweens jump to their end value after the tween time.
