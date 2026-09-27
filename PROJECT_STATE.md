# Brew a Potion — Project State

_Last updated: Sep 27, 2026_

This file is the source of truth for the project (the old chats weren't reachable from the coding session, so everything they decided lives here).

## Status at a glance

| Item | Status |
|---|---|
| Milestone 1: prototype loop | Written. **Not yet played in Studio** |
| Milestone 2: recipes, cauldron menu, effects | Written. **Not yet played in Studio** |
| Milestone 3: saving (ProfileStore) | Written. **Not yet played in Studio** |
| Cozy magic market look | Written. **Not yet played in Studio** |
| Static checks | **Pass**: luau-lsp strict with Roblox API types, selene, StyLua, script-security scan against the API dump |
| Place file | `build/BrewAPotion.rbxlx` (built by Rojo from `src/`) |
| Saving | ProfileStore. Real saves only in a published place with API access on (see below) |

Nothing below counts as "working" until it has been played in Studio.

## Play it (fastest way)

1. Download `build/BrewAPotion.rbxlx` from this branch on GitHub (open the file, then **Download raw file**).
2. Roblox Studio > **File > Open from File** > pick it.
3. Press **Play**. Output should say `[Brew a Potion] Server started`.

The place file already has **StreamingEnabled off** and **Lighting > Technology = Future** (scripts can't set those two).

**Saving in Studio:** progress only saves if the place is published (**File > Publish to Roblox**) and **Game Settings > Security > Enable Studio Access to API Services** is on. Otherwise Output says `[ProfileStore]: Roblox API services unavailable - data will not be saved` and the HUD shows an orange "Test mode: progress is not saved here" chip. That's expected.

**Players per server:** there are 6 shops. When you publish, set the place's max players (server size) to **6** so everyone gets a shop.

### Other ways to install

* **Rojo:** `rojo serve` (or `rojo build default.project.json -o BrewAPotion.rbxlx`). `default.project.json` maps everything.
* **By hand** (not recommended, 40+ scripts): start from a Baseplate, turn Workspace > StreamingEnabled off, set Lighting > Technology to Future, then recreate the tree below, pasting each file. A folder with `init.lua` becomes a ModuleScript of that name, and the other files go inside it.

```
ReplicatedStorage
  Config (ModuleScript = Config/init.lua)  children: Tuning, Ingredients, Recipes, Upgrades, Palette, Sounds, World
  Effects (ModuleScript = Effects/init.lua) children: BigHead, Rainbow, Tiny, Floaty, Twirl, Frosty, Froggy
ServerScriptService
  Main (Script)
  Modules (Folder): Net, PlayerData, ProfileStore, Guard, Kit, ShopBuilder, CustomerBuilder, MarketBuilder,
                    WorldService, PlotService, IngredientService, BrewService, CustomerService, UpgradeService
StarterPlayer > StarterPlayerScripts
  ClientMain (LocalScript = ClientMain/init.client.lua)
    children: Ui, Sfx, Hud, UpgradesPanel, RecipeBook, CauldronMenu, CauldronFx, PromptUi, Popups,
              GoalMarker, CustomerAnimator, Ambience
```
`Remotes`, `Market` and `PlotStash` are created by code; don't make them.

## What's in the game (built, untested)

**World** (all built by code, no free models)
* 6 shops in a ring around a cobblestone plaza. Each shop has its own awning color, a sign with the owner's name, a timber back wall with a tiled roof, bottle shelves, lanterns, barrels and a rug.
* Plaza: tiered marble fountain topped by a giant glowing potion that slowly cycles through every potion color, lamp posts joined by string lights, benches you can sit on, a "Potion Market" sign, fireflies.
* Around it: trees between the shops, a forest ring, rolling hills on the horizon.
* Golden-hour lighting: low warm sun, haze, sunset clouds, bloom on neon, gentle color grading. Fires and lanterns flicker.

**Loop**
* Collect ingredients from your plants (charges regrow). 4 ingredients: Moonberry, Glowshroom (start), Starflower, Frost Crystal (unlock by buying their plots).
* Brew at your cauldron. Standing at it opens the **cauldron menu**: every unlocked potion, what you're missing, which one a customer wants. Tap a card (or press 1-9), or press the cauldron to brew the suggested potion. Press again while brewing to stir (faster). The liquid turns the potion's color.
* First time you brew a recipe: "NEW RECIPE!" celebration plus a bonus of its sell price.
* Customers walk from the plaza to your counter and ask for one specific potion (the first one always asks for a Giant Head Potion). Sell it: coins, a funny effect everyone can see, they walk away, the next one comes. About 12% of customers after your 5th sale are **VIPs** (gold crown) who pay double.

**7 potions and their effects**

| Potion | Ingredients | Coins | Brew | Effect |
|---|---|---|---|---|
| Giant Head | Moonberry + Glowshroom | 10 | 6s | Head inflates like a balloon |
| Rainbow | 2 Moonberry | 12 | 6s | Glowing rainbow waves, keeps the stripes |
| Tiny | 2 Glowshroom | 12 | 6s | Poof, shrinks to pocket size, hops |
| Floaty | Starflower + Glowshroom | 24 | 7.2s | Floats up 7 studs with sparkles |
| Twirly | Starflower + Moonberry | 24 | 7.2s | Spins like a top |
| Frosty | Frost Crystal + Glowshroom | 45 | 9s | Frozen in an ice block that cracks |
| Froggy | Frost Crystal + Moonberry + Starflower | 70 | 10.8s | Turns into a frog and hops away |

Brew times shown at Faster Brewing level 0; all numbers live in `Config`.

**Upgrades** (Upgrades panel, or the "for sale" signs in your shop)

| Upgrade | Levels (cost) | What changes |
|---|---|---|
| Faster Brewing | 25 / 90 / 300 | Brew 6s → 4.5s → 3.5s → 2.5s; fire turns blue / purple / green |
| Starflower Bed | 60 | Plants Starflowers; unlocks Floaty + Twirly |
| Bigger Shelves | 80 / 250 | Hold 5 → 8 → 12 potions; more bottles on the wall |
| Green Thumb | 120 / 350 | 3 → 4 → 5 per plant, regrow 3s → 2.4s → 1.8s |
| Second Counter Spot | 200 | Two customers at once |
| Frost Grotto | 400 (needs Starflower Bed) | Grows Frost Crystals; unlocks Frosty + Froggy |
| Cozy Decor | 150 / 500 / 1500 | String lights + flower boxes → banners + glowing sign → golden cauldron, star and sparkles |

**UI** (scales for phones; see `design/`)
* Coins (count up and bounce), goal banner that always says the next step, basket with ingredients and potions, Upgrades / Recipes / Sound buttons with badges, toasts, a big celebration banner, floating "+1" / "+coins" popups.
* Custom styled prompts (tap them on mobile). If that module ever fails, prompts fall back to Roblox's default ones.
* Bouncing gold arrow over the next thing to do, for your first 8 sales.
* Keys: U upgrades, R recipes, M mute, 1-9 brew, Esc close.

**Saving** (Milestone 3)
* ProfileStore: session locking (no duping across servers), autosave, final save on leave and on shutdown.
* Versioned data (`SchemaVersion`), a migration step per version, and every loaded value is sanity-checked (unknown ids dropped, negatives and NaN fixed).
* Can't load → you're kicked with a friendly "please rejoin" (so nobody plays unsaved). Loaded on another server → kicked from the old one.
* Leaving mid-brew keeps the potion (it finishes instantly) instead of losing the ingredients.

## Test checklist

1. **Play solo.** Output: `[Brew a Potion] Server started` and a ProfileStore line. You appear in your shop facing the counter; the sign shows your name.
2. The goal banner and gold arrow point at the purple bush. Collect a Moonberry, then a Glowshroom: "+1" popups, counts go up in the basket, berries/caps disappear and regrow.
3. Stand at the cauldron: the menu pops up at the bottom. Tap Giant Head (or press E). The liquid turns pink, the bar fills. Press E again to stir: the bar jumps, bubbles splash.
4. "NEW RECIPE!" banner and +10 bonus coins. The first customer walks in from the plaza asking for a Giant Head Potion.
5. Sell: +10 coins popup, their head inflates, they shout "My head!!", then walk away. A new customer walks in.
6. Reach 25 coins: the UPGRADES badge appears. Buy Faster Brewing: the fire turns blue and the celebration banner shows.
7. Buy the Starflower Bed from its "for sale" sign in your shop: the sign disappears and starflowers appear. Floaty and Twirly show up in the menu.
8. **Timing:** first sale should come within 60–90 seconds.
9. **Spam test:** mash E on a customer with 1 potion. It must sell only once.
10. **Test tab > Clients and Servers > 2 players.** Each gets their own shop. You can't use the other shop's prompts, but you can see their customers walk and react.
11. **Test tab > Device > a phone.** Everything readable and tappable; the cauldron menu and buttons don't sit under the joystick or jump button. Tap a prompt to use it.
12. **Saving** (published place + API access on): earn coins, stop, play again. Coins, potions, upgrades and discovered recipes come back.
13. **Leave mid-brew**, rejoin: you have the potion.

Send any red Output errors and what you did right before. Yellow `[Effects] ... errored` or `[ClientMain] custom prompts disabled` warnings are worth sending too.

## Design decisions

* Everything built by code (no free models). Colors live in `Config.Palette`, all numbers in `Config`.
* The server decides everything; the client only asks and displays. Every action checks: owns the plot, near enough, cooldown, valid id, has the items. State changes right after the checks with no yields in between, so double presses can't duplicate.
* Shared rules (what's unlocked, costs, brew times, capacity) are functions in `Config`, so the server and the UI can never disagree.
* Customers walk on the clients only: the server sets `Phase` / `PhaseStart` / `PhaseEnd` / `WalkFrom` attributes and keeps the customer at the counter. Smooth, and it costs no network.
* Effects run on clients only (`Effects` module), never touch coins, and a broken effect only prints a warning.
* Locked plants and not-yet-bought decor are built once and parked in `ServerStorage.PlotStash`; buying moves them into the shop.
* One `PlayerData` module holds all data; nothing else touches ProfileStore.
* Sounds: the only asset ids used are ones Roblox's own tutorials use (so they're public and free): a chime (potion ready, sales), a jingle (upgrades), a celebration sting (new recipe) and an upbeat music loop. Every other slot in `Config/Sounds.lua` has search words for the Toolbox and falls back to a built-in client sound or stays silent. The client preloads the ids and switches any that fail to load to the built-in sound. Long sounds fade out after `MaxSeconds`, and music ducks under fanfares.

## Economy (first pass, tune after playtesting)

* **Sources:** potion sales (10–70 coins, VIPs x2), first-brew bonuses (one per recipe, 197 total).
* **Sinks:** 7 upgrade tracks, 4,025 coins to max everything.
* **Pace estimate:** customers are the bottleneck (about 6 sales a minute per counter spot). Early game about 50–70 coins/min, so the first upgrade comes after 2–3 sales and the Starflower Bed at about 2 minutes. After the Frost Grotto, about 200+ coins/min. Maxing everything takes roughly 25–35 minutes.
* **Watch for:** the content wall after ~30 minutes (needs new ingredients/recipes/decor), and whether Faster Brewing matters while customers are the bottleneck.

## Verified API notes (checked Sep 26–27, 2026)

* **ProfileStore** (github.com/MadStudioRoblox/ProfileStore, Apache-2.0, vendored unmodified): `ProfileStore.New(name, template)`, `:StartSessionAsync(key, {Cancel = fn})`, `profile.Data`, `:Reconcile()`, `:AddUserId()`, `:EndSession()`, `OnSessionEnd`, `IsClosing`, `DataStoreState`, `.Mock`. In Studio it test-writes a key; on "403" or "must publish" it switches to mock mode by itself. It handles `BindToClose` itself.
* **Lighting.Technology** is RobloxScriptSecurity and **Workspace.StreamingEnabled** is PluginSecurity for writing: scripts can't set them, so the place file does.
* Custom prompts: `ProximityPrompt.Style = Custom` + `ProximityPromptService.PromptShown/PromptHidden`; touch/click calls `prompt:InputHoldBegin()` / `InputHoldEnd()`.
* Client sounds that ship with every client (current manifest): `rbxasset://sounds/` `volume_slider.ogg`, `impact_water.mp3`, `action_jump.mp3`, `impact_explosion_03.mp3` (plus a few footstep sounds). The old ones (`button.wav`, `electronicpingshort.wav`, ...) are gone.
* Audio ids from Roblox's tutorials (github.com/Roblox/creator-docs): `4110925712` "simple chime" (In-game sounds), `3422389728` "retro jingle" and `1841461968` "upbeat" looping music (Add 2D audio), `1846248593` "cheerful, celebratory" (Add 3D audio). Not listened to from here: swap any you don't like.
* `ContentProvider:PreloadAsync(ids, callback(contentId, Enum.AssetFetchStatus))` accepts id strings; anything but `Success` means the asset didn't load.
* **Prices:** `MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Product / GamePass)`, read `PriceInRobux`. The old `GetProductInfo` is deprecated.
* **Developer products:** grant only through `ProcessReceipt` (or `BindReceiptHandler`), key on `PurchaseId`, save the grant in the profile, return granted only after that. Never grant from `PromptProductPurchaseFinished`.
* **Game passes:** `UserOwnsGamePassAsync(userId, passId)`.

## Unresolved bugs / known gaps

* **Never played in Studio.** Expect a first round of small fixes (sizes, positions, colors, UI spacing).
* Only 4 real audio ids so far (chime, jingle, celebration, music), picked from Roblox's tutorials without hearing them. Effect sounds (ribbit, freeze, whoosh, inflate, shrink) and bubbling are still empty: pick audio in the Toolbox and paste the ids into `Config/Sounds.lua`.
* Lighting and colors were chosen without seeing them rendered; tweak `Config/World.lua` and `Config/Palette.lua` to taste.
* If Roblox ever changes a ball part's size when its shape is set, bushes and bottles may look slightly different (visual only).
* More than 6 players in one server: extra players get "The market is full" (set server size to 6).

## Next steps

1. **You:** open `build/BrewAPotion.rbxlx`, run the test checklist, send errors or "it works" (screenshots help a lot for the look).
2. Fix what the playtest finds; tune lighting, colors and economy numbers.
3. Listen to the 4 chosen sounds and the music; fill the empty effect sound slots from the Toolbox (`Config/Sounds.lua`).
4. Content after ~30 min: more ingredients and recipes, more decor, maybe a daily reward.
5. Later: monetization (see the API notes above), leaderboards, trading between friends.
