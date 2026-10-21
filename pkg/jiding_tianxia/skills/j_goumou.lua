local j_goumou = fk.CreateSkill {
  name = "j_goumou",
}

Fk:loadTranslationTable{
  ["j_goumou"] = "构谋",
  [":j_goumou"] = "每轮限一次，当你因【昭心】获得牌后，你可以选择一名其他角色，令其本轮无法使用或响应【昭心】所选花色的牌，然后你可以将一张因【昭心】获得的牌当作【过河拆桥】使用。",

  ["#j_goumou-invoke"] = "构谋：是否发动（令一名角色无法使用/响应昭心花色牌）？",
  ["#j_goumou-ban"] = "构谋：选择一名角色，令其本轮无法使用/响应昭心所选花色牌",
  ["#j_goumou-disman"] = "构谋：将一张因昭心获得的牌当作过河拆桥使用",
  ["#j_goumou-disman-target"] = "构谋：选择过河拆桥的目标",
  ["j_goumou_card"] = "因昭心获得的牌",

  ["$j_goumou1"] = "构衅于内，祸发萧墙。",
  ["$j_goumou2"] = "此谋一成，大事可图。",
}

-- 因昭心获得牌后触发（每轮限一次）
j_goumou:addEffect(fk.AfterCardsMove, {
  global = true,
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_goumou.name) or player.dead then return false end
    if player:getMark("j_goumou_used-round") ~= 0 then return false end
    return player:getMark("j_zhaoxin_justgained-round") == 1
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local ok = room:askToSkillInvoke(player, { skill_name = j_goumou.name, prompt = "#j_goumou-invoke" })
    if not ok then
      -- 放弃此次机会，消耗本次“因昭心获得牌”的触发标记
      room:setPlayerMark(player, "j_zhaoxin_justgained-round", 0)
    end
    return ok
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "j_goumou_used-round", 1)
    room:setPlayerMark(player, "j_zhaoxin_justgained-round", 0)

    -- 选择一名其他角色，令其本轮无法使用/响应昭心所选花色牌
    local others = table.filter(room.alive_players, function(p) return p ~= player end)
    local t_list = room:askToChoosePlayers(player, {
      targets = others,
      min_num = 1,
      max_num = 1,
      skill_name = j_goumou.name,
      prompt = "#j_goumou-ban",
      cancelable = true,
    })
    if #t_list > 0 then
      local suits = player:getMark("j_zhaoxin_suits-round")
      if type(suits) == "table" and #suits > 0 then
        room:setPlayerMark(t_list[1], "j_goumou_ban-round", suits)
      end
    end

    -- 将一张因昭心获得的牌当作过河拆桥使用
    local got = player:getMark("j_zhaoxin_gotids-round")
    if type(got) ~= "table" then return end
    local hand = player:getCardIds("h")
    local avail = table.filter(got, function(id) return table.contains(hand, id) end)
    if #avail == 0 then return end
    if not room:askToSkillInvoke(player, { skill_name = j_goumou.name, prompt = "#j_goumou-disman" }) then return end
    local cards = room:askToChooseCards(player, {
      target = player,
      flag = { card_data = { { "j_goumou_card", avail } } },
      min = 1,
      max = 1,
      skill_name = j_goumou.name,
      prompt = "#j_goumou-disman",
      cancelable = true,
    })
    if #cards == 0 then return end
    local d_targets = table.filter(room.alive_players, function(p) return p ~= player end)
    local d_list = room:askToChoosePlayers(player, {
      targets = d_targets,
      min_num = 1,
      max_num = 1,
      skill_name = j_goumou.name,
      prompt = "#j_goumou-disman-target",
      cancelable = true,
    })
    if #d_list == 0 then return end
    local card = Fk:cloneCard("dismantlement")
    card.skillName = j_goumou.name
    card:addSubcard(cards[1])
    room:useCard{ from = player, tos = { d_list[1] }, card = card, extraUse = true }
  end,
})

-- 被构谋标记的角色无法使用/响应昭心所选花色的牌
j_goumou:addEffect("prohibit", {
  global = true,
  is_prohibited = function(self, from, to, card)
    if not from or not card then return false end
    local suits = from:getMark("j_goumou_ban-round")
    if type(suits) ~= "table" then return false end
    return table.contains(suits, card:getSuitString())
  end,
})

return j_goumou
