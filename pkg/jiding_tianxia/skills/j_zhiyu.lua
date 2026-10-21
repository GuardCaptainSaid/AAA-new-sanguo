local j_zhiyu = fk.CreateSkill {
  name = "j_zhiyu",
}

Fk:loadTranslationTable{
  ["j_zhiyu"] = "智愚",
  [":j_zhiyu"] = "当你受到伤害时，你可以摸至多5张牌，然后展示所有手牌，若颜色均相同，你弃置伤害来源一张牌，否则此技能本回合失效。",

  ["#j_zhiyu-invoke"] = "智愚：是否发动？",
  ["#j_zhiyu-num"] = "智愚：摸至多5张牌",
  ["#j_zhiyu-discard"] = "智愚：弃置伤害来源一张牌",

  ["$j_zhiyu1"] = "经达权变，大智若愚。",
  ["$j_zhiyu2"] = "愚者千虑，必有一得。",
}

j_zhiyu:addEffect(fk.Damaged, {
  anim_type = "masochism",
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if not player:hasSkill(j_zhiyu.name) or player.dead then return false end
    -- 本回合已失效则不可发动
    if player:getMark("j_zhiyu_fail") > 0 then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_zhiyu.name, prompt = "#j_zhiyu-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 摸至多5张牌（0-5）
    local num = room:askToNumber(player, {
      min = 0,
      max = 5,
      skill_name = j_zhiyu.name,
      prompt = "#j_zhiyu-num",
    })
    if num and num > 0 then
      player:drawCards(num, j_zhiyu.name)
    end
    if player.dead then return end

    -- 展示所有手牌
    local cards = player:getCardIds("h")
    if #cards > 0 then
      player:showCards(cards)
    end

    -- 颜色判断：无手牌视为同色
    local same = true
    if #cards > 0 then
      local color = Fk:getCardById(cards[1]).color
      same = table.every(cards, function(id)
        return Fk:getCardById(id).color == color
      end)
    end

    if same then
      -- 弃置伤害来源一张牌
      local from = data.from
      if from and not from.dead and not from:isNude() then
        -- askToDiscard 已弃置该牌（弃至弃牌堆），此处无需再手动弃牌
        room:askToDiscard(from, {
          min_num = 1,
          max_num = 1,
          include_equip = true,
          skill_name = j_zhiyu.name,
          prompt = "#j_zhiyu-discard",
          cancelable = false,
        })
      end
    else
      -- 本回合失效
      room:setPlayerMark(player, "j_zhiyu_fail", 1)
    end
  end,
})

-- 任意角色回合结束（结束阶段）时重置失效标记
j_zhiyu:addEffect(fk.EventPhaseEnd, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    if data.phase ~= Player.Finish then return false end
    return player:hasSkill(j_zhiyu.name) and player:getMark("j_zhiyu_fail") > 0
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "j_zhiyu_fail", 0)
  end,
})

j_zhiyu:addAI(Fk.Ltk.AI.newInvokeStrategy {
  skill_name = j_zhiyu.name,
  think = function(self, player)
    -- 受伤害后：血线低或手牌少时值得发动摸牌
    return player.hp <= 2 or #player:getCardIds("h") <= 2
  end,
})

-- 测试辅助：askToNumber 回复
local function replyNumber(n)
  return { card = { skill = "spin_skill", subcards = {} }, targets = {}, interaction_data = n }
end

-- 测试：受伤害摸牌同色 → 弃置伤害来源一张牌
j_zhiyu:addTest(function(room, me)
  local comp2 = room.players[2]
  local d1, d2, d3, srcCard
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_zhiyu.name)
    -- 牌堆顶三张同色（红）：摸 3 张后全红
    d1 = room:printCard("slash", Card.Heart, 3)
    d2 = room:printCard("jink", Card.Heart, 4)
    d3 = room:printCard("peach", Card.Heart, 5)
    room:moveCards{ ids = { d1.id, d2.id, d3.id }, toArea = Card.DrawPile, moveReason = fk.ReasonPut, drawPilePosition = 1 }
    -- 伤害来源 comp2 有一张手牌可被弃
    srcCard = room:printCard("slash", Card.Spade, 7)
    room:obtainCard(comp2, { srcCard }, true, fk.ReasonDraw, comp2, "test")
  end)

  FkTest.runInRoom(function()
    local handBefore = #me:getCardIds("h")
    FkTest.setNextReplies(me, { "1", replyNumber(3) })
    FkTest.setNextReplies(comp2, { FkTest.ReplyDiscard({ srcCard.id }) })
    room:damage{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    -- 摸 3 张同色 → 不失效
    lu.assertEquals(#me:getCardIds("h"), handBefore + 3, "应摸 3 张牌")
    lu.assertEquals(me:getMark("j_zhiyu_fail"), 0, "同色时不应失效")
    -- 伤害来源被弃一张牌
    lu.assertFalse(table.contains(comp2:getCardIds("h"), srcCard.id), "伤害来源应被弃一张牌")
  end)
end)

-- 测试：受伤害摸牌非同色 → 本回合失效
j_zhiyu:addTest(function(room, me)
  local comp2 = room.players[2]
  local d1, d2
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_zhiyu.name)
    -- 牌堆顶两张不同色（红+黑）
    d1 = room:printCard("slash", Card.Heart, 3)
    d2 = room:printCard("jink", Card.Spade, 4)
    room:moveCards{ ids = { d1.id, d2.id }, toArea = Card.DrawPile, moveReason = fk.ReasonPut, drawPilePosition = 1 }
  end)

  FkTest.runInRoom(function()
    local handBefore = #me:getCardIds("h")
    FkTest.setNextReplies(me, { "1", replyNumber(2) })
    room:damage{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    -- 摸 2 张不同色 → 本回合失效
    lu.assertEquals(#me:getCardIds("h"), handBefore + 2, "应摸 2 张牌")
    lu.assertEquals(me:getMark("j_zhiyu_fail"), 1, "非同色时应本回合失效")
  end)
end)

-- 测试：失效后再次受伤害不可发动
j_zhiyu:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_zhiyu.name)
    room:setPlayerMark(me, "j_zhiyu_fail", 1)
  end)

  FkTest.runInRoom(function()
    local handBefore = #me:getCardIds("h")
    FkTest.setNextReplies(me, { "1" })
    room:damage{ from = comp2, to = me, damage = 1, damageType = fk.NormalDamage }
    -- 失效期间不发动 → 不摸牌
    lu.assertEquals(#me:getCardIds("h"), handBefore, "失效期间不应摸牌")
  end)
end)

-- 测试：回合结束（结束阶段）重置失效标记
j_zhiyu:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_zhiyu.name)
    room:setPlayerMark(me, "j_zhiyu_fail", 1)
  end)

  FkTest.runInRoom(function()
    room.logic:trigger(fk.EventPhaseEnd, comp2, { phase = Player.Finish })
    lu.assertEquals(me:getMark("j_zhiyu_fail"), 0, "回合结束应重置失效标记")
  end)
end)

return j_zhiyu
