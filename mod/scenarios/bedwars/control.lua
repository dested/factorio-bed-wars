-- Bed Wars: event wiring only. Game logic lives in lib/; tuning in lib/config.lua.
local Config = require("__bed-wars__/scenarios/bedwars/lib/config")
local Mapgen = require("__bed-wars__/scenarios/bedwars/lib/mapgen")
local Teams = require("__bed-wars__/scenarios/bedwars/lib/teams")
local Lobby = require("__bed-wars__/scenarios/bedwars/lib/lobby")
local Generators = require("__bed-wars__/scenarios/bedwars/lib/generators")
local Shop = require("__bed-wars__/scenarios/bedwars/lib/shop")
local Upgrades = require("__bed-wars__/scenarios/bedwars/lib/upgrades")
local Combat = require("__bed-wars__/scenarios/bedwars/lib/combat")
local Hud = require("__bed-wars__/scenarios/bedwars/lib/hud")

script.on_init(function()
  storage.bw = {
    state = "lobby",
    difficulty = "classic",
    host = nil,
    started_tick = nil,
    escalation_next = 1,
    emerald_tier = 1,
    sudden_death_done = false,
    sudden_death_warned = false,
    pending_spectate = {},
    fireworks = nil,
    teams = {},
    gens = {},
    rng = game.create_random_generator(),
  }
  for _, key in pairs(Config.TEAM_ORDER) do
    storage.bw.teams[key] = {
      force_name = Config.TEAMS[key].force_name,
      bed = nil, bed_alive = true, spawn = nil,
      market_items = nil, market_upgrades = nil, chest = nil,
      upgrades = { forge = 0, sharp = 0, boots = false, drill = false, heal = false, fortress = false },
      players = {},
    }
  end
  local surface = game.surfaces[Config.SURFACE]
  surface.always_day = true
  Teams.create_forces()
  Mapgen.prime(surface)
  Teams.setup_islands(surface)
  Generators.place_all(surface)
  Shop.stock_markets()
  for _, key in pairs(Config.TEAM_ORDER) do
    Upgrades.refresh_offers(key)
    game.forces[Config.TEAMS[key].force_name].chart_all(surface)
  end
end)

script.on_event(defines.events.on_player_created, function(e)
  local player = game.get_player(e.player_index)
  storage.bw.host = storage.bw.host or e.player_index
  Teams.make_spectator(player)
  if storage.bw.state == "lobby" then
    Lobby.assign_default(player)
    Lobby.show_all()
  else
    player.print("A game is in progress - you are spectating.", { color = { r = 1, g = 0.8, b = 0.2 } })
    Hud.build(player)
  end
end)

script.on_event(defines.events.on_player_joined_game, function(e)
  local player = game.get_player(e.player_index)
  if storage.bw.state == "lobby" then Lobby.show(player) end
end)

script.on_event(defines.events.on_gui_click, function(e)
  Lobby.on_gui_click(e)
  Combat.on_gui_click(e)
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(e)
  Lobby.on_selection_changed(e)
end)

script.on_event(defines.events.on_chunk_generated, function(e)
  Mapgen.on_chunk_generated(e)
end)

script.on_event(defines.events.on_market_item_purchased, function(e)
  Shop.on_market_purchase(e)
end)

script.on_event(defines.events.on_player_mined_entity, function(e)
  Combat.on_player_mined_entity(e)
end)

script.on_event(defines.events.on_entity_died, function(e)
  Combat.on_entity_died(e)
end, {
  { filter = "name", name = "bw-bed-west" },
  { filter = "name", name = "bw-bed-east" },
})

script.on_event(defines.events.on_player_died, function(e)
  Combat.on_player_died(e)
end)

script.on_event(defines.events.on_player_respawned, function(e)
  Combat.on_player_respawned(e)
end)

script.on_nth_tick(Config.GEN_TICK, function()
  Generators.tick()
end)

script.on_nth_tick(Config.HUD_UPDATE_TICKS, function()
  if storage.bw.state ~= "lobby" then Hud.update_all() end
  if storage.bw.state == "active" or storage.bw.state == "over" then
    Combat.clock_tick()
  end
  if storage.bw.state == "active" then Upgrades.tick() end
end)
