-- Bed Wars: forces, island furniture, and player/team assignment.
local Config = require("__bed-wars__/scenarios/bedwars/lib/config")
local Util = require("__bed-wars__/scenarios/bedwars/lib/util")
local M = {}

local NO_CRAFT = "bw-no-craft"

function M.create_forces()
  for _, key in pairs(Config.TEAM_ORDER) do
    local fname = Config.TEAMS[key].force_name
    if not game.forces[fname] then
      game.create_force(fname)
    end
  end

  local west = game.forces[Config.TEAMS.west.force_name]
  local east = game.forces[Config.TEAMS.east.force_name]
  west.set_friend(east, false)
  west.set_cease_fire(east, false)
  east.set_friend(west, false)
  east.set_cease_fire(west, false)

  local player_force = game.forces.player
  for _, f in pairs({ west, east }) do
    f.set_friend(player_force, true)
    f.set_cease_fire(player_force, true)
    player_force.set_friend(f, true)
    player_force.set_cease_fire(f, true)
    f.disable_research()
    f.share_chart = true
  end
  player_force.disable_research()

  if not game.permissions.get_group(NO_CRAFT) then
    local group = game.permissions.create_group(NO_CRAFT)
    group.set_allows_action(defines.input_action.craft, false)
    group.set_allows_action(defines.input_action.cancel_craft, false)
  end
end

function M.setup_islands(surface)
  for _, key in pairs(Config.TEAM_ORDER) do
    local team = storage.bw.teams[key]
    local force = game.forces[team.force_name]
    local F = Config.FURNITURE

    local function clear_at(pos)
      for _, ent in pairs(surface.find_entities_filtered{ position = pos, radius = 1 }) do
        if ent.valid and ent.type ~= "character" then ent.destroy() end
      end
    end

    -- Bed: damageable AND minable. Force must be NEUTRAL: players can never
    -- mine enemy-force entities; ownership is carried by the prototype name
    -- (bw-bed-west/east), not the force.
    local bed_pos = Util.team_pos(key, F.bed)
    clear_at(bed_pos)
    local bed = surface.create_entity{ name = Config.BED_NAMES[key], position = bed_pos, force = "neutral" }
    team.bed = bed
    team.bed_alive = true

    local spawn_pos = Util.team_pos(key, F.spawn)
    team.spawn = spawn_pos
    force.set_spawn_position(spawn_pos, surface)

    local mi_pos = Util.team_pos(key, F.market_items)
    clear_at(mi_pos)
    local market_items = surface.create_entity{ name = Config.MARKET_ITEMS_NAME, position = mi_pos, force = team.force_name }
    market_items.destructible = false
    market_items.minable_flag = false
    team.market_items = market_items

    local mu_pos = Util.team_pos(key, F.market_upgrades)
    clear_at(mu_pos)
    local market_upgrades = surface.create_entity{ name = Config.MARKET_UPGRADES_NAME, position = mu_pos, force = team.force_name }
    market_upgrades.destructible = false
    market_upgrades.minable_flag = false
    team.market_upgrades = market_upgrades

    local chest_pos = Util.team_pos(key, F.chest)
    clear_at(chest_pos)
    local chest = surface.create_entity{ name = "steel-chest", position = chest_pos, force = team.force_name }
    chest.destructible = false
    chest.minable_flag = false
    team.chest = chest

    for _, toff in pairs(F.trees) do
      local tpos = Util.team_pos(key, toff)
      clear_at(tpos)
      if surface.can_place_entity{ name = Config.TREE_NAME, position = tpos } then
        surface.create_entity{ name = Config.TREE_NAME, position = tpos }
      end
    end
  end
end

function M.assign(player, key)
  local team = storage.bw.teams[key]
  player.force = game.forces[team.force_name]
  player.color = Config.TEAMS[key].color

  local present = false
  for _, idx in pairs(team.players) do
    if idx == player.index then present = true break end
  end
  if not present then table.insert(team.players, player.index) end

  local other = storage.bw.teams[Util.enemy_key(key)].players
  for i = #other, 1, -1 do
    if other[i] == player.index then table.remove(other, i) end
  end

  game.permissions.get_group(NO_CRAFT).add_player(player)
end

function M.give_kit(player)
  for _, item in pairs(Config.KIT) do
    player.insert{ name = item.name, count = item.count }
  end
end

function M.make_spectator(player)
  if player.character then
    local c = player.character
    player.set_controller{ type = defines.controllers.spectator }
    c.destroy()
  else
    player.set_controller{ type = defines.controllers.spectator }
  end
  player.teleport({ x = 0, y = -24 }, game.surfaces[Config.SURFACE])
end

function M.spawn_character(player, key)
  local surface = game.surfaces[Config.SURFACE]
  local team = storage.bw.teams[key]
  local pos = surface.find_non_colliding_position("character", team.spawn, 8, 0.5) or team.spawn
  local c = surface.create_entity{ name = "character", position = pos, force = team.force_name }
  player.teleport(pos, surface)
  player.set_controller{ type = defines.controllers.character, character = c }
end

return M
