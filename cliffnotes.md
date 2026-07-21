# Bed Wars for Factorio — Cliffnotes

Last updated: 2026-07-20

Minecraft Bed Wars rebuilt as a **Factorio 2.1 mod that ships a scenario**.
Play solo against Rivet, a full character-based opponent, or disable the AI
for human 1v1. Two islands, resource generators, market shops, team upgrades,
landfill bridges, and a bed that gates respawning.

## Quick reference

| Thing | Where / how |
| --- | --- |
| Play it | Factorio → New Game → Scenarios (or Mods tab) → **Bed Wars › bedwars** |
| Single-player | Leave **Computer opponent** on Rookie, Rival, or Master; Rivet takes the empty team |
| Human 1v1 | Set **Computer opponent** to **Off (multiplayer)** |
| Install (this machine) | Already junctioned: `%APPDATA%\Factorio\mods\bed-wars` → `mod/` |
| All gameplay tuning | `mod/scenarios/bedwars/lib/config.lua` — every number lives here |
| AI implementation | `mod/scenarios/bedwars/lib/ai.lua` — state machine, economy, movement, combat |
| Verify after changes | See `verify.md` (headless data + server boot, isolated from a running game) |
| Full design rationale | `plans/2026-07-20-bed-wars-design.md` (done) |

## Directory tree

```
mod/                          ← the actual Factorio mod (junction target)
  info.json                   name=bed-wars, factorio_version "2.1" (must match minor!)
  data.lua                    requires the two prototype files
  thumbnail.png               mod-list art (generated)
  prototypes/
    items.lua                 bw-gold, bw-emerald, bw-wall-2/3 items, 9 hidden bw-token-*
    entities.lua              bw-bed-west/east, bw-generator, 2 markets, bw-wall-2/3 walls
  graphics/                   11 generated pixel-art PNGs (beds, obelisk, stalls, icons)
  tools/make-sprites.ps1      regenerates every PNG (System.Drawing; run with pwsh)
  locale/en/bed-wars.cfg      item/entity names+descriptions, scenario name
  scenarios/bedwars/
    description.json          {order, multiplayer-compatible}
    control.lua               event wiring ONLY — routes events to lib/ modules
    lib/
      config.lua              SOURCE OF TRUTH: map geometry, prices, rates, difficulties
      util.lua                announce/fly/fmt_time/team_pos helpers (stateless)
      mapgen.lua              pure tile function + chunk paving + natural-entity wipe
      teams.lua               forces, permissions (no crafting), island furniture, spawn/kit
      generators.lua          item-on-ground spawner w/ caps, forge & emerald-tier scaling
      shop.lua                market stocking + purchase routing (tokens → upgrades)
      upgrades.lua            team upgrade effects, offer refresh, heal aura, modifier reset
      lobby.lua               center-GUI lobby: rosters, switch, difficulty, START
      ai.lua                  fair-economy character AI: shop, bridge, fight, defend, respawn
      combat.lua              bed break, deaths/eliminations, victory, escalation clock, rematch
      hud.lua                 top-bar HUD: bed status, currencies, clock, next event
plans/                        dated working docs (design doc lives here)
verify.md / updates.md / decisions.md / ui.md   ← the rest of the kit
```

## How the game flows (runtime)

1. `control.lua on_init`: builds `storage.bw`, creates forces, pre-generates
   chunks (mapgen paints islands over an all-water disc), places furniture +
   generators, stocks markets, charts the map.
2. Players join → spectators + **lobby GUI** (host picks game pace and AI
   skill). Rivet is shown on whichever team has no connected human; selecting
   Off keeps the original human 1v1/solo-exploration behavior.
3. START: human characters and Rivet spawn with kit
   (pistol/ammo/landfill), crafting is
   permission-blocked — everything comes from the two markets per island.
4. `on_nth_tick(10)` generators drop items on the ground (walk to collect);
   `on_nth_tick(30)` HUD, heal aura, escalation clock (Emerald II/III, sudden
   death, draw).
5. Bed = `bw-bed-*`: **neutral force** (players can't mine enemy-force
   entities), 1000 HP with resistances (bullets weak, fire strong), turret-proof
   via `is_military_target=false`. Broken by hand-mining (3 s, fastest) or
   player damage (`on_entity_died` w/ name filters). Own-team mining or
   own-team splash kill → instant rebuild + scold.
6. Death: bed alive → auto-respawn (8/10/15 s by difficulty); bed dead →
   eliminated → spectator. Team all-eliminated → victory GUI + fireworks +
   REMATCH button (full deterministic reset back to lobby).
7. Rivet runs every tick as a real hostile `character`: gathers nearby ground
   stacks, pays normal configured prices, equips real inventories, builds
   landfill one tile at a time, contests mid, resupplies, strafes/retreats,
   defends bed threats, breaks walls, attacks the bed, and follows the same
   respawn/elimination rules. Script-owned characters do not advance vanilla
   gun attacks, so equipped weapon cadence, ammo use, aim error, damage,
   resistances, and kill attribution are resolved deterministically in `ai.lua`.

## storage schema

`storage.bw = { state, difficulty, host, started_tick, escalation_next,
emerald_tier, sudden_death_*, pending_spectate, fireworks, rng, teams{west/east
= force_name, bed, bed_alive, spawn, market_items, market_upgrades, chest,
upgrades{forge,sharp,boots,drill,heal,fortress}, players[]}, gens[], ai{
difficulty,enabled,team,character,state,route,respawn_tick,eliminated,
reached_mid,reached_enemy,resupply_*,combat timing,stats} }` —
initialized ONLY in `control.lua on_init`; modules never add top-level keys.

## Gotchas (hard-won)

- **`require()` only works at control-stage load time.** Never call it inside
  a function/event handler — hoist to top of file. All requires are
  mod-absolute: `require("__bed-wars__/scenarios/bedwars/lib/x")`.
- **`factorio_version` in info.json must match the minor version exactly**
  ("2.1" for 2.1.x — "2.0" is rejected).
- 2.x API traps: `storage` not `global`; `print(msg, {color=...})` (no color
  2nd arg); `spill_item_stack{...}` named table; `entity.minable` is read-only
  → use `entity.minable_flag`; market prices use named keys
  `{name=,count=}`; no tuple form.
- **Verification while Factorio is running**: the user data dir is locked by a
  live game. Always use the isolated config + `--mod-directory` recipe in
  `verify.md` (own write-dir, port 34199).
- `simple-entity-with-force` defaults `is_military_target=true` — beds and
  generators explicitly set false or turrets shoot them.
- Sounds: only use verified paths (`utility/console_message`,
  `utility/alert_destroyed`, `utility/game_won`, `utility/game_lost`).
- No emoji in in-game captions (font gaps); use rich text `[item=bw-emerald]`.
- `walking_state` is a one-tick input: the AI must run on nth-tick 1. Keep
  expensive scans cadence-gated (`AI_PICKUP_TICKS`) rather than slowing its
  controller tick.
- A script-owned `character` accepts `shooting_state` and reports `can_shoot`,
  but does not actually advance the gun attack. `ai.lua` therefore keeps real
  gun/ammo slots and shooting animation while resolving weapon fire itself.
- **Other mods run inside our scenario** and freeplay-assuming ones crash (Any
  Planet Start died in on_player_created). Play via the "Bed Wars only"
  profile: `%APPDATA%\Factorio\bedwars-mods` (junction + minimal mod-list) +
  the desktop shortcut "Factorio - Bed Wars" (`--mod-directory` launch). MP
  also requires both players' mod lists to match exactly.

## Status

- **Done**: full single-player + human 1v1 game loop (map, economy, shops,
  upgrades, combat, lobby/HUD/victory, rematch), 3 match paces, and 3 AI skill
  levels. Data stage, production scenario boot, and accelerated AI integration
  match verified clean on 2.1.11. The integration run covered bridge building,
  mid collection, emerald resupply, equipped gun/ammo use, wall breaking, bed
  destruction, respawn, and final elimination.
- **Not built** (deliberate): 2v2 teams, biters, bed-defense minigames.
  See `decisions.md`.
- **Untested**: final hands-on balance/feel with a human actively fighting
  Rivet; the complete AI lifecycle is engine-tested headlessly.
