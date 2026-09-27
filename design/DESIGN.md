# Design system — Brew a Potion

Status: draft (built overnight from the "cozy magic market" direction; review in Studio, then mark approved)

## Feel
Cozy magic market at golden hour: warm wood, cream parchment, rose and gold accents, glowing potions.
Bright and readable first, magical second. Phone-first.

## Colors (all in `src/ReplicatedStorage/Config/Palette.lua`)
| Role | Name | Use |
|---|---|---|
| Panels | `PanelLight` / `PanelCream` | modal panels, cards, goal banner |
| Dark UI | `PanelDark` / `PanelMid` | coins pill, basket, prompts, toasts |
| Accent | `Gold` | coins, strokes on important things, the goal arrow |
| Action | `Button` / `ButtonDark` | anything you can do right now |
| Disabled | `ButtonOff` / `ButtonOffDark` | can't afford / locked |
| Warning | `Danger` | close buttons, "can't do that" toasts, NEW badges |
| Text | `TextDark` on light, `TextLight` on dark, `TextMuted` for descriptions |

Each potion's own `Color` (Config.Recipes) is reused everywhere that potion appears: bottle icons, cauldron liquid, brew bar, effects.

## Type
One font: FredokaOne. Text is scaled with a max size so it never overflows.
Titles 30–38, labels 20–24, small print 14–18 (design pixels).

## Layout
* Everything is drawn on a 1000 x 560 design screen and scaled to fit (0.62x on small phones up to 1.3x on big monitors), inside Roblox's safe area.
* Top center: coins, goal banner, toasts. Top left: basket. Right middle: side buttons. Bottom center: cauldron menu (only when standing at your cauldron). Center: modal panels and celebrations.
* Bottom corners stay free for the thumbstick and jump button.

## Patterns
* **Chunky button:** colored face over a darker edge, squishes when pressed (`Ui.button`).
* **Panel:** parchment card, dark wood border, colored title ribbon, red X (`Ui.panel`).
* **Pop:** anything that changes bounces a little (`Ui.pop`).
* **Icons:** drawn with frames, no image assets: potion bottle, coin, ingredient dot.
