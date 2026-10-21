local j_lianpo = fk.CreateSkill {
  name = "j_lianpo",
}

Fk:loadTranslationTable{
  ["j_lianpo"] = "炼魄",
  [":j_lianpo"] = "一名角色死亡时，若其未成为过该技能的目标，你可以令其将体力值调整至3-×，摸4-×张牌并令其失去所有非锁定技。(X为此技能本局游戏中发动过的次数且至多为3)",

  ["#j_lianpo-invoke"] = "炼魄：是否令其还阳？",

  ["$j_lianpo1"] = "亡者魂魄，尽归吾掌！",
  ["$j_lianpo2"] = "炼汝残魄，供吾驱策！",
}

j_lianpo:addEffect(fk.Death, {
  anim_type = "defensive",
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_lianpo.name) then return false end
    if not target or target.dead == false then return false end
    if target:getMark("j_lianpo_marked") > 0 then return false end
    return true
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_lianpo.name, prompt = "#j_lianpo-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 跳过后续 BuryVictim 的埋牌与奖惩（GameRule 检测该 tag 后自动清除）
    room:setTag("SkipGameRule", true)

    -- 标记为目标并累计发动次数（至多 3）
    room:setPlayerMark(target, "j_lianpo_marked", 1)
    room:addPlayerMark(player, "j_lianpo_count", 1)
    local x = player:getMark("j_lianpo_count")
    if x > 3 then x = 3 end

    -- 复活：恢复存活状态，再将体力值调整至 3-x
    room:revivePlayer(target, true, j_lianpo.name)
    room:setPlayerProperty(target, "hp", 3 - x)

    -- 摸 4-x 张牌
    room:drawCards(target, 4 - x, j_lianpo.name)

    -- 失去所有非锁定技
    local lost = {}
    for _, sname in ipairs(target:getSkillNameList()) do
      local sk = Fk.skills[sname]
      if sk and not (sk.tags and sk.tags[Skill.Locked]) then
        table.insert(lost, sname)
      end
    end
    if #lost > 0 then
      room:handleAddLoseSkills(target, table.concat(lost, "|"), nil, true, true)
    end

    -- 你成为炼魄的目标：失去炼魄、摸两张、获得诡智
    if target == player then
      room:handleAddLoseSkills(player, "-" .. j_lianpo.name, nil, true, true)
      room:drawCards(player, 2, j_lianpo.name)
      room:handleAddLoseSkills(player, "j_guizhi", nil, true, true)
    end
  end,
})

-- 测试：死亡时发动炼魄 → 复活、调体力、摸牌
j_lianpo:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_lianpo.name)
  end)

  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1" })
    room:killPlayer{ who = comp3, killer = comp2 }
    lu.assertFalse(comp3.dead, "炼魄应令死亡角色复活")
    lu.assertEquals(comp3.hp, 2, "体力值应调整至 3-x（x=1）")
    lu.assertEquals(#comp3:getCardIds("h"), 3, "应摸 4-x=3 张牌")
    lu.assertEquals(comp3:getMark("j_lianpo_marked"), 1, "应记录成为过目标")
    lu.assertEquals(me:getMark("j_lianpo_count"), 1, "应累计发动次数")
  end)
end)

-- 测试：不发动炼魄则角色正常死亡
j_lianpo:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_lianpo.name)
  end)

  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "" })
    room:killPlayer{ who = comp3, killer = comp2 }
    lu.assertTrue(comp3.dead, "拒绝发动时角色应正常死亡")
    lu.assertEquals(comp3:getMark("j_lianpo_marked"), 0, "不应记录目标")
  end)
end)

return j_lianpo
