# Decisions

## 2026-07-20 — Fair character AI, separate from match pace
**Why:** single-player should feel like Bed Wars against another player, not a
wave-defense substitute. Rivet is therefore a hostile `character` that walks,
collects visible drops, pays the same configured prices, equips inventory,
bridges one tile at a time, contests mid, resupplies, defends, attacks, and
uses the normal bed/respawn lifecycle. Rookie/Rival/Master tune reaction,
accuracy, aggression, retreating, upgrades, and planning; Chill/Classic/Brutal
remain shared economy/clock settings.
**Engine constraint:** script-owned characters accept walking and shooting
state, but only walking advances without a player controller. Weapon resolution
is deterministic in `ai.lua` using the equipped gun/ammo, vanilla-like cadence,
magazine consumption, aim error, damage resistance, force upgrades, visual
impacts, and normal kill attribution.
**Rejected:** invisible resource grants (unfair), a renamed biter/unit
(cannot shop/build/use the Bed Wars economy), and a stationary turret opponent
(does not resemble a player).

## 2026-07-20 — Mod-that-ships-a-scenario (not a plain scenario, not a soft-mod)
**Why:** custom prototypes (beds, currencies, wall tiers, markets) require a
mod's data stage; the game mode itself is naturally a scenario. One artifact
gives both, and shows up under New Game.
**Rejected:** plain scenario (no custom entities possible), pure mod that
hijacks freeplay (messy, breaks normal play).

## 2026-07-20 — Bed is indestructible but enemy-hand-minable
**Why:** Factorio bullets ignore walls (no projectile collision), so a
shootable bed would be sniped through any defense. Requiring a 3 s adjacent
mining channel makes walls genuinely protective — faithful to Minecraft where
you must stand at the bed to break it. Own-team mining instantly rebuilds it.
**Rejected:** destructible-with-HP bed (walls would be decorative), turret-target
bed (same problem; also is_military_target defaults true and had to be false).

## 2026-07-20 — Currencies: vanilla iron-plate + custom bw-gold/bw-emerald
**Why:** iron-as-iron is thematic and free; gold/emerald as custom items give
clean 3-tier pricing with recognizable icons (coin / tinted uranium-235).
**Rejected:** all-custom currencies (pointless), vanilla coin directly (name
collisions with other mods, no locale control).

## 2026-07-20 — Upgrades sold as hidden token items through a market
**Why:** `on_market_item_purchased` gives a clean hook; the market GUI is free
UI with tooltips (token descriptions explain each upgrade). Token is removed
and the effect applied; tiered offers are re-stocked per level.
**Rejected:** custom shop GUI (large surface area for no gameplay gain).

## 2026-07-20 — Hand-crafting disabled via permission group
**Why:** the economy IS the game; crafting would bypass shops. Permission group
blocking `craft`/`cancel_craft` is total and per-player.
**Rejected:** manual_crafting_speed_modifier = -1 (players still see a working
craft UI; modifier tricks are leakier).

## 2026-07-20 — Scope: 1v1 only, no biters
**Why:** built for dad-vs-son; two forces keep every system (victory, rosters,
HUD) simple. Difficulty comes from economy pacing + sudden death, not enemies.
**Rejected:** 2v2 (lobby/team complexity now, easy to add later), biter raids
on mid (fights the PvP focus; water map makes pathing weird).

## 2026-07-20 — All tuning in config.lua; modules never hardcode numbers
**Why:** one file to rebalance the whole game (prices, rates, geometry,
difficulty multipliers) — safe for non-programmers to tweak.

## 2026-07-20 — Bed is damageable + minable, neutral force (supersedes "indestructible but enemy-hand-minable")
**Why:** two playtest findings. (1) Players can NEVER hand-mine enemy-force
entities, so team-force beds were unbreakable — beds are now neutral force
(ownership lives in the prototype name). (2) Weapons-on-bed is more fun:
1000 HP with resistances (bullets weakened, explosions decent, fire unresisted,
impact halved) makes guns/grenades/flamethrower/car all viable while the 3 s
mining channel stays fastest. Turrets still ignore beds (is_military_target
false); own-team kills/mines trigger instant rebuild.
**Rejected:** keeping full indestructibility (less fun, and the wall-sniping
concern is tempered by bullet resistance + turret immunity).
