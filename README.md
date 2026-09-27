# Brew a Potion

A cozy Roblox potion-shop game: collect magic ingredients, brew potions in your cauldron,
and sell them to customers who drink them and turn into frogs, ghosts, rockets and more.
Up to 6 players each run a shop around a market plaza.

## Play it in Roblox Studio

The whole game is one place file: [`build/BrewAPotion.rbxlx`](build/BrewAPotion.rbxlx).

1. Open that file on GitHub and click **Download raw file** (the download icon).
2. Open **Roblox Studio** (Windows or Mac) > **File > Open from File...** > pick `BrewAPotion.rbxlx`.
   (Double-clicking the file also works.)
3. Press **Play**. In Studio only, an orange **+10K** button lets you skip ahead to the late game.

To keep it on your Roblox account: **File > Publish to Roblox As...** > a new experience. Then
turn on **Game Settings > Security > Enable Studio Access to API Services** so progress saves,
and set the server size to **6** (one shop per player).

## More

* [`PROJECT_STATE.md`](PROJECT_STATE.md): everything in the game, a test checklist, the economy,
  design decisions and what's next.
* `src/`: the scripts (Luau). `default.project.json` builds the place with [Rojo](https://rojo.space)
  (`rojo build default.project.json -o build/BrewAPotion.rbxlx`).
* `tests/`: headless tests that run the real scripts outside Roblox with [Lune](https://github.com/lune-org/lune).
