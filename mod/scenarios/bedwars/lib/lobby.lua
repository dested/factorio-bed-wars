-- Bed Wars: pre-game lobby. Team rosters, side-switching, difficulty, START.
local Config = require("__bed-wars__/scenarios/bedwars/lib/config")
local Util = require("__bed-wars__/scenarios/bedwars/lib/util")
local Teams = require("__bed-wars__/scenarios/bedwars/lib/teams")
local Shop = require("__bed-wars__/scenarios/bedwars/lib/shop")
local Upgrades = require("__bed-wars__/scenarios/bedwars/lib/upgrades")
local Hud = require("__bed-wars__/scenarios/bedwars/lib/hud")
local AI = require("__bed-wars__/scenarios/bedwars/lib/ai")
local M = {}

local DIFF_DESC = {
  chill = "Fast resources, cheap prices, no sudden death. Great for a first game.",
  classic = "The intended Bed Wars experience.",
  brutal = "Slow resources, long respawns, early sudden death. For veterans.",
}

function M.assign_default(player)
  local west = #storage.bw.teams.west.players
  local east = #storage.bw.teams.east.players
  Teams.assign(player, east < west and "east" or "west")
end

local function roster(key)
  local names = {}
  for _, idx in pairs(storage.bw.teams[key].players) do
    local p = game.get_player(idx)
    if p and p.valid then table.insert(names, p.name) end
  end
  if AI.planned_team() == key then
    table.insert(names, Config.AI_NAME .. " [AI]")
  end
  if #names == 0 then return "waiting..." end
  return table.concat(names, ", ")
end

function M.show(player)
  local center = player.gui.center
  if center.bw_lobby then center.bw_lobby.destroy() end
  local frame = center.add{ type = "frame", name = "bw_lobby", direction = "vertical", caption = "BED WARS" }

  local sub = frame.add{ type = "label", caption = "Destroy the enemy bed, then finish them off. Defend your own." }
  sub.style.font = "default-bold"

  local west_label = frame.add{ type = "label", caption = "West: " .. roster("west") }
  west_label.style.font_color = Config.TEAMS.west.color
  local east_label = frame.add{ type = "label", caption = "East: " .. roster("east") }
  east_label.style.font_color = Config.TEAMS.east.color

  frame.add{ type = "button", name = "bw_lobby_switch", caption = "Switch team" }

  local is_host = player.index == storage.bw.host

  local diff_flow = frame.add{ type = "flow", direction = "horizontal" }
  diff_flow.add{ type = "label", caption = "Game pace:" }
  local items = {}
  local selected = 1
  for i, key in pairs(Config.DIFFICULTY_ORDER) do
    items[i] = Config.DIFFICULTY_LABELS[key]
    if key == storage.bw.difficulty then selected = i end
  end
  diff_flow.add{
    type = "drop-down", name = "bw_lobby_difficulty",
    items = items, selected_index = selected, enabled = is_host,
  }

  frame.add{ type = "label", name = "bw_lobby_diff_desc", caption = DIFF_DESC[storage.bw.difficulty] }

  local ai_flow = frame.add{ type = "flow", direction = "horizontal" }
  ai_flow.add{ type = "label", caption = "Computer opponent:" }
  local ai_items = {}
  local ai_selected = 1
  for i, key in pairs(Config.AI_DIFFICULTY_ORDER) do
    ai_items[i] = Config.AI_DIFFICULTY_LABELS[key]
    if key == storage.bw.ai.difficulty then ai_selected = i end
  end
  ai_flow.add{
    type = "drop-down", name = "bw_lobby_ai_difficulty",
    items = ai_items, selected_index = ai_selected, enabled = is_host,
  }
  frame.add{
    type = "label", name = "bw_lobby_ai_desc",
    caption = Config.AI_DIFFICULTY_DESCRIPTIONS[storage.bw.ai.difficulty],
  }

  frame.add{
    type = "button", name = "bw_lobby_start", caption = "START GAME",
    style = "confirm_button", enabled = is_host,
    tooltip = "With one occupied team, Rivet takes the other side. Set the computer opponent to Off for human multiplayer.",
  }
end

function M.show_all()
  if storage.bw.state ~= "lobby" then return end
  for _, player in pairs(game.connected_players) do
    M.show(player)
  end
end

function M.on_gui_click(e)
  if not (e.element and e.element.valid) then return end
  local player = game.get_player(e.player_index)
  local name = e.element.name
  if name == "bw_lobby_switch" then
    local my = Util.team_key_of_player(player)
    if my == nil then
      M.assign_default(player)
    else
      local other = Util.enemy_key(my)
      if #storage.bw.teams[other].players == 0 then
        Teams.assign(player, other)
      else
        local other_pid = storage.bw.teams[other].players[1]
        local other_pl = game.get_player(other_pid)
        Teams.assign(player, other)
        if other_pl and other_pl.valid then Teams.assign(other_pl, my) end
      end
    end
    M.show_all()
  elseif name == "bw_lobby_start" then
    if e.player_index ~= storage.bw.host then return end
    M.start_game()
  end
end

function M.on_selection_changed(e)
  if not (e.element and e.element.valid) then return end
  if e.player_index ~= storage.bw.host then return end
  if e.element.name == "bw_lobby_difficulty" then
    storage.bw.difficulty = Config.DIFFICULTY_ORDER[e.element.selected_index]
    Shop.stock_markets()
    for _, key in pairs(Config.TEAM_ORDER) do Upgrades.refresh_offers(key) end
    M.show_all()
  elseif e.element.name == "bw_lobby_ai_difficulty" then
    storage.bw.ai.difficulty = Config.AI_DIFFICULTY_ORDER[e.element.selected_index]
    M.show_all()
  end
end

function M.start_game()
  storage.bw.state = "active"
  storage.bw.started_tick = game.tick
  for _, player in pairs(game.connected_players) do
    if player.gui.center.bw_lobby then player.gui.center.bw_lobby.destroy() end
  end
  for _, key in pairs(Config.TEAM_ORDER) do
    for _, pid in pairs(storage.bw.teams[key].players) do
      local p = game.get_player(pid)
      if p and p.valid and p.connected then
        Teams.spawn_character(p, key)
        Teams.give_kit(p)
      end
    end
  end
  AI.start()
  for _, player in pairs(game.connected_players) do
    Hud.build(player)
  end
  Util.announce("[entity=bw-bed-west] BED WARS! Protect your bed, break theirs. Fight! [entity=bw-bed-east]",
    { r = 1, g = 0.85, b = 0.3 }, "utility/console_message")
end

return M
