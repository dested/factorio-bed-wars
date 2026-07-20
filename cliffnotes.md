# Bed Wars for Factorio — Cliffnotes

Last updated: 2026-07-20

Minecraft Bed Wars rebuilt as a **Factorio 2.1 mod that ships a scenario**.
Two players on two islands, resource generators, market shops, team upgrades,
landfill bridges, and a bed that gates respawning. Built for 1v1 (dad vs son).

## Quick reference

| Thing | Where / how |
| --- | --- |
| Play it | Factorio → New Game → Scenarios (or Mods tab) → **Bed Wars › bedwars** |
| Install (this machine) | Already junctioned: `%APPDATA%\Factorio\mods\bed-wars` → `mod/` |
| All gameplay tuning | `mod/scenarios/bedwars/lib/config.lua` — every number lives here |
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
      combat.lua              bed break, deaths/eliminations, victory, escalation clock, rematch
      hud.lua                 top-bar HUD: bed status, currencies, clock, next event
plans/                        dated working docs (design doc lives here)
verify.md / updates.md / decisions.md / ui.md   ← the rest of the kit
```

## How the game flows (runtime)

1. `control.lua on_init`: builds `storage.bw`, creates forces, pre-generates
   chunks (mapgen paints islands over an all-water disc), places furniture +
   generators, stocks markets, charts the map.
2. Players join → spectators + **lobby GUI** (host picks difficulty, START).
3. START: characters spawn with kit (pistol/ammo/landfill), crafting is
   permission-blocked — everything comes from the two markets per island.
4. `on_nth_tick(10)` generators drop items on the ground (walk to collect);
   `on_nth_tick(30)` HUD, heal aura, escalation clock (Emerald II/III, sudden
   death, draw).
5. Bed = `bw-bed-*`: indestructible (`destructible=false`, turret-proof via
   `is_military_target=false`) but **hand-minable by the enemy** (3 s channel).
   Mining your own bed instantly rebuilds it.
6. Death: bed alive → auto-respawn (8/10/15 s by difficulty); bed dead →
   eliminated → spectator. Team all-eliminated → victory GUI + fireworks +
   REMATCH button (full deterministic reset back to lobby).

## storage schema

`storage.bw = { state, difficulty, host, started_tick, escalation_next,
emerald_tier, sudden_death_*, pending_spectate, fireworks, rng, teams{west/east
= force_name, bed, bed_alive, spawn, market_items, market_upgrades, chest,
upgrades{forge,sharp,boots,drill,heal,fortress}, players[]}, gens[] }` —
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

## Status

- **Done**: full 1v1 game loop (map, economy, shops, upgrades, combat,
  lobby/HUD/victory, rematch, 3 difficulties), data stage + headless server
  boot verified clean on 2.1.11, installed via junction.
- **Not built** (deliberate): 2v2 teams, biters, bed-defense minigames.
  See `decisions.md`.
- **Untested**: full in-game playthrough (needs two humans — the fun part).
