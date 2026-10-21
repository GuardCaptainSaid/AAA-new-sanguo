local j_hanji = fk.CreateSkill {
  name = "j_hanji",
}

Fk:loadTranslationTable{
  ["j_hanji"] = "捍基",
  [":j_hanji"] = "当你进入濒死状态时，若场上没有角色死亡且游戏人数大于2，你将体力恢复至一点；否则改为摸一张牌。",

  ["$j_hanji1"] = "基业未固，臣岂能先毙！",
  ["$j_hanji2"] = "此身尚在，霸业可期。",
}

-- 进入濒死时：场上无角色死亡且存活人数>2 → 回复至一点体力；存活≤2（单挑）→ 摸一张牌
j_hanji:addEffect(fk.EnterDying, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_hanji.name)
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local alive_num = #room:getAlivePlayers()
    if alive_num > 2 then
      local has_dead = false
      for _, p in ipairs(room.players) do
        if p.dead then
          has_dead = true
          break
        end
      end
      if has_dead then return end
      -- 必须先打标记再回复：固垒②监听的 fk.HpRecover 嵌套在本次回复结算内部触发，
      -- 若等回复结束再标记，固垒将永远错过该时机（死代码）。
      room:setPlayerMark(player, "j_hanji_recover-turn", 1)
      room:recover{
        who = player,
        num = math.max(1 - player.hp, 0),
        recoverBy = player,
        skillName = j_hanji.name,
      }
      -- 回复被防止（如被【扼津】封锁）时撤销标记，避免固垒误结算
      if player.hp < 1 then
        room:setPlayerMark(player, "j_hanji_recover-turn", 0)
      end
    else
      room:drawCards(player, 1, j_hanji.name)
    end
  end,
})

-- 测试：存活人数>2且无死亡 → 回复至一点体力
j_hanji:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_hanji.name)
    room:setPlayerProperty(me, "hp", 0)
  end)

  FkTest.runInRoom(function()
    room.logic:trigger(fk.EnterDying, me, {})
    lu.assertEquals(me.hp, 1, "存活人数>2且无死亡：应回复至一点体力")
  end)
end)

-- 测试：单挑（存活人数=2）→ 不回复，改为摸一张牌
j_hanji:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_hanji.name)
    for i = 3, #room.players do
      room:setPlayerProperty(room.players[i], "dead", true)
    end
    room:setPlayerProperty(me, "hp", 0)
  end)

  FkTest.runInRoom(function()
    local hand_before = #me:getCardIds("h")
    room.logic:trigger(fk.EnterDying, me, {})
    lu.assertEquals(me.hp, 0, "单挑时不应回复体力")
    lu.assertEquals(#me:getCardIds("h"), hand_before + 1, "单挑时应改为摸一张牌")
  end)
end)

return j_hanji
