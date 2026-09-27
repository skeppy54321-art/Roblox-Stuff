# Social: leaderboard, market news, cheers, Market Stars board

Status: draft (built overnight, not yet reviewed)

* **Goal:** see the other shop owners in your market, feel their progress, and be able to do something nice for them. Nothing here can change anyone's coins.
* **Player list (leaderstats):** `Coins` and `Sold` (potions sold) for everyone in the server. Server-owned values, updated on every change.
* **Market news:** when someone discovers a recipe or unlocks a big upgrade (Starflower Bed, Second Counter Spot, Frost Grotto), everyone else gets a violet toast ("Sam discovered the Froggy Potion!"). The player who did it gets their own celebration instead. At most one news item per player every 3 seconds.
* **Cheer stand:** a small wooden stand with a big pink heart at the front right of every shop, outside the counter.
  * On your own shop and on empty shops: no prompt, just the heart and the count.
  * On someone else's shop: a "Cheer" prompt. Pressing it: hearts burst from the stand (everyone sees them), the owner's cheer count goes up by one and they get a pink "Sam cheered for your shop!" toast with a chime; you get "You cheered for Alex's shop!".
  * One cheer per visitor per shop per visit (server session). A second press says "You already cheered for Alex's shop!". Cheers are saved (`Stats.Cheers`).
* **Market Stars board:** a wooden notice board in the plaza, opposite the welcome sign. Title "Market Stars", then one row per shop owner in this server, best first by coins earned (all time): rank badge (gold / silver / bronze for the top three), name, coins earned, recipes found (x/12), cheers.
  * Empty state: "Open a shop to be a star!"
  * Refreshes a couple of seconds after any change.
* **Mobile:** nothing new on screen except toasts; the prompt uses the game's custom prompt style.
