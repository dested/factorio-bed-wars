-- Bed Wars team upgrades: apply token effects, keep offers current, run the heal aura.
local Config = require("__bed-wars__/scenarios/bedwars/lib/config")
local Generators = require("__bed-wars__/scenarios/bedwars/lib/generators")

local M = {}

local function pos_key(p)
  return math.floor(p.x + 0.5) .. ":" .. math.floor(p.y + 0.5)
end

function M.apply(key, id)
  local team = storage.bw.teams[key]
  local force = game.forces[team.force_name]

  if id == "forge-1" or id == "forge-2" or id == "forge-3" then
    local n = tonumber(string.sub(id, -1))
    Generators.set_forge_level(key, n)
    force.print("Forge upgraded to level " .. n .. " - generators speed up!", { color = { r = 1, g = 0.85, b = 0.3 } })

  elseif id == "sharp-1" or id == "sharp-2" then
    local n = tonumber(string.sub(id, -1))
    team.upgrades.sharp = n
    for _, cat in pairs(Config.SHARP_AMMO_CATEGORIES) do
      force.set_ammo_damage_modifier(cat, Config.SHARP_BONUS[n])
    end
    force.set_turret_attack_modifier("gun-turret", Config.SHARP_BONUS[n])
    force.print("Sharpened Rounds " .. n .. " - +" .. math.floor(Config.SHARP_BONUS[n] * 100) .. "% damage!", { color = { r = 1, g = 0.5, b = 0.4 } })

  elseif id == "boots" then
    team.upgrades.boots = true
    force.character_running_speed_modifier = Config.BOOTS_SPEED
    force.print("Swift Boots - your team moves faster!", { color = { r = 0.6, g = 1, b = 0.6 } })

  elseif id == "drill" then
    team.upgrades.drill = true
    force.manual_mining_speed_modifier = Config.DRILL_MINING
    force.print("Demolition Drill - break enemy beds and walls faster by hand!", { color = { r = 1, g = 0.7, b = 0.3 } })

  elseif id == "heal" then
    team.upgrades.heal = true
    force.print("Healing Pool active around your bed.", { color = { r = 0.5, g = 1, b = 0.7 } })

  elseif id == "fortress" then
    team.upgrades.fortress = true
    if not (team.bed and team.bed.valid) then
      force.print("Your bed is gone - fortress wasted.", { color = { r = 1, g = 0.6, b = 0.3 } })
      return
    end
    local p = team.bed.position
    local half = Config.FORTRESS_HALF
    local surface = team.bed.surface
    -- Doorway faces island center: +x for west, -x for east. Skip that face tile
    -- plus its two vertical neighbors for a 3-tile opening.
    local doorx = (key == "east") and -half or half
    local skip = {}
    skip[pos_key({ x = p.x + doorx, y = p.y })] = true
    skip[pos_key({ x = p.x + doorx, y = p.y - 1 })] = true
    skip[pos_key({ x = p.x + doorx, y = p.y + 1 })] = true
    for dx = -half, half do
      for dy = -half, half do
        if math.max(math.abs(dx), math.abs(dy)) == half then
          local tile = { x = p.x + dx, y = p.y + dy }
          if not skip[pos_key(tile)]
            and surface.can_place_entity{ name = "bw-wall-2", position = tile, force = force } then
            surface.create_entity{ name = "bw-wall-2", position = tile, force = force }
          end
        end
      end
    end
    force.print("Bed Fortress erected!", { color = { r = 0.8, g = 0.8, b = 1 } })
  end

  M.refresh_offers(key)
end

function M.refresh_offers(key)
  local team = storage.bw.teams[key]
  local m = team.market_upgrades
  if not (m and m.valid) then return end
  local diff = Config.DIFFICULTY[storage.bw.difficulty]
  m.clear_market_items()
  for _, entry in pairs(Config.UPGRADES) do
    local id = entry.id
    local available = false
    if id == "forge-1" or id == "forge-2" or id == "forge-3" then
      available = (tonumber(string.sub(id, -1)) == team.upgrades.forge + 1)
    elseif id == "sharp-1" or id == "sharp-2" then
      available = (tonumber(string.sub(id, -1)) == team.upgrades.sharp + 1)
    else
      available = not team.upgrades[id]
    end
    if available then
      m.add_market_item{
        price = { { name = entry.cost.item, count = math.max(1, math.ceil(entry.cost.count * diff.price_mult)) } },
        offer = { type = "give-item", item = entry.token, count = 1 },
      }
    end
  end
end

function M.tick()
  for _, key in pairs(Config.TEAM_ORDER) do
    local team = storage.bw.teams[key]
    if team.upgrades.heal and team.bed_alive and team.bed and team.bed.valid then
      local bp = team.bed.position
      local r2 = Config.HEAL_RADIUS * Config.HEAL_RADIUS
      for _, pl in pairs(game.connected_players) do
        if pl.force.name == team.force_name and pl.character and pl.character.valid then
          local cp = pl.character.position
          local dx = cp.x - bp.x
          local dy = cp.y - bp.y
          if dx * dx + dy * dy <= r2 then
            pl.character.health = pl.character.health + Config.HEAL_PER_TICK30
          end
        end
      end
      local ai = storage.bw.ai
      if ai and ai.enabled and ai.team == key
        and ai.character and ai.character.valid then
        local cp = ai.character.position
        local dx = cp.x - bp.x
        local dy = cp.y - bp.y
        if dx * dx + dy * dy <= r2 then
          ai.character.health = ai.character.health + Config.HEAL_PER_TICK30
        end
      end
    end
  end
end

function M.reset_force_modifiers(key)
  local force = game.forces[storage.bw.teams[key].force_name]
  for _, cat in pairs(Config.SHARP_AMMO_CATEGORIES) do
    force.set_ammo_damage_modifier(cat, 0)
  end
  force.set_turret_attack_modifier("gun-turret", 0)
  force.character_running_speed_modifier = 0
  force.manual_mining_speed_modifier = 0
end

return M
