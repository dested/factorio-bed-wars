# Bed Wars for Factorio — Design & Architecture

Status: done
Date: 2026-07-20
Target: Factorio 2.1.11 (Steam, Windows), base game only (no DLC dependency)

## What this is

A Factorio **mod that ships a scenario** ("Bed Wars"), faithful to Minecraft
Bed Wars, tuned for 1v1 (dad vs son). Mod is needed for custom prototypes
(bed, currencies, wall tiers, generator markers); scenario carries all
runtime logic. Appears in game as New Game → Scenarios → Bed Wars.

## Core loop (mapping MC → Factorio)

| Minecraft | Factorio implementation |
|---|---|
| Islands in the void | Islands in an all-water finite map; `out-of-map` border |
| Bridging with blocks | **Landfill** bought from shop |
| Wool/wood/obsidian walls | stone-wall (350HP) / bw-wall-2 (1500HP) / bw-wall-3 (5000HP) + gates |
| Iron/gold/emerald drops | item-on-ground spawned near generator entities: `iron-plate`, `bw-gold`, `bw-emerald` |
| Item shop villager | vanilla `market` entity with offers (iron/gold/emerald prices) |
| Team upgrades villager | second market selling hidden **token items**; `on_market_item_purchased` applies effect and eats token |
| Swords/bows/armor | pistol→SMG→shotgun→combat-shotgun→flamethrower; grenades; light/heavy/power armor; gun turrets; a CAR |
| Bed | `bw-bed` 2×2 entity: **indestructible but hand-minable by the enemy** (~5 s channel). Bullets can't snipe it — you must physically reach it, so walls genuinely protect it (faithful to MC) |
| Bed gone → no respawn | death → spectator; last team standing wins |
| Forge / team upgrades | force modifiers + scripted auras |

## Map layout (all coordinates in tiles, surface = nauvis)

- Playable disc radius 118 water; radius 118–126 `deepwater`; beyond → `out-of-map`. Always day. All natural entities (biters, trees, rocks, resources, cliffs, fish) wiped per chunk at generation; we place our own decor. Whole map charted for both forces.
- **Home islands** (West blue @ center −64,0; East red @ +64,0): 26×26 rounded square (|dx|≤13, |dy|≤13, corners rounded r=4), `grass-1`. Furniture (West; East = negate x offsets):
  - Bed `bw-bed` (2×2) @ (−72, 0) — far edge, behind spawn
  - Spawn point @ (−68, 0); `hazard-concrete-left` 4×4 under bed
  - Base generator `bw-generator` @ (−64, 0), `refined-concrete` plaza 10×10 around island center
  - Item Shop `bw-market-items` @ (−64, −6); Upgrade Shop `bw-market-upgrades` @ (−64, +6)
  - Team steel chest @ (−68, −4)
  - 4 decorative trees near corners
- **Gold islands**: circles r=8 `sand-1` @ (0, −44) and (0, +44); 1 gold generator each @ center.
- **Mid island**: circle r=14 @ (0,0), `grass-2` with `stone-path` 6×6 center; 2 emerald generators @ (0,−5) and (0,+5).
- Straight-line bridge home→mid ≈ 37 water tiles; home→gold island diagonal ≈ 30.

## Economy

Currencies: `iron-plate` (vanilla), `bw-gold` (coin icon), `bw-emerald` (uranium-235 icon, green). Spawned as items on ground near generators (spill within 2 tiles); each generator has a cap (skip spawn if ≥cap of that item within radius 4) so piles don't grow unbounded.

Generator schedule (Classic; period in ticks):
| Generator | Item | Period | Cap |
|---|---|---|---|
| Base ×1/team | iron-plate | 60 | 48 |
| Base ×1/team | bw-gold | 300 | 16 |
| Gold island ×1 each | bw-gold | 180 | 12 |
| Mid ×2 | bw-emerald | 900 → 600 (tier II) → 360 (tier III) | 8 |

Forge upgrade scales base-gen periods: I ÷1.5, II ÷2.0, III ÷2.5 + base emerald drip every 1800.

## Item shop offers (count × item — price)

Blocks: 10×landfill—6 iron · 6×stone-wall—5 iron · 2×gate—4 iron · 4×bw-wall-2—4 gold · 2×bw-wall-3—1 emerald
Weapons: submachine-gun—8 gold · shotgun—5 gold · combat-shotgun—2 emerald · flamethrower—3 emerald
Ammo: 10×firearm-magazine—8 iron · 10×shotgun-shell—6 iron · 10×piercing-rounds-magazine—4 gold · 5×piercing-shotgun-shell—3 gold · 1×flamethrower-ammo—1 emerald · 3×grenade—5 gold · 1×cluster-grenade—1 emerald
Defense: gun-turret—10 gold · 2×repair-pack—4 iron · 3×raw-fish—3 iron (eat to heal!)
Armor: light-armor—15 iron · heavy-armor—10 gold · power-armor—3 emerald
Fun: car—10 gold · 5×solid-fuel—3 iron · 3×defender-capsule—1 emerald · 2×poison-capsule—1 emerald

Chill prices ×0.75 (ceil), Brutal ×1.0.

## Upgrade shop (team-wide; token items `bw-token-*`)

| Upgrade | Effect | Cost |
|---|---|---|
| Forge I/II/III | base gen speed ÷1.5/÷2.0/÷2.5+emerald drip | 6 g / 12 g / 3 em |
| Sharpened Rounds I/II | force ammo (bullet, shotgun-shell) & turret damage +30% / +60% | 6 g / 2 em |
| Swift Boots | force running speed +25% | 4 g |
| Demolition Drill | force manual mining +150% (breaks enemy bed faster) | 4 g |
| Healing Pool | allies within 12 tiles of own bed heal 3 HP/s | 1 em |
| Bed Fortress | instantly ring own bed with bw-wall-2 (8×8, gate on inner side) | 8 g |

Tiered offers replaced on purchase; one-shots removed. Purchase feedback: flying text + sound.

## Game flow

1. **Lobby**: players join as spectators hovering mid. Center GUI: title, team roster (P1→West/blue, P2→East/red, "Switch sides" while in lobby), host-only difficulty drop-down, START button (works with 1 player for solo testing). Late joiners after start = spectators.
2. **Start**: characters created at spawns, kit given (pistol + 20 firearm-magazine + 10 landfill), permissions lock hand-crafting, research disabled, HUD appears, clock starts.
3. **Death**: corpse with loot (vanilla). Bed alive → respawn at spawn in 10 s (Brutal 15 s) with fresh kit. Bed dead → permanent spectator + broadcast.
4. **Bed break**: enemy hand-mines your bed → big broadcast + `utility/alert_destroyed` sound to all, HUD flips to ☠, miner's team announced.
5. **Win**: a team with dead bed has zero live players → victory banner GUI (winner color), explosion fireworks over losing island, "Rematch" + "Continue watching" buttons. **Rematch** does a full deterministic reset: wipe non-character entities, re-run tile pass, re-place furniture, reset storage/upgrades/forces, back to lobby.
6. **Escalation clock** (Classic): 12:00 Emerald II · 24:00 Emerald III · 30:00 Sudden Death warning · 32:00 both beds self-destruct · 40:00 draw. Chill: no sudden death, gens ×1.4 faster. Brutal: gens ×0.75 speed, sudden death 22:00/24:00.
7. **HUD** (top bar, updated 2×/s): your bed ♥/☠, enemy bed, iron/gold/emerald counts, game clock, next event countdown.

## Difficulties

| | Chill | Classic | Brutal |
|---|---|---|---|
| Gen speed | ×1.4 | ×1.0 | ×0.75 |
| Prices | ×0.75 | ×1.0 | ×1.0 |
| Respawn | 8 s | 10 s | 15 s |
| Sudden death | off | 32:00 | 24:00 |

## Mod file layout (repo `G:\code\factorio-bed-wars`)

```
mod/                          ← junctioned into %APPDATA%\Factorio\mods\bed-wars
  info.json                   name=bed-wars, factorio_version 2.0 (bump if 2.1 required)
  data.lua
  prototypes/items.lua        bw-gold, bw-emerald, bw-wall-2/3 items, bw-token-* (hidden)
  prototypes/entities.lua     bw-bed, bw-generator, bw-wall-2/3, bw-market-items/upgrades
  graphics/*.png              custom bed + generator sprites (generated by tools/make-sprites.ps1)
  tools/make-sprites.ps1      System.Drawing pixel-art generator (bed, obelisk, icons)
  locale/en/bed-wars.cfg
  scenarios/bedwars/
    description.json
    control.lua               event wiring only (Fable-written)
    lib/config.lua            ALL constants (Fable-written; source of truth)
    lib/util.lua  lib/mapgen.lua  lib/teams.lua  lib/lobby.lua
    lib/generators.lua  lib/shop.lua  lib/upgrades.lua
    lib/combat.lua  lib/hud.lua
plans/                        this doc
```

### Module interfaces (exact; control.lua calls these)

- `Mapgen.on_chunk_generated(e)` · `Mapgen.prime(surface)` · `Mapgen.reset_tiles(surface)`
- `Teams.create_forces()` · `Teams.setup_islands(surface)` · `Teams.assign(player, key)` · `Teams.give_kit(player)` · `Teams.make_spectator(player)`
- `Lobby.show(player)` · `Lobby.on_gui_click(e)` · `Lobby.on_selection_changed(e)` · `Lobby.start_game()`
- `Generators.tick()` (on_nth_tick 10) · `Generators.set_forge_level(key, lvl)` · `Generators.escalate(tier)`
- `Shop.stock_markets()` · `Shop.on_market_purchase(e)`
- `Upgrades.apply(key, id)` · `Upgrades.tick()` (heal aura, on_nth_tick 30) · `Upgrades.refresh_offers(key)`
- `Combat.on_player_mined_entity(e)` · `Combat.on_pre_player_died(e)` · `Combat.on_player_died(e)` · `Combat.on_player_respawned(e)` · `Combat.check_victory()` · `Combat.sudden_death()` · `Combat.end_game(winner_or_nil)` · `Combat.rematch()`
- `Hud.build(player)` · `Hud.update_all()` · `Hud.announce(text, color, sound)`

### storage schema

```lua
storage.bw = {
  state = "lobby"|"active"|"over",
  difficulty = "chill"|"classic"|"brutal",
  started_tick = nil|number,
  escalation_next = 1,
  teams = {
    west = { force_name="bw-west", bed=LuaEntity, bed_alive=true, spawn={x=,y=},
             market_items=ent, market_upgrades=ent, chest=ent,
             upgrades={forge=0, sharp=0, boots=false, drill=false, heal=false, fortress=false},
             players={player_index,...} },
    east = { ... mirrored ... },
  },
  gens = { {ent=, item=, period=, cap=, kind="base-iron"|"base-gold"|"gold"|"emerald"|"base-emerald", team=nil|"west"|"east", next_tick=}, ... },
}
```

## Verification

- Data stage: headless `factorio.exe --dump-data --mod-directory <isolated dir>` → zero errors in factorio-current.log
- Control stage: `factorio.exe --start-server-load-scenario bed-wars/bedwars --mod-directory <isolated dir>` → server reaches "joinable", kill process, log clean
- Install: junction `%APPDATA%\Factorio\mods\bed-wars` → repo `mod/`

## Build plan (fable-opus)

Wave 1 (3 Opus agents): DATA (mod skeleton+prototypes+sprite gen), MAP (util/mapgen/teams), ECON (generators/shop/upgrades). Fable writes config.lua + control.lua + description.json. Wave 2: GAME agent (lobby/combat/hud). Then review → headless verify → quality gate.
