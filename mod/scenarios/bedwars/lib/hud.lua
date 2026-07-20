-- Bed Wars: top-bar HUD. Bed status, currency counts, clock, next-event countdown.
local Config = require("__bed-wars__/scenarios/bedwars/lib/config")
local Util = require("__bed-wars__/scenarios/bedwars/lib/util")
local M = {}

function M.build(player)
  local top = player.gui.top
  if top.bw_hud then top.bw_hud.destroy() end
  local hud = top.add{ type = "frame", name = "bw_hud", direction = "horizontal" }

  hud.add{ type = "sprite", sprite = "entity/bw-bed-west" }
  hud.add{ type = "label", name = "bw_west_status" }
  hud.add{ type = "sprite", sprite = "entity/bw-bed-east" }
  hud.add{ type = "label", name = "bw_east_status" }

  hud.add{ type = "sprite", sprite = "item/iron-plate" }
  hud.add{ type = "label", name = "bw_iron" }
  hud.add{ type = "sprite", sprite = "item/bw-gold" }
  hud.add{ type = "label", name = "bw_gold" }
  hud.add{ type = "sprite", sprite = "item/bw-emerald" }
  hud.add{ type = "label", name = "bw_em" }

  local clock = hud.add{ type = "label", name = "bw_clock", caption = "0:00" }
  clock.style.font = "default-bold"
  hud.add{ type = "label", name = "bw_event" }
end

-- Soonest future scheduled event (escalations + sudden death), or nil.
local function next_event(elapsed)
  local labels = { ["emerald-2"] = "Emerald II", ["emerald-3"] = "Emerald III", ["draw"] = "Draw" }
  local best_label, best_remaining = nil, nil
  for i = storage.bw.escalation_next, #Config.ESCALATION do
    local entry = Config.ESCALATION[i]
    local remaining = entry.min * 3600 - elapsed
    if remaining > 0 and (best_remaining == nil or remaining < best_remaining) then
      best_label, best_remaining = labels[entry.event] or entry.event, remaining
    end
  end
  local diff = Config.DIFFICULTY[storage.bw.difficulty]
  if diff.sudden_death_min and not storage.bw.sudden_death_done then
    local remaining = diff.sudden_death_min * 3600 - elapsed
    if remaining > 0 and (best_remaining == nil or remaining < best_remaining) then
      best_label, best_remaining = "Sudden Death", remaining
    end
  end
  return best_label, best_remaining
end

function M.update_all()
  for _, player in pairs(game.connected_players) do
    if not player.gui.top.bw_hud then M.build(player) end
    local hud = player.gui.top.bw_hud
    if hud and hud.valid then
      for _, s in pairs({
        { key = "west", label = hud.bw_west_status },
        { key = "east", label = hud.bw_east_status },
      }) do
        if storage.bw.teams[s.key].bed_alive then
          s.label.caption = "SAFE"
          s.label.style.font_color = { r = 0.4, g = 1, b = 0.4 }
        else
          s.label.caption = "DESTROYED"
          s.label.style.font_color = { r = 1, g = 0.35, b = 0.35 }
        end
      end

      local function count(item)
        if player.character then return player.get_item_count(item) end
        return 0
      end
      hud.bw_iron.caption = "x " .. count("iron-plate")
      hud.bw_gold.caption = "x " .. count("bw-gold")
      hud.bw_em.caption = "x " .. count("bw-emerald")

      if storage.bw.state == "active" then
        local elapsed = game.tick - storage.bw.started_tick
        hud.bw_clock.caption = Util.fmt_time(elapsed)
        local label, remaining = next_event(elapsed)
        if label then
          hud.bw_event.caption = label .. " in " .. Util.fmt_time(remaining)
        else
          hud.bw_event.caption = ""
        end
      elseif storage.bw.state == "over" then
        hud.bw_clock.caption = "GAME OVER"
        hud.bw_event.caption = ""
      else
        hud.bw_clock.caption = "-"
        hud.bw_event.caption = ""
      end
    end
  end
end

function M.destroy_all()
  for _, player in pairs(game.players) do
    if player.gui.top.bw_hud then player.gui.top.bw_hud.destroy() end
  end
end

M.announce = Util.announce

return M
