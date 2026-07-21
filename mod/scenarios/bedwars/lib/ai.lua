-- Bed Wars single-player opponent.
--
-- Rivet is a real script-controlled character: walking and gunfire use the
-- same character inputs as a player, resources are picked up from visible
-- ground stacks, and every item/upgrade is paid for from Config's shop tables.
-- The state machine handles economy, bridging, mid control, defense, retreats,
-- bed pressure, death, and respawning without granting hidden resources.
local Config = require("__bed-wars__/scenarios/bedwars/lib/config")
local Util = require("__bed-wars__/scenarios/bedwars/lib/util")
local Upgrades = require("__bed-wars__/scenarios/bedwars/lib/upgrades")

local M = {}

local SHOP_BY_ITEM = {}
for _, offer in pairs(Config.SHOP) do SHOP_BY_ITEM[offer.give] = offer end

local UPGRADE_BY_ID = {}
for _, entry in pairs(Config.UPGRADES) do UPGRADE_BY_ID[entry.id] = entry end

local WATER_TILES = {
  [Config.TILES.water] = true,
  [Config.TILES.deepwater] = true,
}

local function distance_sq(a, b)
  local dx = a.x - b.x
  local dy = a.y - b.y
  return dx * dx + dy * dy
end

local function distance(a, b)
  return math.sqrt(distance_sq(a, b))
end

local function close_to(a, b, radius)
  return distance_sq(a, b) <= radius * radius
end

local function random_unit()
  return storage.bw.rng(-1000, 1000) / 1000
end

function M.new_state(difficulty)
  return {
    difficulty = difficulty or "rival",
    enabled = false,
    team = nil,
    character = nil,
    state = "disabled",
    state_tick = 0,
    last_spawn_tick = nil,
    spawn_count = 0,
    respawn_tick = nil,
    eliminated = false,
    lane = Config.AI_BRIDGE_LANES[1],
    route = nil,
    route_index = 1,
    route_next = nil,
    resume_state = nil,
    threat_player = nil,
    aim = nil,
    aim_tick = 0,
    strafe_sign = 1,
    next_melee_tick = 0,
    next_mine_tick = 0,
    next_shot_tick = 0,
    loaded_ammo_name = nil,
    rounds_left = 0,
    reached_mid = false,
    reached_enemy = false,
    resupply_done = false,
    resupply_pending = false,
    assault_flanked = false,
    assault_approached = false,
    stats = { collected = 0, spent = 0, bridge_tiles = 0, deaths = 0 },
  }
end

local function connected_team_count(key)
  local count = 0
  for _, player_index in pairs(storage.bw.teams[key].players) do
    local player = game.get_player(player_index)
    if player and player.valid and player.connected then count = count + 1 end
  end
  return count
end

-- The AI always occupies an otherwise empty side. This makes the default
-- one-player lobby single-player while automatically preserving human 1v1.
function M.planned_team()
  local ai = storage.bw.ai
  if not ai or ai.difficulty == "off" then return nil end
  local west = connected_team_count("west")
  local east = connected_team_count("east")
  if west > 0 and east == 0 then return "east" end
  if east > 0 and west == 0 then return "west" end
  if west == 0 and east == 0 then return "east" end
  return nil
end

local function stop_walking(character)
  if character and character.valid then
    character.walking_state = { walking = false, direction = defines.direction.north }
  end
end

local function stop_shooting(character)
  if character and character.valid then
    character.shooting_state = {
      state = defines.shooting.not_shooting,
      position = character.position,
    }
  end
end

local function main_inventory(character)
  return character.get_inventory(defines.inventory.character_main)
end

local function put_in_main(character, name, count)
  local inventory = main_inventory(character)
  if not inventory then return 0 end
  return inventory.insert{ name = name, count = count }
end

local function equip_item(character, inventory_id, slot_index, name)
  local inventory = character.get_inventory(inventory_id)
  local main = main_inventory(character)
  if not (inventory and main) then return false end
  local slot = inventory[slot_index]
  if slot.valid_for_read and slot.name == name then return true end
  if main.get_item_count(name) == 0 then return false end
  if slot.valid_for_read then
    main.insert{ name = slot.name, count = slot.count }
    slot.clear()
  end
  if main.remove{ name = name, count = 1 } == 1 then
    slot.set_stack{ name = name, count = 1 }
    return true
  end
  return false
end

local function load_ammo(character, slot_index, choices)
  local ammo = character.get_inventory(defines.inventory.character_ammo)
  local main = main_inventory(character)
  if not (ammo and main) then return false end
  local slot = ammo[slot_index]

  local desired = nil
  for _, name in pairs(choices) do
    if (slot.valid_for_read and slot.name == name) or main.get_item_count(name) > 0 then
      desired = name
      break
    end
  end
  if not desired then return false end

  if slot.valid_for_read and slot.name ~= desired then
    main.insert{ name = slot.name, count = slot.count }
    slot.clear()
  end

  if not slot.valid_for_read then
    local available = main.get_item_count(desired)
    if available > 0 then
      local take = math.min(available, prototypes.item[desired].stack_size)
      main.remove{ name = desired, count = take }
      slot.set_stack{ name = desired, count = take }
    end
  elseif slot.name == desired then
    local room = slot.prototype.stack_size - slot.count
    local take = math.min(room, main.get_item_count(desired))
    if take > 0 then
      main.remove{ name = desired, count = take }
      slot.count = slot.count + take
    end
  end
  return slot.valid_for_read
end

local function equip_armor(character)
  local armor = character.get_inventory(defines.inventory.character_armor)
  local main = main_inventory(character)
  if not (armor and main) then return end
  local desired = nil
  for _, name in pairs({ "power-armor", "heavy-armor", "light-armor" }) do
    if (armor[1].valid_for_read and armor[1].name == name)
      or main.get_item_count(name) > 0 then
      desired = name
      break
    end
  end
  if not desired or (armor[1].valid_for_read and armor[1].name == desired) then return end
  if armor[1].valid_for_read then
    main.insert{ name = armor[1].name, count = 1 }
    armor[1].clear()
  end
  if main.remove{ name = desired, count = 1 } == 1 then
    armor[1].set_stack{ name = desired, count = 1 }
  end
end

local function equip_loadout(character)
  local main = main_inventory(character)
  if not main then return end

  if main.get_item_count("submachine-gun") > 0 then
    equip_item(character, defines.inventory.character_guns, 1, "submachine-gun")
  elseif main.get_item_count("pistol") > 0 then
    equip_item(character, defines.inventory.character_guns, 1, "pistol")
  end
  if main.get_item_count("combat-shotgun") > 0 then
    equip_item(character, defines.inventory.character_guns, 2, "combat-shotgun")
  elseif main.get_item_count("shotgun") > 0 then
    equip_item(character, defines.inventory.character_guns, 2, "shotgun")
  end

  local bullet_loaded = load_ammo(character, 1, {
    "piercing-rounds-magazine", "firearm-magazine",
  })
  local shells_loaded = load_ammo(character, 2, {
    "piercing-shotgun-shell", "shotgun-shell",
  })
  equip_armor(character)

  local guns = character.get_inventory(defines.inventory.character_guns)
  if shells_loaded and guns[2].valid_for_read then
    character.selected_gun_index = 2
  elseif bullet_loaded and guns[1].valid_for_read then
    character.selected_gun_index = 1
  end
end

local function give_spawn_kit(character)
  local guns = character.get_inventory(defines.inventory.character_guns)
  local ammo = character.get_inventory(defines.inventory.character_ammo)
  guns[1].set_stack{ name = "pistol", count = 1 }
  ammo[1].set_stack{ name = "firearm-magazine", count = 20 }
  put_in_main(character, "landfill", 10)
  character.selected_gun_index = 1
end

local function spawn_character(ai)
  local surface = game.surfaces[Config.SURFACE]
  local team = storage.bw.teams[ai.team]
  local pos = surface.find_non_colliding_position("character", team.spawn, 8, 0.5)
    or team.spawn
  local character = surface.create_entity{
    name = "character",
    position = pos,
    force = team.force_name,
  }
  if not character then return false end

  character.color = Config.TEAMS[ai.team].color
  character.picking_state = true
  give_spawn_kit(character)
  ai.character = character
  ai.spawn_count = ai.spawn_count + 1
  ai.last_spawn_tick = game.tick
  ai.respawn_tick = nil
  ai.state = "prepare"
  ai.state_tick = game.tick
  ai.route = nil
  ai.route_index = 1
  ai.aim = nil
  ai.threat_player = nil
  ai.resupply_pending = false
  return true
end

function M.start()
  local old = storage.bw.ai or M.new_state("rival")
  local ai = M.new_state(old.difficulty)
  storage.bw.ai = ai
  if ai.difficulty == "off" then return false end

  ai.team = M.planned_team()
  if not ai.team then
    -- A human already occupies both sides. Human multiplayer wins cleanly.
    return false
  end
  ai.enabled = true
  ai.lane = Config.AI_BRIDGE_LANES[storage.bw.rng(1, #Config.AI_BRIDGE_LANES)]
  if not spawn_character(ai) then
    ai.enabled = false
    return false
  end

  Util.announce(Config.AI_NAME .. " joined " .. Config.TEAMS[ai.team].display
    .. " (" .. Config.AI_DIFFICULTY_LABELS[ai.difficulty] .. " AI).",
    Config.TEAMS[ai.team].color, "utility/console_message")
  return true
end

function M.reset()
  local old = storage.bw.ai
  local difficulty = old and old.difficulty or "rival"
  if old and old.character and old.character.valid then old.character.destroy() end
  storage.bw.ai = M.new_state(difficulty)
end

local function collect_ground_items(ai)
  local character = ai.character
  local inventory = main_inventory(character)
  if not inventory then return end
  local items = character.surface.find_entities_filtered{
    name = "item-on-ground",
    position = character.position,
    radius = Config.AI_PICKUP_RADIUS,
  }
  for _, item in pairs(items) do
    if item.valid and item.stack and item.stack.valid_for_read then
      local count = item.stack.count
      local inserted = inventory.insert{ name = item.stack.name, count = count }
      if inserted > 0 then
        ai.stats.collected = ai.stats.collected + inserted
        if inserted >= count then
          item.destroy()
        else
          item.stack.count = count - inserted
        end
      end
    end
  end
end

local function effective_price(cost)
  local multiplier = Config.DIFFICULTY[storage.bw.difficulty].price_mult
  return math.max(1, math.ceil(cost.count * multiplier))
end

local function buy_item(ai, name)
  local offer = SHOP_BY_ITEM[name]
  local character = ai.character
  if not offer or not (character and character.valid) then return false end
  local price = effective_price(offer.cost)
  if character.get_item_count(offer.cost.item) < price then return false end
  local inventory = main_inventory(character)
  if not inventory or not inventory.can_insert{ name = name, count = offer.count } then
    return false
  end
  character.remove_item{ name = offer.cost.item, count = price }
  inventory.insert{ name = name, count = offer.count }
  ai.stats.spent = ai.stats.spent + price
  return true
end

local function has_armor(character)
  local armor = character.get_inventory(defines.inventory.character_armor)
  return armor and armor[1].valid_for_read
end

local function total_bullet_ammo(character)
  return character.get_item_count("firearm-magazine")
    + character.get_item_count("piercing-rounds-magazine")
end

local function buy_item_loadout(ai)
  local character = ai.character
  local settings = Config.AI_DIFFICULTY[ai.difficulty]

  if not has_armor(character) then buy_item(ai, "light-armor") end

  local guard = 0
  while character.get_item_count("landfill") < settings.bridge_stock
    and guard < 16 and buy_item(ai, "landfill") do
    guard = guard + 1
  end

  guard = 0
  while total_bullet_ammo(character) < settings.ammo_stock
    and guard < 8 and buy_item(ai, "firearm-magazine") do
    guard = guard + 1
  end

  if character.get_item_count("raw-fish") < 3 then buy_item(ai, "raw-fish") end
  if character.get_item_count("submachine-gun") == 0 then
    buy_item(ai, "submachine-gun")
  end

  if ai.difficulty ~= "rookie" then
    local armor = character.get_inventory(defines.inventory.character_armor)
    if storage.bw.teams[ai.team].upgrades.fortress
      and not (armor[1].valid_for_read
      and (armor[1].name == "heavy-armor" or armor[1].name == "power-armor")) then
      buy_item(ai, "heavy-armor")
    end
    if character.get_item_count("piercing-rounds-magazine") < 20 then
      buy_item(ai, "piercing-rounds-magazine")
    end
  end

  if ai.difficulty == "master"
    and (ai.resupply_done or ai.state == "resupply") then
    if character.get_item_count("combat-shotgun") == 0 then
      buy_item(ai, "combat-shotgun")
    end
    if character.get_item_count("piercing-shotgun-shell") < 10 then
      buy_item(ai, "piercing-shotgun-shell")
      buy_item(ai, "piercing-shotgun-shell")
    end
    local armor = character.get_inventory(defines.inventory.character_armor)
    if not (armor[1].valid_for_read and armor[1].name == "power-armor") then
      buy_item(ai, "power-armor")
    end
  end

  equip_loadout(character)
end

local function upgrade_available(ai, id)
  local upgrades = storage.bw.teams[ai.team].upgrades
  if string.sub(id, 1, 6) == "forge-" then
    return tonumber(string.sub(id, -1)) == upgrades.forge + 1
  elseif string.sub(id, 1, 6) == "sharp-" then
    return tonumber(string.sub(id, -1)) == upgrades.sharp + 1
  end
  return upgrades[id] == false
end

local function buy_upgrade(ai, id)
  local entry = UPGRADE_BY_ID[id]
  local character = ai.character
  if not entry or not upgrade_available(ai, id) then return false end
  local price = effective_price(entry.cost)
  if character.get_item_count(entry.cost.item) < price then return false end
  character.remove_item{ name = entry.cost.item, count = price }
  ai.stats.spent = ai.stats.spent + price
  Upgrades.apply(ai.team, id)
  return true
end

local function buy_team_upgrades(ai)
  local settings = Config.AI_DIFFICULTY[ai.difficulty]
  for _, id in pairs(settings.upgrade_priority) do buy_upgrade(ai, id) end
end

local function direction_for(dx, dy)
  local ax = math.abs(dx)
  local ay = math.abs(dy)
  if ax < 0.25 then
    return dy < 0 and defines.direction.north or defines.direction.south
  elseif ay < 0.25 then
    return dx < 0 and defines.direction.west or defines.direction.east
  elseif dx > 0 and dy > 0 then
    return defines.direction.southeast
  elseif dx > 0 and dy < 0 then
    return defines.direction.northeast
  elseif dx < 0 and dy > 0 then
    return defines.direction.southwest
  end
  return defines.direction.northwest
end

local function loaded_weapon(character)
  local guns = character.get_inventory(defines.inventory.character_guns)
  local ammo = character.get_inventory(defines.inventory.character_ammo)
  local slot = character.selected_gun_index
  return guns and ammo and guns[slot].valid_for_read and ammo[slot].valid_for_read
end

local function shoot_at(character, position)
  character.shooting_state = {
    state = defines.shooting.shooting_selected,
    position = position,
  }
end

local function weapon_profile(character)
  local guns = character.get_inventory(defines.inventory.character_guns)
  local ammo = character.get_inventory(defines.inventory.character_ammo)
  local slot_index = character.selected_gun_index
  local gun = guns and guns[slot_index]
  local magazine = ammo and ammo[slot_index]
  if not (gun and gun.valid_for_read and magazine and magazine.valid_for_read) then
    return nil
  end

  local damage = Config.AI_AMMO_DAMAGE[magazine.name]
  local cooldown = Config.AI_WEAPON_COOLDOWN[gun.name]
  local category = "bullet"
  if gun.name == "shotgun" or gun.name == "combat-shotgun" then
    category = "shotgun-shell"
  end
  if not damage or not cooldown then return nil end
  return {
    gun = gun.name,
    ammo = magazine.name,
    slot = slot_index,
    damage = damage,
    cooldown = cooldown,
    category = category,
  }
end

local function consume_round(ai, profile)
  local ammo = ai.character.get_inventory(defines.inventory.character_ammo)
  local stack = ammo and ammo[profile.slot]
  if not (stack and stack.valid_for_read) then return false end
  if ai.loaded_ammo_name ~= profile.ammo or ai.rounds_left <= 0 then
    ai.loaded_ammo_name = profile.ammo
    ai.rounds_left = Config.AI_MAGAZINE_ROUNDS
    if stack.count <= 1 then
      stack.clear()
    else
      stack.count = stack.count - 1
    end
  end
  ai.rounds_left = ai.rounds_left - 1
  return true
end

-- Script-owned characters accept shooting_state but do not advance the base
-- gun attack. Resolve the equipped weapon here while preserving its inventory,
-- cadence, ammo use, aim error, resistances, force attribution, and animation.
local function fire_weapon(ai, target, aim, force_hit)
  if game.tick < ai.next_shot_tick or not (target and target.valid) then return end
  local profile = weapon_profile(ai.character)
  if not profile or not consume_round(ai, profile) then return end
  ai.next_shot_tick = game.tick + profile.cooldown

  local sharp = storage.bw.teams[ai.team].upgrades.sharp
  local damage = profile.damage * (1 + (Config.SHARP_BONUS[sharp] or 0))
  local hit = force_hit
    or close_to(aim, target.position, Config.AI_AIM_HIT_RADIUS)
  local impact = hit and target.position or aim
  target.surface.create_entity{
    name = "explosion-gunshot", position = impact, target = target,
  }
  if hit and target.valid then
    target.damage(damage, ai.character.force, "physical",
      ai.character, ai.character)
  end
end

local function attack_obstacle(ai, obstacle)
  local character = ai.character
  stop_walking(character)
  equip_loadout(character)
  if loaded_weapon(character) then
    shoot_at(character, obstacle.position)
    fire_weapon(ai, obstacle, obstacle.position, true)
  elseif close_to(character.position, obstacle.position, 2.0)
    and game.tick >= ai.next_melee_tick then
    ai.next_melee_tick = game.tick + Config.AI_DIFFICULTY[ai.difficulty].melee_interval
    obstacle.damage(
      Config.AI_DIFFICULTY[ai.difficulty].melee_damage,
      character.force,
      "physical",
      character,
      character
    )
  end
end

local function obstacle_ahead(ai, position)
  for _, entity in pairs(ai.character.surface.find_entities_filtered{
    position = position,
    -- Character + wall collision boxes stop the center just before a tighter
    -- probe would overlap the wall's entity position.
    radius = Config.AI_OBSTACLE_PROBE_RADIUS,
  }) do
    if entity.valid and (entity.type == "wall" or entity.type == "gate")
      and entity.force.name ~= ai.character.force.name then
      return entity
    end
  end
  return nil
end

local function build_ahead(ai, dx, dy)
  local character = ai.character
  local length = math.sqrt(dx * dx + dy * dy)
  if length == 0 then return true end
  local tile_pos = {
    x = math.floor(character.position.x
      + dx / length * Config.AI_BRIDGE_LOOKAHEAD),
    y = math.floor(character.position.y
      + dy / length * Config.AI_BRIDGE_LOOKAHEAD),
  }
  local tile = character.surface.get_tile(tile_pos)
  if not WATER_TILES[tile.name] then return true end
  if character.get_item_count("landfill") == 0 then return false end
  if character.remove_item{ name = "landfill", count = 1 } ~= 1 then return false end
  character.surface.set_tiles({
    { name = Config.AI_BRIDGE_TILE, position = tile_pos },
  }, true)
  ai.stats.bridge_tiles = ai.stats.bridge_tiles + 1
  return true
end

local function walk_to(ai, target, stop_radius)
  local character = ai.character
  local dx = target.x - character.position.x
  local dy = target.y - character.position.y
  local d = math.sqrt(dx * dx + dy * dy)
  if d <= (stop_radius or 0.65) then
    stop_walking(character)
    return true
  end

  local ahead = {
    x = character.position.x + dx / d * 0.75,
    y = character.position.y + dy / d * 0.75,
  }
  local obstacle = obstacle_ahead(ai, ahead)
  if obstacle then
    attack_obstacle(ai, obstacle)
    return false
  end
  if not build_ahead(ai, dx, dy) then
    stop_walking(character)
    return false
  end
  character.walking_state = {
    walking = true,
    direction = direction_for(dx, dy),
  }
  return false
end

local function set_route(ai, points, next_state)
  ai.state = "route"
  ai.state_tick = game.tick
  ai.route = points
  ai.route_index = 1
  ai.route_next = next_state
end

local function route_to_mid(ai)
  local sign = Config.TEAMS[ai.team].sign
  local home_inner = Config.ISLANDS.home_cx - Config.ISLANDS.home_half
    + Config.AI_ROUTE_INSET
  local mid_edge = Config.ISLANDS.mid_radius - Config.AI_ROUTE_INSET
  set_route(ai, {
    { x = sign * home_inner, y = ai.lane },
    { x = sign * mid_edge, y = ai.lane },
  }, "mid")
end

local function route_to_enemy(ai)
  local sign = Config.TEAMS[ai.team].sign
  local home_inner = Config.ISLANDS.home_cx - Config.ISLANDS.home_half
    + Config.AI_ROUTE_INSET
  local mid_edge = Config.ISLANDS.mid_radius - Config.AI_ROUTE_INSET
  set_route(ai, {
    { x = -sign * mid_edge, y = ai.lane },
    { x = -sign * home_inner, y = ai.lane },
  }, "assault")
  ai.assault_flanked = false
  ai.assault_approached = false
end

local function route_home(ai, next_state)
  local sign = Config.TEAMS[ai.team].sign
  local x = ai.character.position.x * sign
  local home_inner = Config.ISLANDS.home_cx - Config.ISLANDS.home_half
    + Config.AI_ROUTE_INSET
  local mid_edge = Config.ISLANDS.mid_radius - Config.AI_ROUTE_INSET
  local points = {}
  if x < -Config.ISLANDS.mid_radius then
    points[#points + 1] = { x = -sign * home_inner, y = ai.lane }
    points[#points + 1] = { x = -sign * mid_edge, y = ai.lane }
  end
  if x < Config.ISLANDS.mid_radius then
    points[#points + 1] = { x = sign * mid_edge, y = ai.lane }
  end
  points[#points + 1] = { x = sign * home_inner, y = ai.lane }
  points[#points + 1] = Util.team_pos(ai.team, Config.FURNITURE.base_gen)
  set_route(ai, points, next_state or "prepare")
end

local function enter_state(ai, state)
  ai.state = state
  ai.state_tick = game.tick
  ai.route = nil
  ai.route_index = 1
  ai.route_next = nil
  stop_walking(ai.character)
end

local function follow_route(ai)
  local target = ai.route and ai.route[ai.route_index]
  if not target then
    local next_state = ai.route_next or "prepare"
    enter_state(ai, next_state)
    if next_state == "mid" then ai.reached_mid = true end
    if next_state == "assault" then ai.reached_enemy = true end
    return
  end
  if walk_to(ai, target, 0.75) then ai.route_index = ai.route_index + 1 end
end

local function player_character(player_index)
  if not player_index then return nil end
  local player = game.get_player(player_index)
  if player and player.valid and player.connected
    and player.character and player.character.valid then
    return player.character
  end
  return nil
end

local function nearest_enemy(ai)
  local best_player, best_character, best_distance = nil, nil, nil
  for _, player in pairs(game.connected_players) do
    if player.character and player.character.valid
      and player.force.name ~= ai.character.force.name then
      local d = distance_sq(ai.character.position, player.character.position)
      if not best_distance or d < best_distance then
        best_player, best_character, best_distance = player, player.character, d
      end
    end
  end
  return best_player, best_character, best_distance and math.sqrt(best_distance) or nil
end

local function acquire_aim(ai, target)
  local settings = Config.AI_DIFFICULTY[ai.difficulty]
  if not ai.aim or game.tick >= ai.aim_tick then
    ai.aim_tick = game.tick + settings.reaction_ticks
    ai.aim = {
      x = target.position.x + random_unit() * settings.aim_error,
      y = target.position.y + random_unit() * settings.aim_error,
    }
  end
  return ai.aim
end

local function melee_target(ai, target)
  local settings = Config.AI_DIFFICULTY[ai.difficulty]
  if close_to(ai.character.position, target.position, 1.65)
    and game.tick >= ai.next_melee_tick then
    ai.next_melee_tick = game.tick + settings.melee_interval
    target.damage(settings.melee_damage, ai.character.force, "physical",
      ai.character, ai.character)
  end
end

local function fight_target(ai, target)
  local character = ai.character
  local settings = Config.AI_DIFFICULTY[ai.difficulty]
  local d = distance(character.position, target.position)
  equip_loadout(character)

  if loaded_weapon(character) and d <= Config.AI_GUN_RANGE then
    local cycle = settings.burst_on + settings.burst_off
    if game.tick % cycle < settings.burst_on then
      local aim = acquire_aim(ai, target)
      shoot_at(character, aim)
      fire_weapon(ai, target, aim, false)
    else
      stop_shooting(character)
    end
  else
    stop_shooting(character)
  end

  if not loaded_weapon(character) then
    walk_to(ai, target.position, 1.4)
    melee_target(ai, target)
    return
  end

  local preferred = settings.preferred_range
  if d > preferred + 2 then
    walk_to(ai, target.position, preferred)
  elseif d < preferred - 3 then
    local dx = character.position.x - target.position.x
    local dy = character.position.y - target.position.y
    local len = math.max(0.1, math.sqrt(dx * dx + dy * dy))
    walk_to(ai, {
      x = character.position.x + dx / len * 3,
      y = character.position.y + dy / len * 3,
    }, 0.5)
  elseif settings.strafe then
    if game.tick % settings.strafe_ticks == 0 then
      ai.strafe_sign = -ai.strafe_sign
    end
    local dx = target.position.x - character.position.x
    local dy = target.position.y - character.position.y
    local len = math.max(0.1, math.sqrt(dx * dx + dy * dy))
    walk_to(ai, {
      x = character.position.x - dy / len * 3 * ai.strafe_sign,
      y = character.position.y + dx / len * 3 * ai.strafe_sign,
    }, 0.5)
  else
    stop_walking(character)
  end
end

local function heal_or_should_retreat(ai)
  local character = ai.character
  local settings = Config.AI_DIFFICULTY[ai.difficulty]
  if character.health / Config.AI_CHARACTER_MAX_HEALTH
    >= settings.retreat_health then return false end
  if character.get_item_count("raw-fish") > 0 then
    character.remove_item{ name = "raw-fish", count = 1 }
    character.health = math.min(Config.AI_CHARACTER_MAX_HEALTH,
      character.health + Config.AI_HEAL_AMOUNT)
    return false
  end
  return storage.bw.teams[ai.team].bed_alive
end

local function start_next_attack(ai)
  if ai.reached_enemy then
    enter_state(ai, "assault")
  elseif ai.reached_mid then
    route_to_enemy(ai)
  else
    route_to_mid(ai)
  end
end

local function prepare_tick(ai)
  local character = ai.character
  local phase = math.floor((game.tick - ai.state_tick)
    / Config.AI_PHASE_TICKS) % 4
  local target
  if phase == 0 or phase == 2 then
    target = Util.team_pos(ai.team, Config.FURNITURE.base_gen)
  elseif phase == 1 then
    target = Util.team_pos(ai.team, Config.FURNITURE.market_items)
  else
    target = Util.team_pos(ai.team, Config.FURNITURE.market_upgrades)
  end

  local stop_radius = (phase == 1 or phase == 3)
    and Config.AI_SHOP_REACH or 1.8
  if walk_to(ai, target, stop_radius) then
    if phase == 1 then
      buy_item_loadout(ai)
    elseif phase == 3 then
      buy_team_upgrades(ai)
    end
  end

  local settings = Config.AI_DIFFICULTY[ai.difficulty]
  local delay = ai.spawn_count == 1 and settings.aggression_ticks or settings.regear_ticks
  if not storage.bw.teams[ai.team].bed_alive then delay = 0 end
  local needed_landfill = settings.bridge_stock
  if ai.reached_mid then needed_landfill = math.min(50, needed_landfill) end
  if ai.reached_enemy then needed_landfill = math.min(20, needed_landfill) end
  if game.tick - ai.last_spawn_tick >= delay
    and character.get_item_count("landfill") >= needed_landfill
    and total_bullet_ammo(character) >= 10 then
    start_next_attack(ai)
  end
end

local function mid_tick(ai)
  local settings = Config.AI_DIFFICULTY[ai.difficulty]
  local phase = math.floor((game.tick - ai.state_tick)
    / Config.AI_PHASE_TICKS) % 2
  local target = { x = 0, y = phase == 0 and -5 or 5 }
  walk_to(ai, target, 1.7)
  local loiter_ticks = ai.resupply_done
    and math.min(Config.AI_POST_RESUPPLY_MID_TICKS,
      settings.mid_loiter_ticks)
    or settings.mid_loiter_ticks
  if game.tick - ai.state_tick < loiter_ticks then return end

  if settings.emerald_resupply and not ai.resupply_done
    and not ai.resupply_pending
    and ai.character.get_item_count("bw-emerald") >= 2 then
    ai.resupply_pending = true
    route_home(ai, "resupply")
  else
    route_to_enemy(ai)
  end
end

local function resupply_tick(ai)
  local elapsed = game.tick - ai.state_tick
  local target
  if math.floor(elapsed / Config.AI_PHASE_TICKS) % 2 == 0 then
    target = Util.team_pos(ai.team, Config.FURNITURE.market_items)
    if walk_to(ai, target, Config.AI_SHOP_REACH) then
      buy_item_loadout(ai)
    end
  else
    target = Util.team_pos(ai.team, Config.FURNITURE.market_upgrades)
    if walk_to(ai, target, Config.AI_SHOP_REACH) then
      buy_team_upgrades(ai)
    end
  end
  if elapsed >= Config.AI_RESUPPLY_TICKS then
    ai.resupply_pending = false
    ai.resupply_done = true
    route_to_mid(ai)
  end
end

local function assault_tick(ai)
  local enemy_key = Util.enemy_key(ai.team)
  local enemy_team = storage.bw.teams[enemy_key]
  local _, enemy_character, enemy_distance = nearest_enemy(ai)
  if enemy_character and enemy_distance <= 28 then
    fight_target(ai, enemy_character)
    return
  end

  if enemy_team.bed_alive and enemy_team.bed and enemy_team.bed.valid then
    local bed = enemy_team.bed
    local enemy_sign = Config.TEAMS[enemy_key].sign
    local approach = {
      x = bed.position.x - enemy_sign
        * (Config.FORTRESS_HALF + Config.AI_BED_APPROACH_MARGIN),
      y = bed.position.y,
    }
    local flank = { x = approach.x, y = ai.lane }
    if not ai.assault_flanked then
      if close_to(ai.character.position, flank, 1.2) then
        ai.assault_flanked = true
      else
        walk_to(ai, flank, 0.8)
        return
      end
    end
    if not ai.assault_approached then
      if close_to(ai.character.position, approach, 1.2) then
        ai.assault_approached = true
      else
        walk_to(ai, approach, 0.8)
        return
      end
    end
    if not close_to(ai.character.position, bed.position, 3.25) then
      walk_to(ai, bed.position, 2.7)
      return
    end

    stop_walking(ai.character)
    stop_shooting(ai.character)
    if game.tick >= ai.next_mine_tick then
      local settings = Config.AI_DIFFICULTY[ai.difficulty]
      local drill_multiplier = storage.bw.teams[ai.team].upgrades.drill
        and (1 + Config.DRILL_MINING) or 1
      ai.next_mine_tick = game.tick + settings.mine_interval
      bed.damage(settings.bed_mine_damage * drill_multiplier,
        ai.character.force, "physical",
        ai.character, ai.character)
    end
    return
  end

  if enemy_character then
    fight_target(ai, enemy_character)
  else
    walk_to(ai, enemy_team.spawn, 2.0)
  end
end

local function defend_tick(ai)
  local target = player_character(ai.threat_player)
  local bed = storage.bw.teams[ai.team].bed
  local radius = Config.AI_DIFFICULTY[ai.difficulty].defend_radius
  if not target or not bed or not bed.valid
    or not close_to(target.position, bed.position, radius * 1.35) then
    ai.threat_player = nil
    start_next_attack(ai)
    return
  end
  fight_target(ai, target)
end

local function scan_threats(ai)
  local bed = storage.bw.teams[ai.team].bed
  if not (bed and bed.valid) then return end
  local radius = Config.AI_DIFFICULTY[ai.difficulty].defend_radius
  for _, player in pairs(game.connected_players) do
    if player.character and player.character.valid
      and player.force.name ~= ai.character.force.name
      and close_to(player.character.position, bed.position, radius) then
      ai.threat_player = player.index
      local returning_to_defend = ai.state == "route"
        and ai.route_next == "defend"
      if ai.state ~= "defend" and not returning_to_defend then
        if close_to(ai.character.position, bed.position, radius + 10) then
          enter_state(ai, "defend")
        else
          route_home(ai, "defend")
        end
      end
      return
    end
  end
end

function M.tick()
  local ai = storage.bw and storage.bw.ai
  if not ai or not ai.enabled then return end
  if storage.bw.state ~= "active" then
    stop_walking(ai.character)
    stop_shooting(ai.character)
    return
  end

  if not (ai.character and ai.character.valid) then
    if not ai.eliminated and ai.respawn_tick and game.tick >= ai.respawn_tick then
      if spawn_character(ai) then
        Util.announce(Config.AI_NAME .. " respawned.", Config.TEAMS[ai.team].color)
      end
    end
    return
  end

  if game.tick % Config.AI_PICKUP_TICKS == 0 then
    collect_ground_items(ai)
    scan_threats(ai)
  end

  if heal_or_should_retreat(ai)
    and not (ai.state == "route" and ai.route_next == "prepare") then
    route_home(ai, "prepare")
  end

  local _, nearby, nearby_distance = nearest_enemy(ai)
  if nearby and nearby_distance <= 16
    and ai.state ~= "route" and ai.state ~= "resupply" then
    fight_target(ai, nearby)
    return
  end

  if ai.state == "prepare" then
    prepare_tick(ai)
  elseif ai.state == "route" then
    follow_route(ai)
  elseif ai.state == "mid" then
    mid_tick(ai)
  elseif ai.state == "resupply" then
    resupply_tick(ai)
  elseif ai.state == "assault" then
    assault_tick(ai)
  elseif ai.state == "defend" then
    defend_tick(ai)
  else
    enter_state(ai, "prepare")
  end
end

function M.on_entity_died(event)
  local ai = storage.bw and storage.bw.ai
  if not ai or not ai.enabled or not ai.character then return false end
  if event.entity ~= ai.character then return false end

  ai.stats.deaths = ai.stats.deaths + 1
  ai.character = nil
  ai.aim = nil
  ai.threat_player = nil
  local killer = "the void"
  if event.cause and event.cause.valid then
    if event.cause.type == "character" and event.cause.player then
      killer = event.cause.player.name
    else
      killer = "[entity=" .. event.cause.name .. "]"
    end
  end
  Util.announce(Config.AI_NAME .. " was slain by " .. killer,
    { r = 0.7, g = 0.7, b = 0.7 })

  if storage.bw.teams[ai.team].bed_alive then
    ai.respawn_tick = game.tick
      + Config.DIFFICULTY[storage.bw.difficulty].respawn_s * 60
    ai.state = "respawning"
  else
    ai.eliminated = true
    ai.respawn_tick = nil
    ai.state = "eliminated"
    Util.announce(Config.AI_NAME .. " is ELIMINATED!",
      { r = 1, g = 0.3, b = 0.3 }, "utility/game_lost")
  end
  return true
end

function M.is_character(entity)
  local ai = storage.bw and storage.bw.ai
  return ai and ai.enabled and ai.character
    and entity and entity == ai.character
end

return M
