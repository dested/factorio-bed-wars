-- Bed Wars: bed breaking, deaths/respawns, victory, escalation clock, rematch.
local Config = require("__bed-wars__/scenarios/bedwars/lib/config")
local Util = require("__bed-wars__/scenarios/bedwars/lib/util")
local Teams = require("__bed-wars__/scenarios/bedwars/lib/teams")
local Mapgen = require("__bed-wars__/scenarios/bedwars/lib/mapgen")
local Generators = require("__bed-wars__/scenarios/bedwars/lib/generators")
local Shop = require("__bed-wars__/scenarios/bedwars/lib/shop")
local Upgrades = require("__bed-wars__/scenarios/bedwars/lib/upgrades")
local Hud = require("__bed-wars__/scenarios/bedwars/lib/hud")
local Lobby = require("__bed-wars__/scenarios/bedwars/lib/lobby")
local M = {}

local function bed_key_of_name(name)
  for _, key in pairs(Config.TEAM_ORDER) do
    if Config.BED_NAMES[key] == name then return key end
  end
  return nil
end

-- Neutral force: players can never hand-mine enemy-force entities (see teams.lua).
local function rebuild_bed(bed_key, pos)
  local surface = game.surfaces[Config.SURFACE]
  local bed = surface.create_entity{ name = Config.BED_NAMES[bed_key], position = pos, force = "neutral" }
  storage.bw.teams[bed_key].bed = bed
  return bed
end

local function bed_broken(bed_key, breaker_text)
  local team = storage.bw.teams[bed_key]
  team.bed_alive = false
  team.bed = nil
  Util.announce(Config.TEAMS[bed_key].display .. " bed DESTROYED by " .. breaker_text .. "! "
    .. Config.TEAMS[bed_key].display .. " can no longer respawn!",
    { r = 1, g = 0.3, b = 0.3 }, "utility/alert_destroyed")
  M.check_victory()
end

function M.on_player_mined_entity(e)
  local name = e.entity and e.entity.valid and e.entity.name
  if not name then return end
  local bed_key = bed_key_of_name(name)
  if not bed_key or storage.bw.state ~= "active" then return end
  local player = game.get_player(e.player_index)
  local my = Util.team_key_of_player(player)

  if my == bed_key then
    rebuild_bed(bed_key, e.entity.position)
    Util.fly(player, "You can't break your own bed!", { r = 1, g = 0.4, b = 0.4 })
    return
  end
  bed_broken(bed_key, player.name)
end

-- Beds can also be shot/bombed/burned to death (script destroy() does not fire this).
function M.on_entity_died(e)
  local name = e.entity and e.entity.valid and e.entity.name
  if not name then return end
  local bed_key = bed_key_of_name(name)
  if not bed_key or storage.bw.state ~= "active" then return end
  local team_force = storage.bw.teams[bed_key].force_name

  if e.force and e.force.valid and e.force.name == team_force then
    -- Own team's stray damage killed their own bed: rebuild, no free suicides.
    rebuild_bed(bed_key, e.entity.position)
    game.forces[team_force].print("Your own attack hit your bed - it was rebuilt. Careful!",
      { color = { r = 1, g = 0.6, b = 0.3 } })
    return
  end

  local breaker = "an attack"
  local cause = e.cause
  if cause and cause.valid then
    if cause.type == "character" and cause.player then
      breaker = cause.player.name
    else
      breaker = "[entity=" .. cause.name .. "]"
    end
  end
  bed_broken(bed_key, breaker)
end

function M.on_player_died(e)
  local player = game.get_player(e.player_index)
  local key = Util.team_key_of_player(player)
  if not key or storage.bw.state ~= "active" then return end

  local cause = e.cause
  local killer = "the void"
  if cause and cause.valid then
    if cause.type == "character" and cause.player then
      killer = cause.player.name
    else
      killer = "[entity=" .. cause.name .. "]"
    end
  end
  Util.announce(player.name .. " was slain by " .. killer, { r = 0.7, g = 0.7, b = 0.7 })

  if storage.bw.teams[key].bed_alive then
    player.ticks_to_respawn = Config.DIFFICULTY[storage.bw.difficulty].respawn_s * 60
  else
    storage.bw.pending_spectate[player.index] = true
    player.ticks_to_respawn = 60
    Util.announce(player.name .. " is ELIMINATED!", { r = 1, g = 0.3, b = 0.3 }, "utility/game_lost")
  end
end

function M.on_player_respawned(e)
  local player = game.get_player(e.player_index)
  if storage.bw.pending_spectate[player.index] then
    storage.bw.pending_spectate[player.index] = nil
    Teams.make_spectator(player)
    M.check_victory()
    return
  end
  if storage.bw.state == "active" then Teams.give_kit(player) end
end

function M.check_victory()
  if storage.bw.state ~= "active" then return end
  local outs = {}
  local contenders = 0
  for _, key in pairs(Config.TEAM_ORDER) do
    local team = storage.bw.teams[key]
    if #team.players > 0 then
      contenders = contenders + 1
      local alive = false
      if not team.bed_alive then
        for _, pid in pairs(team.players) do
          local p = game.get_player(pid)
          if p and p.valid
            and ((p.character and p.character.valid)
                 or p.ticks_to_respawn ~= nil
                 or p.controller_type == defines.controllers.ghost)
            and not storage.bw.pending_spectate[p.index] then
            alive = true
            break
          end
        end
      else
        alive = true
      end
      if not alive then table.insert(outs, key) end
    end
  end
  if contenders < 2 then return end
  if #outs == 1 then
    M.end_game(Util.enemy_key(outs[1]))
  elseif #outs == 2 then
    M.end_game(nil)
  end
end

function M.clock_tick()
  if storage.bw.state == "over" then
    local fw = storage.bw.fireworks
    if fw and fw.remaining > 0 then
      local surface = game.surfaces[Config.SURFACE]
      for _ = 1, 2 do
        surface.create_entity{ name = "big-explosion",
          position = { x = fw.x + storage.bw.rng(-8, 8), y = fw.y + storage.bw.rng(-8, 8) } }
      end
      fw.remaining = fw.remaining - 2
      if fw.remaining <= 0 then storage.bw.fireworks = nil end
    end
    return
  end

  local elapsed = game.tick - storage.bw.started_tick
  local diff = Config.DIFFICULTY[storage.bw.difficulty]

  while storage.bw.escalation_next <= #Config.ESCALATION do
    local entry = Config.ESCALATION[storage.bw.escalation_next]
    if elapsed < entry.min * 3600 then break end
    storage.bw.escalation_next = storage.bw.escalation_next + 1
    if entry.event == "emerald-2" then
      Generators.escalate(2)
      Util.announce("[item=bw-emerald] Emerald generators upgraded to Tier II!",
        { r = 0.4, g = 1, b = 0.5 }, "utility/console_message")
    elseif entry.event == "emerald-3" then
      Generators.escalate(3)
      Util.announce("[item=bw-emerald] Emerald generators upgraded to Tier III!",
        { r = 0.4, g = 1, b = 0.5 }, "utility/console_message")
    elseif entry.event == "draw" then
      M.end_game(nil)
    end
  end

  if diff.warn_min and not storage.bw.sudden_death_warned and elapsed >= diff.warn_min * 3600 then
    storage.bw.sudden_death_warned = true
    Util.announce("SUDDEN DEATH in 2 minutes - all beds will self-destruct!",
      { r = 1, g = 0.3, b = 0.3 }, "utility/alert_destroyed")
  end
  if diff.sudden_death_min and not storage.bw.sudden_death_done and elapsed >= diff.sudden_death_min * 3600 then
    M.sudden_death()
  end
end

function M.sudden_death()
  storage.bw.sudden_death_done = true
  for _, key in pairs(Config.TEAM_ORDER) do
    local team = storage.bw.teams[key]
    if team.bed_alive then
      if team.bed and team.bed.valid then team.bed.destroy() end
      team.bed_alive = false
      team.bed = nil
    end
  end
  Util.announce("SUDDEN DEATH! All beds destroyed - no more respawns!",
    { r = 1, g = 0.2, b = 0.2 }, "utility/alert_destroyed")
end

function M.end_game(winner_key)
  storage.bw.state = "over"
  if winner_key then
    local w = Config.TEAMS[winner_key]
    Util.announce(w.display .. " WINS THE GAME!", w.color, "utility/game_won")
    local loser = Util.enemy_key(winner_key)
    storage.bw.fireworks = { x = storage.bw.teams[loser].spawn.x, y = storage.bw.teams[loser].spawn.y, remaining = 16 }
  else
    Util.announce("DRAW. Both beds are gone.", { r = 0.8, g = 0.8, b = 0.8 }, "utility/game_lost")
  end
  for _, player in pairs(game.connected_players) do
    M.build_end_gui(player, winner_key)
  end
end

function M.build_end_gui(player, winner_key)
  local center = player.gui.center
  if center.bw_end then center.bw_end.destroy() end
  local frame = center.add{ type = "frame", name = "bw_end", direction = "vertical", caption = "GAME OVER" }

  local big = frame.add{ type = "label" }
  if winner_key then
    big.caption = Config.TEAMS[winner_key].display .. " WINS!"
    big.style.font_color = Config.TEAMS[winner_key].color
  else
    big.caption = "DRAW"
    big.style.font_color = { r = 0.8, g = 0.8, b = 0.8 }
  end
  big.style.font = "default-large-bold"

  frame.add{ type = "label", caption = "Rematch resets the whole map - bridges, walls, upgrades, everything." }

  local flow = frame.add{ type = "flow", direction = "horizontal" }
  flow.add{ type = "button", name = "bw_end_rematch", caption = "REMATCH", style = "confirm_button" }
  flow.add{ type = "button", name = "bw_end_close", caption = "Keep exploring" }
end

function M.on_gui_click(e)
  if not (e.element and e.element.valid) then return end
  local name = e.element.name
  if name == "bw_end_rematch" then
    M.rematch()
  elseif name == "bw_end_close" then
    local player = game.get_player(e.player_index)
    if player.gui.center.bw_end then player.gui.center.bw_end.destroy() end
  end
end

function M.rematch()
  local surface = game.surfaces[Config.SURFACE]
  for _, player in pairs(game.connected_players) do
    if player.gui.center.bw_end then player.gui.center.bw_end.destroy() end
    if player.character then Teams.make_spectator(player) end
  end
  Hud.destroy_all()

  for _, ent in pairs(surface.find_entities_filtered{}) do
    if ent.valid and ent.type ~= "character" then ent.destroy() end
  end
  Mapgen.reset_tiles(surface)

  for _, key in pairs(Config.TEAM_ORDER) do
    local team = storage.bw.teams[key]
    team.bed = nil
    team.bed_alive = true
    team.market_items = nil
    team.market_upgrades = nil
    team.chest = nil
    team.upgrades = { forge = 0, sharp = 0, boots = false, drill = false, heal = false, fortress = false }
    Upgrades.reset_force_modifiers(key)
  end

  storage.bw.gens = {}
  storage.bw.state = "lobby"
  storage.bw.started_tick = nil
  storage.bw.escalation_next = 1
  storage.bw.emerald_tier = 1
  storage.bw.sudden_death_done = false
  storage.bw.sudden_death_warned = false
  storage.bw.pending_spectate = {}
  storage.bw.fireworks = nil

  Teams.setup_islands(surface)
  Generators.place_all(surface)
  Shop.stock_markets()
  for _, key in pairs(Config.TEAM_ORDER) do
    Upgrades.refresh_offers(key)
    game.forces[Config.TEAMS[key].force_name].chart_all(surface)
  end
  Lobby.show_all()
  Util.announce("REMATCH! Back to the lobby.", { r = 1, g = 0.85, b = 0.3 }, "utility/console_message")
end

return M
