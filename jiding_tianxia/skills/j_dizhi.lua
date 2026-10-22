local j_dizhi = fk.CreateSkill {
  name = "j_dizhi",
}

Fk:loadTranslationTable{
  ["j_dizhi"] = "缔智",
  [":j_dizhi"] = "每轮每名角色限一次，当一名角色受到伤害时，你可以展示牌堆底一张牌，然后将此牌视为【指仓相赠】置于其判定区（其下回合的判定阶段进行判定，判定时以此牌的花色点数与判定牌对比）。",
}

j_dizhi:addEffect(fk.Damaged, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    local room = player.room
    if not room then return false end
    if not player:hasSkill(j_dizhi.name) then return false end
    if not target:isAlive() then return false end

    local round_count = room:getBanner("RoundCount") or 0
    local round_tag = "j_dizhi_round_" .. round_count
    local used_tag = round_tag .. "_" .. target.id
    if player:getMark(used_tag) > 0 then return false end

    return #room.draw_pile > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_dizhi.name })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if not target:isAlive() then return end
    local round_tag = "j_dizhi_round_" .. (room:getBanner("RoundCount") or 0)
    local used_tag = round_tag .. "_" .. target.id
    room:setPlayerMark(player, used_tag, 1)

    if #room.draw_pile == 0 then
      table.shuffle(room.discard_pile)
      table.insertTable(room.draw_pile, room.discard_pile)
      room.discard_pile = {}
      for _, id in ipairs(room.draw_pile) do
        room:setCardArea(id, Card.DrawPile)
      end
    end

    local bottom_card_id = room.draw_pile[#room.draw_pile]
    local bottom_card = Fk:getCardById(bottom_card_id)
    if not bottom_card then return end

    room:showCards({bottom_card_id}, player, j_dizhi.name)

    -- 徐晃【断粮】同构：牌还是牌堆底那张牌本身，视为【指仓相赠】置于其判定区
    -- （实体牌进判定区，虚拟转化牌用于显示与结算；判定时由"囷"读取这张牌自身花色点数与判定牌对比）
    local vcard = Fk:cloneCard("j_zicangxiangzeng", bottom_card.suit, bottom_card.number)
    vcard:addSubcard(bottom_card_id)
    vcard.skillName = j_dizhi.name
    room:moveCards{
      ids = { bottom_card_id },
      to = target,
      toArea = Card.PlayerJudge,
      virtualEquip = vcard,
      moveReason = fk.ReasonUse,
      skillName = j_dizhi.name,
    }
    room:setCardMark(bottom_card, "j_zicang_target", target.id)
    room:setCardMark(bottom_card, "j_zicang_source", player.id)
    room:setPlayerMark(target, "j_zicang_in_judge", bottom_card_id)
  end,
})

-- 测试：受伤时发动缔智 → 牌堆底牌本身（视为指仓相赠）置入其判定区，不立即判定
j_dizhi:addTest(function(room, me)
  local comp2 = room.players[2]
  local bottom
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_dizhi.name)
    -- 牌堆底：方块5的杀
    bottom = room:printCard("slash", Card.Diamond, 5)
    table.insert(room.draw_pile, bottom.id)
    room:setCardArea(bottom.id, Card.DrawPile)
  end)

  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    room.askToSkillInvoke = function(self, who, params)
      return true
    end
    room:damage{ from = me, to = comp2, damage = 1 }
    room.askToSkillInvoke = origInvoke

    local judge_cards = comp2:getCardIds(Player.Judge)
    lu.assertEquals(#judge_cards, 1, "受伤后其判定区应有一张牌")
    local c = Fk:getCardById(judge_cards[1])
    -- 牌还是牌堆底那张牌本身（徐晃断粮同构），并非新印的指仓相赠
    lu.assertEquals(c.id, bottom.id, "判定区应为牌堆底牌本身")
    lu.assertEquals(c.name, "slash", "判定区实体牌仍为原牌")
    lu.assertEquals(c.suit, Card.Diamond, "判定时读取的花色应为牌堆底牌花色")
    lu.assertEquals(c.number, 5, "判定时读取的点数应为牌堆底牌点数")
    -- 视为【指仓相赠】：虚拟转化牌应可取得
    local vcard = comp2:getVirtualEquip(judge_cards[1])
    lu.assertNotNil(vcard, "应存在虚拟转化（视为指仓相赠）")
    lu.assertEquals(vcard.name, "j_zicangxiangzeng", "虚拟转化牌应为指仓相赠")
    lu.assertEquals(comp2:getMark("j_zicang_in_judge"), judge_cards[1], "应记录判定区指向")
    lu.assertEquals(c:getMark("j_zicang_source"), me.id, "应记录缔智使用者")
    -- 不立即判定：牌仍在判定区（未被结算）
    lu.assertEquals(#comp2:getCardIds(Player.Judge), 1, "牌应留在判定区等待其下回合判定")
  end)
end)

-- 端到端：缔智置入判定区后，其下回合判定阶段按【指仓相赠】结算——判定时读取牌堆底牌（实体）花色点数与判定牌对比，
-- 匹配的判定牌入囷并继续判定（洛神式），失败后判定者摸两张
j_dizhi:addTest(function(room, me)
  local comp2 = room.players[2]
  local bottom
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_dizhi.name)
    room:handleAddLoseSkills(me, "j_qun")
    bottom = room:printCard("slash", Card.Diamond, 5)
    table.insert(room.draw_pile, bottom.id)
    room:setCardArea(bottom.id, Card.DrawPile)
  end)

  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    room.askToSkillInvoke = function(self, who, params) return true end
    room:damage{ from = me, to = comp2, damage = 1 }
    room.askToSkillInvoke = origInvoke

    local judge_cards = comp2:getCardIds(Player.Judge)
    lu.assertEquals(#judge_cards, 1, "判定区应有牌堆底牌")

    -- 模拟判定阶段：判定区牌以虚拟转化（指仓相赠）结算；判定牌1方块9（与牌堆底牌方块5花色相同 → 匹配），判定牌2黑桃4（不匹配）
    local vcard = comp2:getVirtualEquip(judge_cards[1])
    lu.assertNotNil(vcard, "应有虚拟转化")
    local j1 = room:printCard("peach", Card.Diamond, 9)
    local j2 = room:printCard("slash", Card.Spade, 4)
    -- 用 moveCards 正确置顶（同步维护 card_place，避免脏 id 导致判定取不到牌）
    room:moveCards{ ids = { j2.id }, toArea = Card.DrawPile, moveReason = fk.ReasonJustMove, drawPilePosition = 1 }
    room:moveCards{ ids = { j1.id }, toArea = Card.DrawPile, moveReason = fk.ReasonJustMove, drawPilePosition = 1 }
    room:moveCardTo(vcard, Card.Processing, nil, fk.ReasonPut, "phase_judge")
    local hand_before = #comp2:getCardIds("h")
    local eff = CardEffectData:new{ card = vcard, to = comp2, tos = { comp2 } }
    room:doCardEffect(eff)

    -- 匹配的判定牌入囷；失败后判定者摸两张
    lu.assertEquals(#comp2:getPile("j_qun"), 1, "匹配的判定牌应置入囷")
    lu.assertEquals(comp2:getPile("j_qun")[1], j1.id, "囷应为匹配的判定牌")
    lu.assertEquals(#comp2:getCardIds("h"), hand_before + 2, "失败后判定者应摸两张牌")
  end)
end)

return j_dizhi