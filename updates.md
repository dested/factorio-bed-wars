# Updates

## 2026-07-20 — v1.0.2: full single-player Rivet AI
Added a character-based computer opponent with Rookie, Rival, and Master skill
levels independent from match pace. Rivet gathers visible generator drops,
shops at normal prices, equips guns/ammo/armor, buys upgrades, builds landfill
bridges, contests mid, performs a Master emerald resupply, strafes, retreats,
heals, defends bed threats, shoots through walls, breaks beds, respawns, and
can be permanently eliminated. Lobby rosters, settings, HUD, victory checks,
rematch reset, healing aura, locale, migration, and documentation now include
the AI. Human 1v1 remains available with Computer opponent = Off.

Verified on Factorio 2.1.11 with data-stage and production boot checks plus an
accelerated headless integration match covering bridging, resupply, equipped
weapon/ammo consumption, obstruction and bed destruction, respawn, and
elimination.
Touched: mod scenario control/config/ai/lobby/combat/hud/upgrades, locale,
info.json, README/cliffnotes/decisions/ui/verify/updates

## 2026-07-20 — v1.0.1: make beds actually breakable (+ damageable by weapons)
Playtest found beds unbreakable (players can't mine enemy-force entities) →
beds are neutral force now. Per request, beds are also damageable: 1000 HP,
resistances tuned (mine 3s fastest, guns slow, fire melts), own-team kill/mine
rebuilds. New on_entity_died handler w/ name filters. Verified data+boot clean.
Touched: prototypes/entities.lua, lib/teams.lua, lib/combat.lua, control.lua, info.json, docs

## 2026-07-20 — build Bed Wars as a Factorio scenario, full game
Built the whole mod+scenario from scratch (per plans/2026-07-20-bed-wars-design.md):
islands map, 3-tier economy (iron/gold/emerald generators), item+upgrade
markets, bed break/elimination/victory/rematch, lobby + HUD + 3 difficulties,
generated pixel-art sprites. Verified: data stage + headless scenario boot
clean on 2.1.11; junctioned into the live mods folder.
Touched: mod/** (all), cliffnotes kit, plans/2026-07-20-bed-wars-design.md

