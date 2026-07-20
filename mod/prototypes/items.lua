-- Bed Wars custom items: currencies, wall tiers, and hidden upgrade tokens.
-- Icon paths are all base-game files verified to exist. The stone-wall item's
-- real icon is graphics/icons/wall.png (there is no stone-wall.png).
local WALL_ICON = "__base__/graphics/icons/wall.png"

local items = {}

-- Currencies -----------------------------------------------------------------
items[#items + 1] = {
  type = "item",
  name = "bw-gold",
  icon = "__base__/graphics/icons/coin.png",
  icon_size = 64,
  stack_size = 200,
  subgroup = "raw-material",
  order = "z-a",
}

items[#items + 1] = {
  type = "item",
  name = "bw-emerald",
  icon = "__base__/graphics/icons/uranium-235.png",
  icon_size = 64,
  stack_size = 100,
  subgroup = "raw-material",
  order = "z-b",
}

-- Wall tiers -----------------------------------------------------------------
items[#items + 1] = {
  type = "item",
  name = "bw-wall-2",
  icons = { { icon = WALL_ICON, icon_size = 64, tint = { r = 0.55, g = 0.62, b = 0.80, a = 1 } } },
  stack_size = 50,
  place_result = "bw-wall-2",
  subgroup = "defensive-structure",
  order = "z-c",
}

items[#items + 1] = {
  type = "item",
  name = "bw-wall-3",
  icons = { { icon = WALL_ICON, icon_size = 64, tint = { r = 0.50, g = 0.30, b = 0.60, a = 1 } } },
  stack_size = 50,
  place_result = "bw-wall-3",
  subgroup = "defensive-structure",
  order = "z-d",
}

-- Hidden upgrade tokens ------------------------------------------------------
-- Purchasable from the upgrade market and removable from inventory, so only
-- `hidden = true` (no flags — "only-in-cursor" would block that).
local function token(name, icon, tint, order)
  return {
    type = "item",
    name = name,
    icons = { { icon = icon, icon_size = 64, tint = tint } },
    stack_size = 1,
    hidden = true,
    subgroup = "raw-material",
    order = order,
  }
end

items[#items + 1] = token("bw-token-forge-1", "__base__/graphics/icons/electric-furnace.png", { r = 0.85, g = 0.60, b = 0.35, a = 1 }, "z-t-a")
items[#items + 1] = token("bw-token-forge-2", "__base__/graphics/icons/electric-furnace.png", { r = 0.78, g = 0.78, b = 0.85, a = 1 }, "z-t-b")
items[#items + 1] = token("bw-token-forge-3", "__base__/graphics/icons/electric-furnace.png", { r = 1.0, g = 0.85, b = 0.35, a = 1 }, "z-t-c")
items[#items + 1] = token("bw-token-sharp-1", "__base__/graphics/icons/piercing-rounds-magazine.png", { r = 1, g = 1, b = 1, a = 1 }, "z-t-d")
items[#items + 1] = token("bw-token-sharp-2", "__base__/graphics/icons/piercing-rounds-magazine.png", { r = 1, g = 0.45, b = 0.45, a = 1 }, "z-t-e")
items[#items + 1] = token("bw-token-boots", "__base__/graphics/icons/exoskeleton-equipment.png", { r = 1, g = 1, b = 1, a = 1 }, "z-t-f")
items[#items + 1] = token("bw-token-drill", "__base__/graphics/icons/electric-mining-drill.png", { r = 1, g = 1, b = 1, a = 1 }, "z-t-g")
items[#items + 1] = token("bw-token-heal", "__base__/graphics/icons/repair-pack.png", { r = 0.5, g = 1, b = 0.5, a = 1 }, "z-t-h")
items[#items + 1] = token("bw-token-fortress", WALL_ICON, { r = 1, g = 0.85, b = 0.35, a = 1 }, "z-t-i")

data:extend(items)
