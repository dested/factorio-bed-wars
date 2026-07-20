-- Bed Wars entities: beds, resource generator, upgrade/item markets, wall tiers.
local util = require("util")

local entities = {}

-- Beds -----------------------------------------------------------------------
-- simple-entity-with-force so they carry a team force and show a map color.
-- is_military_target=false keeps turrets from shooting them; the enemy must
-- hand-mine the bed to break it (3 s channel).
local function bed(name, sprite, icon, color)
  return {
    type = "simple-entity-with-force",
    name = name,
    icon = icon,
    icon_size = 64,
    max_health = 500,
    is_military_target = false,
    collision_box = { { -0.9, -0.9 }, { 0.9, 0.9 } },
    selection_box = { { -1, -1 }, { 1, 1 } },
    minable = { mining_time = 3, results = {} },
    flags = { "placeable-neutral" },
    map_color = color,
    render_layer = "object",
    picture = { filename = sprite, width = 128, height = 128, scale = 0.5 },
  }
end

entities[#entities + 1] = bed(
  "bw-bed-west",
  "__bed-wars__/graphics/bw-bed-blue.png",
  "__bed-wars__/graphics/bw-bed-icon-blue.png",
  { r = 0.2, g = 0.5, b = 1 }
)
entities[#entities + 1] = bed(
  "bw-bed-east",
  "__bed-wars__/graphics/bw-bed-red.png",
  "__bed-wars__/graphics/bw-bed-icon-red.png",
  { r = 1, g = 0.25, b = 0.25 }
)

-- Resource generator marker --------------------------------------------------
entities[#entities + 1] = {
  type = "simple-entity-with-force",
  name = "bw-generator",
  icon = "__bed-wars__/graphics/bw-generator-icon.png",
  icon_size = 64,
  max_health = 1000,
  is_military_target = false,
  collision_box = { { -0.4, -0.4 }, { 0.4, 0.4 } },
  selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
  flags = { "placeable-neutral" },
  render_layer = "object",
  picture = { filename = "__bed-wars__/graphics/bw-generator.png", width = 64, height = 96, scale = 0.5, shift = { 0, -0.5 } },
}

-- Markets --------------------------------------------------------------------
local function market(name, sprite, icon)
  return {
    type = "market",
    name = name,
    icon = icon,
    icon_size = 64,
    max_health = 1000,
    collision_box = { { -1.2, -1.2 }, { 1.2, 1.2 } },
    selection_box = { { -1.5, -1.5 }, { 1.5, 1.5 } },
    flags = { "placeable-neutral", "player-creation" },
    allow_access_to_all_forces = true,
    picture = { filename = sprite, width = 192, height = 192, scale = 0.5, shift = { 0, -0.35 } },
  }
end

entities[#entities + 1] = market(
  "bw-market-items",
  "__bed-wars__/graphics/bw-market-items.png",
  "__bed-wars__/graphics/bw-market-items-icon.png"
)
entities[#entities + 1] = market(
  "bw-market-upgrades",
  "__bed-wars__/graphics/bw-market-upgrades.png",
  "__bed-wars__/graphics/bw-market-upgrades-icon.png"
)

-- Wall tiers -----------------------------------------------------------------
-- Recursively tint every sprite (any table carrying a `filename` key) inside a
-- wall's `pictures` struct.
local function tint_pictures(node, tint)
  if type(node) ~= "table" then return end
  if node.filename then node.tint = tint end
  for _, v in pairs(node) do tint_pictures(v, tint) end
end

local function make_wall(name, item_name, hp, tint)
  local w = util.table.deepcopy(data.raw.wall["stone-wall"])
  w.name = name
  w.max_health = hp
  w.next_upgrade = nil
  w.minable = { mining_time = 0.4, results = { { type = "item", name = item_name, amount = 1 } } }
  tint_pictures(w.pictures, tint)
  return w
end

entities[#entities + 1] = make_wall("bw-wall-2", "bw-wall-2", 1500, { r = 0.55, g = 0.62, b = 0.80, a = 1 })
entities[#entities + 1] = make_wall("bw-wall-3", "bw-wall-3", 5000, { r = 0.50, g = 0.30, b = 0.60, a = 1 })

data:extend(entities)
