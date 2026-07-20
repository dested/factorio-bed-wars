-- Bed Wars markets: stock the item shop and route every purchase.
local Config = require("__bed-wars__/scenarios/bedwars/lib/config")
local Util = require("__bed-wars__/scenarios/bedwars/lib/util")
local Upgrades = require("__bed-wars__/scenarios/bedwars/lib/upgrades")

local M = {}

function M.stock_markets()
  local diff = Config.DIFFICULTY[storage.bw.difficulty]
  for _, key in pairs(Config.TEAM_ORDER) do
    local m = storage.bw.teams[key].market_items
    if m and m.valid then
      m.clear_market_items()
      for _, o in pairs(Config.SHOP) do
        m.add_market_item{
          price = { { name = o.cost.item, count = math.max(1, math.ceil(o.cost.count * diff.price_mult)) } },
          offer = { type = "give-item", item = o.give, count = o.count },
        }
      end
    end
  end
end

function M.on_market_purchase(e)
  local market = e.market
  if not (market and market.valid) then return end
  local player = game.get_player(e.player_index)
  local offers = market.get_market_items()
  local offer = offers[e.offer_index]
  if not offer then return end

  if market.name == Config.MARKET_UPGRADES_NAME then
    local team_key
    for _, key in pairs(Config.TEAM_ORDER) do
      local mu = storage.bw.teams[key].market_upgrades
      if mu and mu.valid and mu == market then
        team_key = key
        break
      end
    end
    team_key = team_key or Util.team_key_of_force(market.force.name)
    if not team_key then return end

    local diff = Config.DIFFICULTY[storage.bw.difficulty]
    local token = offer.offer.item
    local by_token = {}
    for _, entry in pairs(Config.UPGRADES) do
      by_token[entry.token] = entry
    end
    local entry = by_token[token]
    if not entry then return end

    if player then
      player.remove_item{ name = token, count = e.count }
      if e.count > 1 then
        local effective_price = math.max(1, math.ceil(entry.cost.count * diff.price_mult))
        player.insert{ name = entry.cost.item, count = (e.count - 1) * effective_price }
      end
    end

    Upgrades.apply(team_key, entry.id)
  else
    if player then
      local given = offer.offer.count * e.count
      Util.fly(player, { "", "+", tostring(given), " ", { "item-name." .. offer.offer.item } }, { r = 0.6, g = 1, b = 0.6 })
      player.play_sound{ path = "utility/console_message" }
    end
  end
end

return M
