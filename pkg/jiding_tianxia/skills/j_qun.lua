local j_qun = fk.CreateSkill {
  name = "j_qun",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_qun"] = "囷",
  [":j_qun"] = "锁定技，一名角色判定区内有“指仓相赠”并判定时，若判定牌与“指仓相赠”花色相同或点数奇偶相同，你获得此“指仓相赠”并将一张新的“指仓相赠”置入其判定区；否则其原拥有者摸两张牌。你拥有的“指仓相赠”可以视为手牌使用或打出，使用“指仓相赠”无次数限制。",
}

j_qun:addEffect(fk.FinishJudge, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_qun.name) then return false end
    if not target:isAlive() then return false end
    if data.reason ~= "j_zicangxiangzeng" then return false end
    return target:getMark("j_zicang_in_judge") ~= 0
  end,
  on_use = function(self, event, target, player, data)
    local room = event.room
    local zicang_card_id = target:getMark("j_zicang_in_judge")
    local zicang_card = Fk:getCardById(zicang_card_id)
    if not zicang_card then
      room:setPlayerMark(target, "j_zicang_in_judge", 0)
      return
    end

    local source_id = zicang_card:getMark("j_zicang_source")
    local source = room:getPlayerById(source_id)
    if not source or not source:isAlive() then
      room:setPlayerMark(target, "j_zicang_in_judge", 0)
      return
    end

    local judge_card = data.card
    if not judge_card then
      room:setPlayerMark(target, "j_zicang_in_judge", 0)
      return
    end

    local match_suit = zicang_card.suit == judge_card.suit
    local match_parity = (zicang_card.number % 2) == (judge_card.number % 2)

    if match_suit or match_parity then
      room:moveCardTo(zicang_card_id, Card.PlayerHand, player, fk.ReasonPut, j_qun.name)
      room:setPlayerMark(player, "j_qun_card", zicang_card_id)
      room:setCardMark(zicang_card, "j_qun_mark", 1)

      local new_card = room:printCard("j_zicangxiangzeng", zicang_card.suit, zicang_card.number)
      room:moveCardTo(new_card.id, Card.PlayerJudge, target, fk.ReasonPut, j_qun.name)
      room:setCardMark(new_card, "j_zicang_target", target.id)
      room:setCardMark(new_card, "j_zicang_source", source_id)

      room:setPlayerMark(target, "j_zicang_in_judge", new_card.id)
    else
      source:drawCards(2, j_qun.name)
      room:setPlayerMark(target, "j_zicang_in_judge", 0)
      room:moveCardTo(zicang_card_id, Card.DiscardPile, nil, fk.ReasonPut, j_qun.name)
    end
  end,
})

j_qun:addEffect("filter", {
  handly_cards = function(self, player)
    local qun_card_id = player:getMark("j_qun_card")
    if qun_card_id and qun_card_id ~= 0 then
      local card = Fk:getCardById(qun_card_id)
      if card and card:getMark("j_qun_mark") == 1 then
        return {qun_card_id}
      end
    end
    return {}
  end,
})

-- 测试：指仓相赠判定与囷联动（匹配 → 获得牌 + 新牌入判定区）
j_qun:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_qun.name)
  end)

  FkTest.runInRoom(function()
    local zicang = room:printCard("j_zicangxiangzeng")
    zicang.suit = Card.Heart
    zicang.number = 5
    room:moveCardTo(zicang.id, Card.PlayerJudge, comp2, fk.ReasonPut, "test")
    room:setCardMark(zicang, "j_zicang_source", me.id)
    room:setPlayerMark(comp2, "j_zicang_in_judge", zicang.id)

    local judge_card = room:printCard("peach")
    judge_card.suit = Card.Heart
    judge_card.number = 5
    table.insert(room.draw_pile, 1, judge_card.id)

    room:judge{ who = comp2, reason = "j_zicangxiangzeng", pattern = "." }
  end)
  lu.assertTrue(me:getMark("j_qun_card") ~= 0, "匹配时囷拥有者应获得指仓相赠")  lu.assertEquals(#comp2:getCardIds(Player.Judge), 1, "匹配后新指仓相赠应留在判定区")
end)

-- 测试：指仓相赠判定不匹配 → 原拥有者摸两张牌
j_qun:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_qun.name)
  end)

  FkTest.runInRoom(function()
    local zicang = room:printCard("j_zicangxiangzeng")
    zicang.suit = Card.Heart
    zicang.number = 5
    room:moveCardTo(zicang.id, Card.PlayerJudge, comp2, fk.ReasonPut, "test")
    room:setCardMark(zicang, "j_zicang_source", me.id)
    room:setPlayerMark(comp2, "j_zicang_in_judge", zicang.id)

    local judge_card = room:printCard("slash")
    judge_card.suit = Card.Spade
    judge_card.number = 4
    table.insert(room.draw_pile, 1, judge_card.id)

    local hand_before = #me:getCardIds("h")
    room:judge{ who = comp2, reason = "j_zicangxiangzeng", pattern = "." }
    lu.assertEquals(#me:getCardIds("h"), hand_before + 2, "不匹配时原拥有者摸两张牌")
    lu.assertEquals(#comp2:getCardIds(Player.Judge), 0, "不匹配时判定区应清空")
  end)
end)

return j_qun