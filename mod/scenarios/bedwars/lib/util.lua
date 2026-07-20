-- Bed Wars: small stateless helpers shared across modules. No storage writes.
local Config = require("__bed-wars__/scenarios/bedwars/lib/config")
local M = {}

function M.announce(text, color, sound_path)
  local settings = { color = color }
  if sound_path then settings.sound_path = sound_path end
  game.print(text, settings)
end

function M.team_key_of_force(force_name)
  for _, key in pairs(Config.TEAM_ORDER) do
    if Config.TEAMS[key].force_name == force_name then return key end
  end
  return nil
end

function M.team_key_of_player(player)
  return M.team_key_of_force(player.force.name)
end

function M.enemy_key(key)
  for _, k in pairs(Config.TEAM_ORDER) do
    if k ~= key then return k end
  end
  return nil
end

-- Per-player floating text. Uses an explicit position (not create_at_cursor) so
-- it is safe for spectators and remote-view players.
function M.fly(player, text, color)
  if not (player and player.valid) then return end
  player.create_local_flying_text{ text = text, position = player.position, color = color }
end

function M.fmt_time(ticks)
  local total = math.floor(ticks / 60)
  local m = math.floor(total / 60)
  local s = total % 60
  return string.format("%d:%02d", m, s)
end

-- Absolute world position for a furniture offset written for West. West applies
-- offsets verbatim (sign = -1); East mirrors x. y is unchanged for both.
function M.team_pos(key, offset)
  local team = Config.TEAMS[key]
  local x = team.sign * Config.ISLANDS.home_cx + (key == "west" and offset.x or -offset.x)
  return { x = x, y = offset.y }
end

return M
