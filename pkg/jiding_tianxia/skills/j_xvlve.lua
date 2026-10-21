local j_xvlve = fk.CreateSkill {
  name = "j_xvlve",
}

Fk:loadTranslationTable{
  ["j_xvlve"] = "续略",
  [":j_xvlve"] = "出牌阶段，若你的判定区有牌，你使用或打出一张手牌后可以摸4-x张牌。（x为本回合进入弃牌堆的花色数）",

  ["#j_xvlve-draw"] = "续略：是否摸取 %arg 张牌？",

  ["$j_xvlve1"] = "计未竟，略可续。",
  ["$j_xvlve2"] = "谋略相衔，生生不息。",
}

-- 记录本回合进入弃牌堆的花色（-turn 标记，回合结束自动清空）
j_xvlve:addEffect(fk.AfterCardsMove, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_xvlve.name) or player.dead then return false end
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile and #move.moveInfo > 0 then
        return true
      end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local suits = player:getTableMark("j_xvlve_suits-turn")
    local changed = false
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile then
        for _, info in ipairs(move.moveInfo) do
          local suit = Fk:getCardById(info.cardId):getSuitString()
          if suit ~= "nosuit" and suit ~= "unknown" and not table.contains(suits, suit) then
            table.insert(suits, suit)
            changed = true
          end
        end
      end
    end
    if changed then
      room:setPlayerMark(player, "j_xvlve_suits-turn", suits)
    end
  end,
})

-- 出牌阶段使用一张手牌后
j_xvlve:addEffect(fk.CardUseFinished, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_xvlve.name) and not player.dead and
      player.phase == Player.Play and
      #player:getCardIds("j") > 0 and
      data.card ~= nil and data:isUsingHandcard(player) and
      (4 - #player:getTableMark("j_xvlve_suits-turn")) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local n = 4 - #player:getTableMark("j_xvlve_suits-turn")
    return player.room:askToSkillInvoke(player, {
      skill_name = j_xvlve.name,
      prompt = "#j_xvlve-draw:::" .. n,
    })
  end,
  on_use = function(self, event, target, player, data)
    local n = 4 - #player:getTableMark("j_xvlve_suits-turn")
    player.room:drawCards(player, n, j_xvlve.name)
  end,
})

-- 出牌阶段打出一张手牌后
j_xvlve:addEffect(fk.CardRespondFinished, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if not (target == player and player:hasSkill(j_xvlve.name) and not player.dead) then return false end
    if player.phase ~= Player.Play then return false end
    if #player:getCardIds("j") == 0 then return false end
    if not data.card then return false end
    -- 打出的须为手牌
    local subcards = data.card.subcards or {}
    if #subcards == 0 then return false end
    if not table.contains(player:getHandlyIds(), subcards[1]) then return false end
    return (4 - #player:getTableMark("j_xvlve_suits-turn")) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local n = 4 - #player:getTableMark("j_xvlve_suits-turn")
    return player.room:askToSkillInvoke(player, {
      skill_name = j_xvlve.name,
      prompt = "#j_xvlve-draw:::" .. n,
    })
  end,
  on_use = function(self, event, target, player, data)
    local n = 4 - #player:getTableMark("j_xvlve_suits-turn")
    player.room:drawCards(player, n, j_xvlve.name)
  end,
})

return j_xvlve
