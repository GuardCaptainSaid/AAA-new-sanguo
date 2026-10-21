local j_gulei = fk.CreateSkill {
  name = "j_gulei",
  tags = { Skill.Compulsory },
  derived_piles = "j_gulei",
}

Fk:loadTranslationTable{
  ["j_gulei"] = "固垒",
  [":j_gulei"] = "锁定技，当你拥有「垒」时，若你受到伤害，你移去所有「垒」，防止此伤害并摸等量牌；当你因【捍基】恢复体力时，你获得所有「垒」；你的回合开始时，你使用一张「垒」，此牌不可被响应，否则你失去一点体力。",

  ["#j_gulei-use"] = "固垒：选择一张「垒」使用",

  ["$j_gulei1"] = "深沟高垒，以守为攻。",
  ["$j_gulei2"] = "垒坚则心安，心安则事济。",
}

-- 拥有「垒」时受到伤害：移去所有「垒」，防止此伤害并摸等量牌
j_gulei:addEffect(fk.DamageInflicted, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_gulei.name) and
      #player:getPile("j_gulei") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local pile = player:getPile("j_gulei")
    if #pile == 0 then return end
    local n = #pile
    data:preventDamage()
    room:moveCards{
      ids = pile,
      from = player,
      toArea = Card.DiscardPile,
      moveReason = fk.ReasonPut,
      skillName = j_gulei.name,
    }
    room:drawCards(player, n, j_gulei.name)
  end,
})

-- 因【捍基】恢复体力时：获得所有「垒」
j_gulei:addEffect(fk.HpRecover, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_gulei.name) and
      player:getMark("j_hanji_recover-turn") == 1 and
      #player:getPile("j_gulei") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local pile = player:getPile("j_gulei")
    room:setPlayerMark(player, "j_hanji_recover-turn", 0)
    if #pile > 0 then
      room:obtainCard(player, pile, true, fk.ReasonDraw, player, j_gulei.name)
    end
  end,
})

-- 回合开始时：使用一张「垒」（不可被响应），否则失去一点体力
j_gulei:addEffect(fk.TurnStart, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_gulei.name) and
      #player:getPile("j_gulei") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local pile = player:getPile("j_gulei")
    if #pile == 0 then return end

    -- 弹窗：让玩家从所有「垒」中选择一张使用；不选则失去一点体力
    local chosen = room:askToChooseCards(player, {
      target = player,
      flag = { card_data = { { "j_gulei", pile } } },
      min = 1,
      max = 1,
      skill_name = j_gulei.name,
      prompt = "#j_gulei-use",
      cancelable = true,
    })
    if #chosen == 0 then
      room:loseHp(player, 1, j_gulei.name)
      return
    end

    local card = Fk:getCardById(chosen[1])
    local cs = card:getSkill(player)
    local min_num = cs:getMinTargetNum(player)
    local tos = {}
    if min_num > 0 then
      local targets = card:getAvailableTargets(player)
      if #targets == 0 then
        -- 选中的「垒」无法使用：失去一点体力
        room:loseHp(player, 1, j_gulei.name)
        return
      end
      tos = room:askToChoosePlayers(player, {
        targets = targets,
        min_num = min_num,
        max_num = cs:getMaxTargetNum(player, card),
        skill_name = j_gulei.name,
        prompt = "#j_gulei-use",
        cancelable = true,
      })
      if #tos == 0 then
        room:loseHp(player, 1, j_gulei.name)
        return
      end
    end
    room:useCard{
      from = player,
      tos = tos,
      card = card,
      extraUse = true,
      -- 不可被响应：所有角色均不可打出无懈/闪等响应此牌
      disresponsiveList = room:getAlivePlayers(),
    }
  end,
})

-- 测试：受到伤害 → 移除所有「垒」并摸等量牌
j_gulei:addTest(function(room, me)
  local g1, g2, g3
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_gulei.name)
    g1 = room:printCard("slash", Card.Spade, 1)
    g2 = room:printCard("slash", Card.Spade, 2)
    g3 = room:printCard("peach", Card.Heart, 3)
    room:moveCards{ ids = { g1.id, g2.id, g3.id }, to = me, toArea = Card.PlayerSpecial, specialName = "j_gulei", moveReason = fk.ReasonPut, skillName = "test" }
    lu.assertEquals(#me:getPile("j_gulei"), 3, "前置：垒池应有 3 张")
  end)

  FkTest.runInRoom(function()
    local hand_before = #me:getCardIds("h")
    local dmg = { from = room.players[2], to = me, damage = 1, damageType = fk.NormalDamage }
    dmg.preventDamage = function(self) self.damage = 0; self.prevented = true end
    room.logic:trigger(fk.DamageInflicted, me, dmg)
    lu.assertTrue(dmg.prevented, "伤害应被防止")
    lu.assertEquals(#me:getPile("j_gulei"), 0, "受伤后所有「垒」应被移除")
    lu.assertEquals(#me:getCardIds("h"), hand_before + 3, "应摸与「垒」等量的牌（3 张）")
  end)
end)

-- 测试：回合开始使用「垒」→ 应先弹窗选择一张，选中的被使用
j_gulei:addTest(function(room, me)
  local g1, g2
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_gulei.name)
    g1 = room:printCard("peach", Card.Heart, 3)
    g2 = room:printCard("peach", Card.Diamond, 4)
    room:moveCards{ ids = { g1.id, g2.id }, to = me, toArea = Card.PlayerSpecial, specialName = "j_gulei", moveReason = fk.ReasonPut, skillName = "test" }
  end)

  FkTest.runInRoom(function()
    local asked = false
    local origChoose = room.askToChooseCards
    room.askToChooseCards = function(self, who, params)
      asked = true
      lu.assertEquals(#params.flag.card_data[1][2], 2, "应提供所有「垒」供玩家选择")
      return { params.flag.card_data[1][2][1] }
    end
    room.logic:trigger(fk.TurnStart, me, {})
    room.askToChooseCards = origChoose
    lu.assertTrue(asked, "回合开始应弹窗选择一张「垒」")
    lu.assertEquals(#me:getPile("j_gulei"), 1, "选中的「垒」被使用后应剩 1 张")
  end)
end)

-- 测试：回合开始选择「垒」时取消 → 失去一点体力
j_gulei:addTest(function(room, me)
  local g1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_gulei.name)
    g1 = room:printCard("peach", Card.Heart, 3)
    room:moveCards{ ids = { g1.id }, to = me, toArea = Card.PlayerSpecial, specialName = "j_gulei", moveReason = fk.ReasonPut, skillName = "test" }
  end)

  FkTest.runInRoom(function()
    local origChoose = room.askToChooseCards
    room.askToChooseCards = function(self, who, params) return {} end
    local hp_before = me.hp
    room.logic:trigger(fk.TurnStart, me, {})
    room.askToChooseCards = origChoose
    lu.assertEquals(me.hp, hp_before - 1, "不选择「垒」应失去一点体力")
    lu.assertEquals(#me:getPile("j_gulei"), 1, "未使用「垒」时垒池保持不变")
  end)
end)

-- 测试：真实伤害流程——受到伤害时移除所有「垒」并摸等量牌（回归：moveCards 必须带 from 以识别私人牌堆来源）
j_gulei:addTest(function(room, me)
  local g1, g2, g3
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_gulei.name)
    g1 = room:printCard("slash", Card.Spade, 1)
    g2 = room:printCard("slash", Card.Spade, 2)
    g3 = room:printCard("peach", Card.Heart, 3)
    room:moveCards{ ids = { g1.id, g2.id, g3.id }, to = me, toArea = Card.PlayerSpecial, specialName = "j_gulei", moveReason = fk.ReasonPut, skillName = "test" }
    lu.assertEquals(#me:getPile("j_gulei"), 3, "前置：垒池应有 3 张")
  end)

  FkTest.runInRoom(function()
    local hand_before = #me:getCardIds("h")
    room:damage{ from = room.players[2], to = me, damage = 1, damageType = fk.NormalDamage }
    print("CHECK gulei pile_after_damage=" .. #me:getPile("j_gulei") .. " hand_gain=" .. (#me:getCardIds("h") - hand_before))
    lu.assertEquals(#me:getPile("j_gulei"), 0, "真实伤害流程后所有「垒」应被移除")
    lu.assertEquals(#me:getCardIds("h"), hand_before + 3, "应摸等量 3 张")
  end)
end)

return j_gulei
