-- Bed Wars: terrain. Pure tile function + chunk paving + natural-entity wipe.
local Config = require("__bed-wars__/scenarios/bedwars/lib/config")
local M = {}

-- Pure: tile name for an integer tile position. No game state touched.
function M.tile_name_at(x, y)
  local r2 = x * x + y * y
  if r2 > Config.MAP.deepwater_radius * Config.MAP.deepwater_radius then
    return Config.TILES.void
  end
  local name = (r2 > Config.MAP.water_radius * Config.MAP.water_radius)
    and Config.TILES.deepwater or Config.TILES.water

  -- Home islands: rounded squares centered at (+-home_cx, 0).
  local half = Config.ISLANDS.home_half
  local corner = Config.ISLANDS.home_corner
  local inset = half - corner
  for _, key in pairs(Config.TEAM_ORDER) do
    local cx = Config.TEAMS[key].sign * Config.ISLANDS.home_cx
    local dx = math.abs(x - cx)
    local dy = math.abs(y)
    local ex = math.max(dx - inset, 0)
    local ey = math.max(dy - inset, 0)
    if ex * ex + ey * ey <= corner * corner and dx <= half and dy <= half then
      name = Config.TILES.home
      if dx <= Config.TILES.plaza_size and dy <= Config.TILES.plaza_size then
        name = Config.TILES.plaza
      end
      local bed_abs_x = cx + (key == "west" and Config.FURNITURE.bed.x or -Config.FURNITURE.bed.x)
      if math.abs(x - bed_abs_x) <= Config.TILES.bed_pad_half
        and math.abs(y) <= Config.TILES.bed_pad_half then
        name = Config.TILES.bed_pad
      end
    end
  end

  -- Gold islands: circles at (0, +-gold_cy).
  for _, cy in pairs({ -Config.ISLANDS.gold_cy, Config.ISLANDS.gold_cy }) do
    local gdy = y - cy
    if x * x + gdy * gdy <= Config.ISLANDS.gold_radius * Config.ISLANDS.gold_radius then
      name = Config.TILES.gold
    end
  end

  -- Mid island: circle at origin.
  if x * x + y * y <= Config.ISLANDS.mid_radius * Config.ISLANDS.mid_radius then
    name = Config.TILES.mid
    if math.abs(x) <= Config.TILES.mid_pad_half and math.abs(y) <= Config.TILES.mid_pad_half then
      name = Config.TILES.mid_pad
    end
  end

  return name
end

local function pave_area(surface, area)
  local tiles = {}
  local n = 0
  for x = area.left_top.x, area.right_bottom.x - 1 do
    for y = area.left_top.y, area.right_bottom.y - 1 do
      n = n + 1
      tiles[n] = { name = M.tile_name_at(x, y), position = { x = x, y = y } }
    end
  end
  surface.set_tiles(tiles, true)
end

function M.on_chunk_generated(e)
  local surface = e.surface
  pave_area(surface, e.area)
  for _, ent in pairs(surface.find_entities_filtered{ area = e.area }) do
    if ent.valid and ent.type ~= "character" then
      local protected = string.match(ent.name, "^bw%-")
        or (ent.force and string.match(ent.force.name, "^bw%-"))
      if not protected then ent.destroy() end
    end
  end
end

function M.prime(surface)
  surface.request_to_generate_chunks({ x = 0, y = 0 }, Config.MAP.chunk_prime_radius)
  surface.force_generate_chunk_requests()
end

-- Rematch reset: repaint every generated chunk, wiping player landfill/concrete.
function M.reset_tiles(surface)
  for chunk in surface.get_chunks() do
    pave_area(surface, chunk.area)
  end
end

return M
