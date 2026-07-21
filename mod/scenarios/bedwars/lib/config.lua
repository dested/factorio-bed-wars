-- Bed Wars: every tunable number and coordinate lives here. Modules read, never write.
local Config = {}

Config.SURFACE = "nauvis"

-- Map geometry (tiles). Playable water disc, deepwater rim, out-of-map beyond.
Config.MAP = {
  water_radius = 118,
  deepwater_radius = 126,
  chunk_prime_radius = 5, -- chunks to pre-generate around origin (5*32=160 > 126)
}

-- Island geometry. Home islands are rounded squares; gold/mid are circles.
Config.ISLANDS = {
  home_half = 13,      -- |dx|,|dy| <= 13 → 26x26
  home_corner = 4,     -- corner rounding radius
  home_cx = 64,        -- centers at (±64, 0)
  gold_radius = 8,     -- circles at (0, ±44)
  gold_cy = 44,
  mid_radius = 14,     -- circle at (0,0)
}

-- Per-team furniture offsets from home island center. West uses these verbatim
-- (island center −64,0); East negates x. Positions are entity centers.
Config.FURNITURE = {
  bed = { x = -8, y = 0 },        -- 2x2, sits at far edge
  spawn = { x = -4, y = 0 },
  base_gen = { x = 0, y = 0 },
  market_items = { x = 0, y = -6 },
  market_upgrades = { x = 0, y = 6 },
  chest = { x = -4, y = -4 },
  trees = { {x=-11,y=-11}, {x=11,y=-11}, {x=-11,y=11}, {x=11,y=11} },
}

Config.TEAMS = {
  west = { force_name = "bw-west", display = "West", color = {r=0.2,g=0.5,b=1,a=1}, sign = -1 },
  east = { force_name = "bw-east", display = "East", color = {r=1,g=0.25,b=0.25,a=1}, sign = 1 },
}
Config.TEAM_ORDER = { "west", "east" }

Config.TILES = {
  water = "water", deepwater = "deepwater", void = "out-of-map",
  home = "grass-1", gold = "sand-1", mid = "grass-2",
  plaza = "refined-concrete", plaza_size = 5,      -- half-extent of 10x10 plaza
  bed_pad = "hazard-concrete-left", bed_pad_half = 2,
  mid_pad = "stone-path", mid_pad_half = 3,
}

-- Generator schedule: periods in ticks at Classic. kind is a stable id.
Config.GENERATORS = {
  { kind = "base-iron",    item = "iron-plate", period = 60,  cap = 48, per_team = true,  offset = {x=0, y=0} },
  { kind = "base-gold",    item = "bw-gold",    period = 300, cap = 16, per_team = true,  offset = {x=0, y=0} },
  { kind = "base-emerald", item = "bw-emerald", period = 1800, cap = 4, per_team = true,  offset = {x=0, y=0}, forge3_only = true },
  { kind = "gold-north",   item = "bw-gold",    period = 180, cap = 12, position = {x=0, y=-44} },
  { kind = "gold-south",   item = "bw-gold",    period = 180, cap = 12, position = {x=0, y=44} },
  { kind = "emerald-north", item = "bw-emerald", period = 900, cap = 8, position = {x=0, y=-5}, emerald_tiered = true },
  { kind = "emerald-south", item = "bw-emerald", period = 900, cap = 8, position = {x=0, y=5},  emerald_tiered = true },
}
Config.GEN_SPILL_RADIUS = 2   -- items appear within this radius of the generator
Config.GEN_CAP_RADIUS = 4    -- ground-item count checked within this radius
Config.EMERALD_TIERS = { 900, 600, 360 } -- period by tier (I/II/III)
Config.FORGE_DIVISOR = { [0]=1.0, [1]=1.5, [2]=2.0, [3]=2.5 } -- base gen period divisor

-- Item shop. price = {item=..., count=...}; currency items: iron-plate/bw-gold/bw-emerald.
Config.SHOP = {
  { give = "landfill",                 count = 10, cost = { item = "iron-plate", count = 6 } },
  { give = "stone-wall",               count = 6,  cost = { item = "iron-plate", count = 5 } },
  { give = "gate",                     count = 2,  cost = { item = "iron-plate", count = 4 } },
  { give = "bw-wall-2",                count = 4,  cost = { item = "bw-gold",    count = 4 } },
  { give = "bw-wall-3",                count = 2,  cost = { item = "bw-emerald", count = 1 } },
  { give = "firearm-magazine",         count = 10, cost = { item = "iron-plate", count = 8 } },
  { give = "shotgun-shell",            count = 10, cost = { item = "iron-plate", count = 6 } },
  { give = "piercing-rounds-magazine", count = 10, cost = { item = "bw-gold",    count = 4 } },
  { give = "piercing-shotgun-shell",   count = 5,  cost = { item = "bw-gold",    count = 3 } },
  { give = "submachine-gun",           count = 1,  cost = { item = "bw-gold",    count = 8 } },
  { give = "shotgun",                  count = 1,  cost = { item = "bw-gold",    count = 5 } },
  { give = "combat-shotgun",           count = 1,  cost = { item = "bw-emerald", count = 2 } },
  { give = "flamethrower",             count = 1,  cost = { item = "bw-emerald", count = 3 } },
  { give = "flamethrower-ammo",        count = 1,  cost = { item = "bw-emerald", count = 1 } },
  { give = "grenade",                  count = 3,  cost = { item = "bw-gold",    count = 5 } },
  { give = "cluster-grenade",          count = 1,  cost = { item = "bw-emerald", count = 1 } },
  { give = "gun-turret",               count = 1,  cost = { item = "bw-gold",    count = 10 } },
  { give = "repair-pack",              count = 2,  cost = { item = "iron-plate", count = 4 } },
  { give = "raw-fish",                 count = 3,  cost = { item = "iron-plate", count = 3 } },
  { give = "light-armor",              count = 1,  cost = { item = "iron-plate", count = 15 } },
  { give = "heavy-armor",              count = 1,  cost = { item = "bw-gold",    count = 10 } },
  { give = "power-armor",              count = 1,  cost = { item = "bw-emerald", count = 3 } },
  { give = "car",                      count = 1,  cost = { item = "bw-gold",    count = 10 } },
  { give = "solid-fuel",               count = 5,  cost = { item = "iron-plate", count = 3 } },
  { give = "defender-capsule",         count = 3,  cost = { item = "bw-emerald", count = 1 } },
  { give = "poison-capsule",           count = 2,  cost = { item = "bw-emerald", count = 1 } },
}

-- Upgrade shop: sold as hidden token items; on purchase the token is removed
-- and the effect applied team-wide. Tiered ids replace their offer; one-shots vanish.
Config.UPGRADES = {
  { id = "forge-1", token = "bw-token-forge-1", cost = { item = "bw-gold", count = 6 },   next_id = "forge-2" },
  { id = "forge-2", token = "bw-token-forge-2", cost = { item = "bw-gold", count = 12 },  next_id = "forge-3", locked = true },
  { id = "forge-3", token = "bw-token-forge-3", cost = { item = "bw-emerald", count = 3 }, locked = true },
  { id = "sharp-1", token = "bw-token-sharp-1", cost = { item = "bw-gold", count = 6 },   next_id = "sharp-2" },
  { id = "sharp-2", token = "bw-token-sharp-2", cost = { item = "bw-emerald", count = 2 }, locked = true },
  { id = "boots",   token = "bw-token-boots",   cost = { item = "bw-gold", count = 4 } },
  { id = "drill",   token = "bw-token-drill",   cost = { item = "bw-gold", count = 4 } },
  { id = "heal",    token = "bw-token-heal",    cost = { item = "bw-emerald", count = 1 } },
  { id = "fortress", token = "bw-token-fortress", cost = { item = "bw-gold", count = 8 } },
}
Config.SHARP_BONUS = { [1] = 0.3, [2] = 0.6 }     -- ammo & turret damage modifier
Config.SHARP_AMMO_CATEGORIES = { "bullet", "shotgun-shell" }
Config.BOOTS_SPEED = 0.25
Config.DRILL_MINING = 1.5
Config.HEAL_RADIUS = 12
Config.HEAL_PER_TICK30 = 1.5                       -- 3 HP/s applied every 30 ticks
Config.FORTRESS_HALF = 4                           -- 8x8 ring of bw-wall-2 around bed

Config.KIT = {
  { name = "pistol", count = 1 },
  { name = "firearm-magazine", count = 20 },
  { name = "landfill", count = 10 },
}

Config.DIFFICULTY = {
  chill   = { gen_speed = 1.4,  price_mult = 0.75, respawn_s = 8,  sudden_death_min = nil, warn_min = nil },
  classic = { gen_speed = 1.0,  price_mult = 1.0,  respawn_s = 10, sudden_death_min = 32,  warn_min = 30 },
  brutal  = { gen_speed = 0.75, price_mult = 1.0,  respawn_s = 15, sudden_death_min = 24,  warn_min = 22 },
}
Config.DIFFICULTY_ORDER = { "chill", "classic", "brutal" }
Config.DIFFICULTY_LABELS = { chill = "Chill", classic = "Classic", brutal = "Brutal" }

-- Single-player opponent. The match difficulty above controls the shared
-- economy and clock; this separate setting controls how convincingly Rivet
-- thinks and fights. Rivet still gathers visible drops and pays normal shop
-- prices at every level -- higher levels improve decisions rather than income.
Config.AI_NAME = "Rivet"
Config.AI_TICK = 1 -- walking/shooting input lasts one tick, so the brain must drive every tick
Config.AI_PICKUP_TICKS = 6
Config.AI_PICKUP_RADIUS = 2.6
Config.AI_SHOP_REACH = 3.5
Config.AI_HEAL_AMOUNT = 80
Config.AI_BRIDGE_TILE = "landfill"
Config.AI_BRIDGE_LANES = { -2, 2 }
Config.AI_PHASE_TICKS = 240
Config.AI_RESUPPLY_TICKS = 12 * 60
Config.AI_POST_RESUPPLY_MID_TICKS = 3 * 60
Config.AI_CHARACTER_MAX_HEALTH = 250
Config.AI_GUN_RANGE = 17
Config.AI_AIM_HIT_RADIUS = 0.9
Config.AI_MAGAZINE_ROUNDS = 10
Config.AI_OBSTACLE_PROBE_RADIUS = 1.4
Config.AI_BRIDGE_LOOKAHEAD = 0.95
Config.AI_ROUTE_INSET = 3
Config.AI_BED_APPROACH_MARGIN = 0.6
Config.AI_WEAPON_COOLDOWN = {
  pistol = 15, ["submachine-gun"] = 6, shotgun = 36, ["combat-shotgun"] = 20,
}
Config.AI_AMMO_DAMAGE = {
  ["firearm-magazine"] = 5, ["piercing-rounds-magazine"] = 8,
  ["shotgun-shell"] = 32, ["piercing-shotgun-shell"] = 48,
}
Config.AI_DIFFICULTY_ORDER = { "off", "rookie", "rival", "master" }
Config.AI_DIFFICULTY_LABELS = {
  off = "Off (multiplayer)",
  rookie = "Rookie",
  rival = "Rival",
  master = "Master",
}
Config.AI_DIFFICULTY_DESCRIPTIONS = {
  off = "No computer opponent. Use this when a human is on each team.",
  rookie = "Patient attacks, readable aim, modest upgrades, and slower bed breaks.",
  rival = "Balanced tactics: shops, defends, strafes, retreats, and pressures mid.",
  master = "Fast reactions, sharp aim, emerald resupply, strong upgrades, relentless defense.",
}
Config.AI_DIFFICULTY = {
  rookie = {
    reaction_ticks = 45, aim_error = 2.8, burst_on = 24, burst_off = 42,
    aggression_ticks = 150 * 60, regear_ticks = 45 * 60,
    bridge_stock = 84, ammo_stock = 30, defend_radius = 17,
    retreat_health = 0.42, strafe = false, strafe_ticks = 180,
    mid_loiter_ticks = 12 * 60,
    emerald_resupply = false, mine_interval = 18, bed_mine_damage = 38,
    melee_interval = 40, melee_damage = 8, preferred_range = 9,
    upgrade_priority = { "boots" },
  },
  rival = {
    reaction_ticks = 18, aim_error = 1.0, burst_on = 42, burst_off = 18,
    aggression_ticks = 95 * 60, regear_ticks = 28 * 60,
    bridge_stock = 94, ammo_stock = 50, defend_radius = 25,
    retreat_health = 0.30, strafe = true, strafe_ticks = 150,
    mid_loiter_ticks = 22 * 60,
    emerald_resupply = false, mine_interval = 12, bed_mine_damage = 58,
    melee_interval = 28, melee_damage = 11, preferred_range = 10,
    upgrade_priority = { "fortress", "boots", "forge-1", "drill", "sharp-1" },
  },
  master = {
    reaction_ticks = 6, aim_error = 0.22, burst_on = 72, burst_off = 8,
    aggression_ticks = 70 * 60, regear_ticks = 18 * 60,
    bridge_stock = 104, ammo_stock = 70, defend_radius = 34,
    retreat_health = 0.22, strafe = true, strafe_ticks = 90,
    mid_loiter_ticks = 42 * 60,
    emerald_resupply = true, mine_interval = 9, bed_mine_damage = 82,
    melee_interval = 20, melee_damage = 14, preferred_range = 11,
    upgrade_priority = {
      "fortress", "sharp-1", "boots", "forge-1", "drill",
      "forge-2", "sharp-2", "heal",
    },
  },
}

Config.ESCALATION = { -- minutes from start, in order; handled once each
  { min = 12, event = "emerald-2" },
  { min = 24, event = "emerald-3" },
  { min = 40, event = "draw" },
}

Config.BED_NAMES = { west = "bw-bed-west", east = "bw-bed-east" }
Config.GEN_NAME = "bw-generator"
Config.TREE_NAME = "tree-05"
Config.MARKET_ITEMS_NAME = "bw-market-items"
Config.MARKET_UPGRADES_NAME = "bw-market-upgrades"

Config.HUD_UPDATE_TICKS = 30
Config.GEN_TICK = 10          -- generator scheduler cadence
Config.CURRENCIES = { "iron-plate", "bw-gold", "bw-emerald" }

return Config
