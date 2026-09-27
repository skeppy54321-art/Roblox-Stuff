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
| Sounds + music | 4 real audio ids from Roblox's tutorials, built-in fallbacks. **Not yet heard** |
| Social: leaderstats, market news, cheers, Market Stars board | Written. **Not yet played in Studio** |
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
  Effects (ModuleScript = Effects/init.lua) children: BigHead, Rainbow, Tiny, Floaty, Twirl, Frosty, Froggy,
                                            FireBreath, Dance, Bubble, Ghost, Rocket
ServerScriptService
  Main (Script)
  Modules (Folder): Net, PlayerData, ProfileStore, Guard, Kit, ShopBuilder, CustomerBuilder, MarketBuilder,
                    WorldService, PlotService, IngredientService, BrewService, CustomerService, UpgradeService,
                    SocialService, GiftService, FameService, BoardKit
StarterPlayer > StarterPlayerScripts
  ClientMain (LocalScript = ClientMain/init.client.lua)
    children: Ui, Sfx, Hud, UpgradesPanel, RecipeBook, CauldronMenu, CauldronFx, PromptUi, Popups,
              GoalMarker, CustomerAnimator, Ambience, Townsfolk, Familiars
```
`Remotes`, `Market` and `PlotStash` are created by code; don't make them.

## What's in the game (built, untested)

**World** (all built by code, no free models)
* 6 shops in a ring around a cobblestone plaza. Each shop has its own awning color, a sign with the owner's name, a timber back wall with a tiled roof, bottle shelves, lanterns, barrels and a rug.
* Plaza: tiered marble fountain topped by a giant glowing potion that slowly cycles through every potion color, lamp posts joined by string lights, benches you can sit on, a "Potion Market" sign, the Market Stars board, fireflies.
* Six townsfolk stroll around the fountain, stop to admire it and window-shop at the stalls (players' shops first), sometimes saying something nice. The server builds them once; every client walks its own copy (no network cost).
* Around it: trees between the shops, a forest ring, rolling hills on the horizon.
* Golden-hour lighting: low warm sun, haze, sunset clouds, bloom on neon, gentle color grading. Fires and lanterns flicker.

**Loop**
* Collect ingredients from your plants (charges regrow). 6 ingredients: Moonberry, Glowshroom (start), Starflower, Frost Crystal, Ember Pepper, Cloud Puff (unlock by buying their plots).
* Brew at your cauldron. Standing at it opens the **cauldron menu**: every unlocked potion, what you're missing, which one a customer wants. Tap a card (or press 1-9), or press the cauldron to brew the suggested potion. Press again while brewing to stir (faster). The liquid turns the potion's color.
* When a potion is done, a bottle of it pops out of the cauldron with a sparkle, and your potions stand on the counter as glowing bottles (everyone can see your stock).
* First time you brew a recipe: "NEW RECIPE!" celebration plus a bonus of its sell price. Brew all 12 and you become a **Master Brewer**: a celebration, market news, "Master Brewer" under your name on the shop sign, and a gold name on the Market Stars board.
* Customers walk from the plaza to your counter and ask for one specific potion (the first one always asks for a Giant Head Potion). They wait up to 45 seconds; if your shelf is full and their potion isn't on it, they give up after a few seconds ("Oh, you're all out!") and the next customer asks for something you have, so the shop can never get stuck. Sell it: coins, they lift the bottle and drink it, a funny effect everyone can see, they walk away, the next one comes. About 12% of customers after your 5th sale are **VIPs** (gold crown) who pay double.

**12 potions and their effects** (every customer drinks the potion first)

| Potion | Ingredients | Coins | Brew | Effect |
|---|---|---|---|---|
| Giant Head | Moonberry + Glowshroom | 10 | 6s | Head inflates like a balloon |
| Rainbow | 2 Moonberry | 12 | 6s | Glowing rainbow waves, keeps the stripes |
| Tiny | 2 Glowshroom | 12 | 6s | Poof, shrinks to pocket size, hops |
| Floaty | Starflower + Glowshroom | 24 | 7.2s | Floats up 7 studs with sparkles |
| Twirly | Starflower + Moonberry | 24 | 7.2s | Spins like a top |
| Frosty | Frost Crystal + Glowshroom | 45 | 9s | Frozen in an ice block that cracks |
| Froggy | Frost Crystal + Moonberry + Starflower | 70 | 10.8s | Turns into a frog and hops away |
| Fire Breath | Ember Pepper + Glowshroom | 90 | 9.6s | Face goes red, steam from the ears, breathes a jet of fire |
| Dance | Ember Pepper + Starflower + Moonberry | 110 | 10.8s | A disco ball drops in; they bounce, twist and point at the sky |
| Bubble | Cloud Puff + Moonberry | 120 | 10.8s | Floats up inside a giant soap bubble until it pops |
| Ghost | Cloud Puff + Frost Crystal | 150 | 12s | Turns see-through, floats and drifts with wisps, then solid again |
| Rocket | Ember Pepper + Cloud Puff + Starflower | 220 | 14.4s | Rumbles, blasts off on a jet of fire, fireworks, parachutes down |

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
| Ember Garden | 900 (needs Frost Grotto) | Grows Ember Peppers (back left corner); unlocks Fire Breath + Dance |
| Cloud Garden | 2500 (needs Ember Garden) | Grows Cloud Puffs (back right corner); unlocks Bubble, Ghost + Rocket |
| Cozy Decor | 150 / 500 / 1500 | String lights + flower boxes → banners + glowing sign → golden cauldron, star and sparkles |
| Magic Familiar | 1500 / 5000 / 15000 | A pet that floats behind you, visible to everyone: Shop Cat → Wise Owl (flapping wings) → Baby Dragon (puffs fire) |

**UI** (scales for phones; see `design/`)
* Coins (count up and bounce), goal banner that always says the next step, basket with ingredients and potions, Upgrades / Recipes / Sound buttons with badges, toasts, a big celebration banner, floating "+1" / "+coins" popups.
* Custom styled prompts (tap them on mobile). If that module ever fails, prompts fall back to Roblox's default ones.
* Bouncing gold arrow over the next thing to do, for your first 8 sales.
* Keys: U upgrades, R recipes, M mute, 1-9 brew, Esc close.

**Social** (see `design/features/social.md`)
* Player list shows everyone's **Coins** and **Sold**.
* **Market news:** when someone discovers a recipe or buys a big upgrade (Starflower Bed, Second Counter Spot, Frost Grotto), everyone else gets a violet toast.
* **Cheer stand:** a pink heart at the front of every shop. At someone else's shop, press it to cheer: hearts burst out for everyone, the owner gets a pink toast, and the shop's cheer count goes up (saved). One cheer per shop per visit. No coins involved.
* **Market Stars board** in the plaza (across from the welcome sign): everyone in the server ranked by coins earned, with recipes found and cheers.
* **Hall of Fame board** (another spot on the plaza): the top 10 brewers of all time across every server, by coins earned (an OrderedDataStore, saved when you leave and every 3 minutes, read every minute). In an unpublished place it just says it fills up once the game is published.

The goal banner suggests upgrades along a set path (`Config.Tuning.UpgradePath`): new potions early, boosts after, and it saves up for the next step instead of spending on whatever is cheapest. Cozy Decor and Magic Familiar are cosmetic, suggested only when nothing useful is left.

**Rebirth**
* Once you've grown the Cloud Garden and have 5,000 coins (+5,000 more each time), the Rebirth card at the top of the Upgrades panel starts your shop over: coins, ingredients, potions and the useful upgrades reset; your familiar, Cozy Decor, recipes and stats stay. Every rebirth adds +25% coins to every sale for good (x1.25, x1.5, ...), shown under your coins and as "Rebirth N" on your sign. Tap twice to confirm. The goal banner suggests it once there's nothing useful left to buy.

**Daily gift**
* A GIFT button (top of the right-hand column) with a badge when it's ready: once every 20 hours, 30 / 50 / 80 / 120 / 160 / 220 / 300 coins for day 1–7 of a streak (later days repeat 300). Come back within 48 hours to keep the streak. The server's clock decides; the button counts down to the next one.

**Saving** (Milestone 3)
* ProfileStore: session locking (no duping across servers), autosave, final save on leave and on shutdown.
* Versioned data (`SchemaVersion`, now 3: v2 added the daily gift, v3 rebirths), a migration step per version, and every loaded value is sanity-checked (unknown ids dropped, negatives and NaN fixed).
* Can't load → you're kicked with a friendly "please rejoin" (so nobody plays unsaved). Loaded on another server → kicked from the old one.
* Leaving mid-brew keeps the potion (it finishes instantly) instead of losing the ingredients.

## Test checklist

1. **Play solo.** Output: `[Brew a Potion] Server started` and a ProfileStore line. You appear in your shop facing the purple Moonberry bush (after your first sale you'll face the counter instead), and the camera is behind you; the sign shows your name.
2. The goal banner and gold arrow point at the purple bush. Collect a Moonberry, then a Glowshroom: "+1" popups, counts go up in the basket, berries/caps disappear and regrow.
3. Stand at the cauldron: the menu pops up at the bottom. Tap Giant Head (or press E). The liquid turns pink, the bar fills. Press E again to stir: the bar jumps, bubbles splash.
4. "NEW RECIPE!" banner and +10 bonus coins. A pink bottle jumps out of the cauldron and sparkles away; a pink bottle now stands on your counter. The first customer walks in from the plaza asking for a Giant Head Potion.
5. Sell: +10 coins popup, the bottle leaves your counter, the customer raises a pink bottle and drinks, their head inflates, they shout "My head!!", then walk away. A new customer walks in.
6. Reach 25 coins: the UPGRADES badge appears. Buy Faster Brewing: the fire turns blue and the celebration banner shows.
7. Buy the Starflower Bed from its "for sale" sign in your shop: the sign disappears and starflowers appear. Floaty and Twirly show up in the menu.
8. **Timing:** first sale should come within 60–90 seconds.
9. **Spam test:** mash E on a customer with 1 potion. It must sell only once.
10. **Test tab > Clients and Servers > 2 players.** Each gets their own shop. You can't use the other shop's prompts, but you can see their customers walk and react. Walk to the other shop's pink heart and press **Cheer**: hearts burst, the other window gets a pink toast, the count on the stand goes up. Pressing again says you already cheered. The Market Stars board lists both players; the player list shows Coins and Sold.
11. **Test tab > Device > a phone.** Everything readable and tappable; the cauldron menu and buttons don't sit under the joystick or jump button. Tap a prompt to use it.
12. **Saving** (published place + API access on): earn coins, stop, play again. Coins, potions, upgrades and discovered recipes come back.
13. **Leave mid-brew**, rejoin: you have the potion.
14. **GIFT** button (top right, with a "!"): tap it, "DAILY GIFT! Day 1: +30 coins". Tap again: it says when the next one is ready.
15. **Late game fast:** in Studio there's an orange **+10K (Studio)** button (bottom left, never in the real game). Use it to buy the Ember and Cloud gardens (they grow up out of the ground), brew Fire Breath / Dance / Bubble / Ghost / Rocket and sell them, and buy a Magic Familiar (a cat floats behind you; the owl and dragon come next).
16. **Rebirth:** with the Cloud Garden and 5,000+ coins, the Rebirth card is at the top of the Upgrades panel. Tap it twice: your shop starts over, the familiar stays, your coins now show "x1.25", the sign says "Rebirth 1", and sales pay 25% more.
17. Watch the plaza for a minute: townsfolk stroll around, stop at the fountain and at shops, and sometimes say something.

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

* **Sources:** potion sales (10–220 coins, VIPs x2), first-brew bonuses (one per recipe, 887 total).
* **Sinks:** 9 useful/decor upgrade tracks (7,425 coins) plus the Magic Familiar (21,500).
* **Measured pacing** (`tests/pacing_bot.luau`, a quick bot that follows the goal banner, before the last price bump): first sale 0:13, Starflower Bed 1:15, Second Counter Spot 5:35, Frost Grotto 8:03, Ember Garden 12:27, Cloud Garden 14:11. About 100–170 coins/min for the first 8 minutes, 380–540 after the Frost Grotto, 750–870 after the Ember Garden; 101 sales in 16 minutes. A real player is slower (walking around, reading): expect roughly 1.5–2x these times.
* **Watch for:** the content wall once the familiars are bought (coins then only feed the Market Stars ranking), and whether Faster Brewing matters while customers are the bottleneck. Late-game income is high, so the Cloud Garden (now 2,500) and familiars (1,500 / 5,000 / 15,000) were raised after the run above; re-run the bot after any price change.

## Verified API notes (checked Sep 26–27, 2026)

* **ProfileStore** (github.com/MadStudioRoblox/ProfileStore, Apache-2.0, vendored unmodified): `ProfileStore.New(name, template)`, `:StartSessionAsync(key, {Cancel = fn})`, `profile.Data`, `:Reconcile()`, `:AddUserId()`, `:EndSession()`, `OnSessionEnd`, `IsClosing`, `DataStoreState`, `.Mock`. In Studio it test-writes a key; on "403" or "must publish" it switches to mock mode by itself. It handles `BindToClose` itself.
* **Lighting.Technology** is RobloxScriptSecurity and **Workspace.StreamingEnabled** is PluginSecurity for writing: scripts can't set them, so the place file does.
* Custom prompts: `ProximityPrompt.Style = Custom` + `ProximityPromptService.PromptShown/PromptHidden`; touch/click calls `prompt:InputHoldBegin()` / `InputHoldEnd()`.
* Particle textures that ship with every client (current manifest): `rbxasset://textures/particles/` `fire_main.dds`, `smoke_main.dds`, `sparkles_main.dds` (used by the new effects).
* Ball parts are always round (Roblox keeps their size uniform), so the parachute canopy is a block with a `SpecialMesh` (`MeshType.Sphere`).
* Client sounds that ship with every client (current manifest): `rbxasset://sounds/` `volume_slider.ogg`, `impact_water.mp3`, `action_jump.mp3`, `impact_explosion_03.mp3` (plus a few footstep sounds). The old ones (`button.wav`, `electronicpingshort.wav`, ...) are gone.
* Audio ids from Roblox's tutorials (github.com/Roblox/creator-docs): `4110925712` "simple chime" (In-game sounds), `3422389728` "retro jingle" and `1841461968` "upbeat" looping music (Add 2D audio), `1846248593` "cheerful, celebratory" (Add 3D audio). Not listened to from here: swap any you don't like.
* `ContentProvider:PreloadAsync(ids, callback(contentId, Enum.AssetFetchStatus))` accepts id strings; anything but `Success` means the asset didn't load.
* **Prices:** `MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Product / GamePass)`, read `PriceInRobux`. The old `GetProductInfo` is deprecated.
* **Developer products:** grant only through `ProcessReceipt` (or `BindReceiptHandler`), key on `PurchaseId`, save the grant in the profile, return granted only after that. Never grant from `PromptProductPurchaseFinished`.
* **Game passes:** `UserOwnsGamePassAsync(userId, passId)`.
* **Leaderboards:** `DataStoreService:GetOrderedDataStore(name)`, `:SetAsync(key, integer)`, `:GetSortedAsync(false, 10):GetCurrentPage()` gives `{ key, value }` items. Names in one call: `UserService:GetUserInfosByUserIdsAsync(ids)` gives `{ Id, Username, DisplayName }`.

## Unresolved bugs / known gaps

* **Never played in Studio.** Expect a first round of small fixes (sizes, positions, colors, UI spacing).
* Only 4 real audio ids so far (chime, jingle, celebration, music), picked from Roblox's tutorials without hearing them. Effect sounds (ribbit, freeze, whoosh, inflate, shrink) and bubbling are still empty: pick audio in the Toolbox and paste the ids into `Config/Sounds.lua`.
* Lighting and colors were chosen without seeing them rendered; tweak `Config/World.lua` and `Config/Palette.lua` to taste.
* If Roblox ever changes a ball part's size when its shape is set, bushes and bottles may look slightly different (visual only).
* More than 6 players in one server: extra players get "The market is full" (set server size to 6).

## Next steps

1. **You:** open `build/BrewAPotion.rbxlx`, run the test checklist, send errors or "it works" (screenshots help a lot for the look).
2. Fix what the playtest finds; tune lighting, colors and economy numbers (re-run `tests/pacing_bot.luau` after price changes).
3. Listen to the 4 chosen sounds and the music; fill the empty effect sound slots from the Toolbox (`Config/Sounds.lua`).
4. More content for rebirth runs: more decor themes, special orders, a rebirth-only potion or ingredient.
5. Later: monetization (see the API notes above), trading between friends.
