-- Bed Wars resource generators: placement, spawn cadence, forge/emerald scaling.
local Config = require("__bed-wars__/scenarios/bedwars/lib/config")
local Util = require("__bed-wars__/scenarios/bedwars/lib/util")

local M = {}

local function pos_key(p)
  return math.floor(p.x + 0.5) .. ":" .. math.floor(p.y + 0.5)
end

-- Place every generator entity and register a gens row per (kind x team) / per neutral.
-- Multiple per-team gens share offset {0,0}, so only one physical bw-generator is
-- created per island center; every base row points at that same entity.
function M.place_all(surface)
  local cache = {}
  local function get_entity(pos, force)
    local k = pos_key(pos)
    local ent = cache[k]
    if not ent then
      ent = surface.create_entity{ name = Config.GEN_NAME, position = pos, force = force }
      if ent then
        ent.destructible = false
        ent.minable_flag = false
      end
      cache[k] = ent
    end
    return ent
  end

  for _, entry in pairs(Config.GENERATORS) do
    if entry.per_team then
      for _, key in pairs(Config.TEAM_ORDER) do
        local ent = get_entity(Util.team_pos(key, entry.offset), Config.TEAMS[key].force_name)
        storage.bw.gens[#storage.bw.gens + 1] = {
          ent = ent, item = entry.item, period = entry.period, cap = entry.cap,
          kind = entry.kind, team = key, next_tick = 0,
          active = not entry.forge3_only, emerald_tiered = entry.emerald_tiered or false,
        }
      end
    else
      local ent = get_entity(entry.position, "neutral")
      storage.bw.gens[#storage.bw.gens + 1] = {
        ent = ent, item = entry.item, period = entry.period, cap = entry.cap,
        kind = entry.kind, team = nil, next_tick = 0,
        active = not entry.forge3_only, emerald_tiered = entry.emerald_tiered or false,
      }
    end
  end
end

function M.tick()
  if storage.bw.state ~= "active" then return end
  local t = game.tick
  local diff = Config.DIFFICULTY[storage.bw.difficulty]
  for _, g in pairs(storage.bw.gens) do
    if g.active and g.ent and g.ent.valid then
      local base = (g.emerald_tiered and Config.EMERALD_TIERS[storage.bw.emerald_tier]) or g.period
      local divisor = diff.gen_speed * (g.team and Config.FORGE_DIVISOR[storage.bw.teams[g.team].upgrades.forge] or 1)
      local eff = math.max(10, math.floor(base / divisor))
      if t >= g.next_tick then
        local surface = g.ent.surface
        local sum = 0
        local ground = surface.find_entities_filtered{
          name = "item-on-ground", position = g.ent.position, radius = Config.GEN_CAP_RADIUS,
        }
        for _, e in pairs(ground) do
          local stack = e.stack
          if stack and stack.valid_for_read and stack.name == g.item then
            sum = sum + stack.count
          end
        end
        if sum < g.cap then
          surface.spill_item_stack{
            position = g.ent.position, stack = { name = g.item, count = 1 },
            enable_looted = true, allow_belts = false, max_radius = Config.GEN_SPILL_RADIUS,
          }
        end
        g.next_tick = t + eff
      end
    end
  end
end

function M.set_forge_level(key, lvl)
  storage.bw.teams[key].upgrades.forge = lvl
  if lvl >= 3 then
    for _, g in pairs(storage.bw.gens) do
      if g.team == key and g.kind == "base-emerald" then
        g.active = true
      end
    end
  end
end

function M.escalate(tier)
  storage.bw.emerald_tier = tier
end

return M
