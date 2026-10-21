local j_ximing = fk.CreateSkill {
  name = "j_ximing",
}

Fk:loadTranslationTable{
  ["j_ximing"] = "戏命",
  [":j_ximing"] = "你的回合开始时，如果你的判定区没有牌，你可以将牌堆中的1张延时锦囊牌置入你的判定区（没有则跳过），然后跳过本回合的判定阶段。",

  ["#j_ximing-invoke"] = "戏命：是否将牌堆中的一张延时锦囊牌随机置于你的判定区，本回合不进行判定（下回合再判定）？",

  ["$j_ximing1"] = "以命为局，戏而弄之。",
  ["$j_ximing2"] = "生死有命，何惧一试？",
}

-- 回合开始时：判定区为空则可将牌堆中延时锦囊置入判定区，并标记跳过判定阶段
j_ximing:addEffect(fk.TurnStart, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_ximing.name) and
      not player.dead and #player:getCardIds("j") == 0
  end,
  on_cost = function(self, event, target, player, data)
    return event.room:askToSkillInvoke(player, { skill_name = j_ximing.name, prompt = "#j_ximing-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 牌堆中的延时锦囊牌
    local ids = table.filter(room.draw_pile, function(cid)
      local c = Fk:getCardById(cid)
      return c.type == Card.TypeTrick and c.sub_type == Card.SubtypeDelayedTrick
    end)
    if #ids > 0 then
      -- 随机一张置入判定区
      local picked = room:tableRandomPick(ids, 1)
      if picked and #picked > 0 then
        room:moveCards{
          ids = { picked[1] },
          to = player,
          toArea = Card.PlayerJudge,
          moveReason = fk.ReasonPut,
          skillName = j_ximing.name,
        }
      end
    end
    -- 无论是否置入，均跳过本回合判定阶段
    room:setPlayerMark(player, "j_ximing-turn", 1)
  end,
})

-- 跳过本回合判定阶段（EventPhaseChanging 的 data 字段是 phase，不是 to）
j_ximing:addEffect(fk.EventPhaseChanging, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target == player and target:getMark("j_ximing-turn") == 1 and
      data.phase == Player.Judge and not data.skipped
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(target, "j_ximing-turn", 0)
    data.skipped = true
  end,
})

-- 测试：回合开始时发动戏命 → 随机置入延时锦囊 → 本回合跳过判定阶段 → 牌留到下回合判
j_ximing:addTest(function(room, me)
  local judgeCard
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_ximing.name)
    judgeCard = room:printCard("lightning", Card.Spade, 1)
  end)

  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    room.askToSkillInvoke = function(self, who, data) return true end
    room.logic:trigger(fk.TurnStart, me, {})
    room.askToSkillInvoke = origInvoke
    lu.assertEquals(#me:getCardIds("j"), 1, "发动戏命后判定区应有 1 张延时锦囊")
    lu.assertEquals(me:getCardIds("j")[1], judgeCard.id, "置入的应为牌堆中随机那张延时锦囊")
    lu.assertEquals(me:getMark("j_ximing-turn"), 1, "应记录本回合跳过判定")
  end)

  FkTest.runInRoom(function()
    local data = { phase = Player.Judge, who = me, reason = "game_rule" }
    room.logic:trigger(fk.EventPhaseChanging, me, data)
    lu.assertTrue(data.skipped, "本回合判定阶段应被跳过")
    lu.assertEquals(me:getMark("j_ximing-turn"), 0, "跳过判定后标记应清零")
    lu.assertEquals(#me:getCardIds("j"), 1, "延时锦囊应保留在判定区，供下回合判定")
  end)
end)

-- 测试：判定区已有牌时，戏命不可发动
j_ximing:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_ximing.name)
    local j1 = room:printCard("indulgence", Card.Heart, 6)
    room:moveCards{ ids = { j1.id }, to = me, toArea = Card.PlayerJudge, moveReason = fk.ReasonPut, skillName = "test" }
  end)

  FkTest.runInRoom(function()
    local invoked = false
    local origInvoke = room.askToSkillInvoke
    room.askToSkillInvoke = function(self, who, data) invoked = true; return true end
    room.logic:trigger(fk.TurnStart, me, {})
    room.askToSkillInvoke = origInvoke
    lu.assertFalse(invoked, "判定区已有牌时不应询问发动戏命")
  end)
end)

-- 测试：牌堆无延时锦囊时仍可发动，跳过判定但判定区保持为空
j_ximing:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_ximing.name)
  end)

  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    room.askToSkillInvoke = function(self, who, data) return true end
    room.logic:trigger(fk.TurnStart, me, {})
    room.askToSkillInvoke = origInvoke
    lu.assertEquals(#me:getCardIds("j"), 0, "牌堆无延时锦囊时判定区应保持为空")
    lu.assertEquals(me:getMark("j_ximing-turn"), 1, "仍应记录本回合跳过判定")
  end)
end)

return j_ximing
