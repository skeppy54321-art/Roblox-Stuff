# Brew a Potion — Project State

_Last updated: Sep 26, 2026_

## Status at a glance

| Item | Status |
|---|---|
| Milestone 1: prototype scripts | **Written, not yet run in Studio** |
| Syntax + Roblox API type check | **Passed** (luau-compile + luau-lsp with Roblox definitions) |
| Played in Studio | **Not yet** |
| Saving | **None.** Session-only. Progress resets on leave. |

Nothing below counts as "working" until it has been played in Studio.

## Confirmed working features (tested in Studio)

_None yet._

## Built, untested

* Market with 2 plots, built by code. Each player gets a free plot and is moved to it.
* 2 ingredient sources (Moonberry bush, Glowshroom patch). 3 charges each, regrow 1 every 3s. Charges show as visible berries/caps.
* Cauldron: 1 recipe (Giant Head Potion = 1 Moonberry + 1 Glowshroom). 6s brew. Bubbles + progress bar.
* Stir: press the cauldron while brewing to cut 0.75s (max 3 stirs).
* Customer at the counter. Sell = +10 coins, head inflates, new customer after ~6s.
* Upgrade: Faster Brewing (25 coins: 6s to 4s, 60 coins: 4s to 2.5s). Fire changes color per level.
* HUD: coins, inventory, goal banner that always says the next step, upgrades panel, toast messages, "PROTOTYPE" label.
* Other players' prompts are hidden on your screen. Server also rejects them.

## How to install (manual, until Studio is connected)

1. Studio > New > **Baseplate**.
2. Click **Workspace** > Properties > turn **StreamingEnabled off** (tiny map, avoids missing parts).
3. Create these, pasting each file's code:

| Explorer location | Type | Name | File |
|---|---|---|---|
| ReplicatedStorage | ModuleScript | Config | `src/ReplicatedStorage/Config.lua` |
| ReplicatedStorage | ModuleScript | Effects | `src/ReplicatedStorage/Effects.lua` |
| ServerScriptService | Script | Main | `src/ServerScriptService/Main.server.lua` |
| ServerScriptService | Folder | Modules | — |
| ServerScriptService > Modules | ModuleScript | Net | `Modules/Net.lua` |
| ServerScriptService > Modules | ModuleScript | PlayerData | `Modules/PlayerData.lua` |
| ServerScriptService > Modules | ModuleScript | Guard | `Modules/Guard.lua` |
| ServerScriptService > Modules | ModuleScript | ShopBuilder | `Modules/ShopBuilder.lua` |
| ServerScriptService > Modules | ModuleScript | PlotService | `Modules/PlotService.lua` |
| ServerScriptService > Modules | ModuleScript | IngredientService | `Modules/IngredientService.lua` |
| ServerScriptService > Modules | ModuleScript | BrewService | `Modules/BrewService.lua` |
| ServerScriptService > Modules | ModuleScript | CustomerService | `Modules/CustomerService.lua` |
| ServerScriptService > Modules | ModuleScript | UpgradeService | `Modules/UpgradeService.lua` |
| StarterPlayer > StarterPlayerScripts | LocalScript | ClientMain | `StarterPlayerScripts/ClientMain/init.client.lua` |
| **inside** ClientMain | ModuleScript | Hud | `StarterPlayerScripts/ClientMain/Hud.lua` |

Names must match exactly. `Remotes` and `Market` are created by code; don't make them.

(Rojo users: `default.project.json` maps everything.)

## Test checklist

1. **Play solo.** Output should say `[Brew a Potion] Server started`. You spawn in your shop, sign shows your name.
2. Collect a Moonberry, then a Glowshroom. Counts go up, berries/caps disappear then regrow.
3. Brew. Bar fills, bubbles speed up. Press again to stir, bar jumps.
4. Sell to the customer. +10 coins, head inflates, new customer arrives.
5. Repeat until 25 coins. UPGRADES badge appears. Buy. Fire turns blue, brew is faster.
6. **Time it:** first sale should be under 60–90s.
7. **Spam test:** mash E on the customer with 1 potion. Must sell only once.
8. **Test tab > Clients and Servers > 2 players.** Each gets their own plot. You can't use the other shop, and you can see the other player's customer effect.
9. **Test tab > Device** > pick a phone. Buttons readable and tappable, nothing hidden by the joystick or jump button.

Send me any red Output errors and what you did right before.

## Design decisions

* Everything built by code (no free models). Palette lives in `Config.Palette`.
* All numbers in `Config`. Server decides everything; client only asks and displays.
* Every action checks: owns plot, near enough, cooldown, has the items. State changes right after checks with no waiting in between, so double-presses can't duplicate.
* Effects run on clients only (`Effects` module), never touch coins.
* Customer effect is scaling a part group, cheap on phones.
* One `PlayerData` module holds all data. Milestone 3 swaps its insides to ProfileStore without changing other modules.
* While brewing, the player stirs or collects more ingredients.

## Verified API notes (checked Sep 26, 2026)

* **ProfileStore** official repo: `github.com/MadStudioRoblox/ProfileStore` (loleris), v1.0.3. Real API: `ProfileStore.New(name, template)`, `:StartSessionAsync(key, {Cancel = fn})`, `profile.Data`, `profile:Reconcile()`, `profile:AddUserId()`, `profile:EndSession()`, `profile.OnSessionEnd`, `ProfileStore.IsClosing`, `ProfileStore.Mock` for Studio testing. Default autosave: every 300s.
* **Prices:** use `MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Product / GamePass)` and read `PriceInRobux`. The old `GetProductInfo` is deprecated.
* **Developer products:** grant only through `ProcessReceipt` or the newer `BindReceiptHandler`. Key on `PurchaseId`, save the grant into the player's profile, return granted only after that. Never grant from `PromptProductPurchaseFinished`.
* **Game passes:** `UserOwnsGamePassAsync(userId, passId)`.

## Unresolved bugs / known gaps

* Ingredients used in a brew are lost if you leave mid-brew (fine for a prototype).
* No sounds yet (need real audio asset IDs).
* Ball-shaped bush size may be adjusted by Roblox to a uniform size. Visual only.

## Next steps

1. **You:** install, run the test checklist, send errors or "it works."
2. Then Milestone 2: split `Config` into modules, recipe selection UI, second effect.
3. Milestone 3: ProfileStore saves, autosave, shutdown handling, load-fail kick.
