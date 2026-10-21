local j_qice = fk.CreateSkill {
  name = "j_qice",
}

Fk:loadTranslationTable{
  ["j_qice"] = "奇策",
  [":j_qice"] = "出牌阶段限一次，你可以弃置所有无法指定其他角色的手牌，视为使用等量张随机合法锦囊牌，若有角色因此进入濒死状态，你受到一点伤害并令此技能视为未发动过。",

  ["#j_qice"] = "奇策：弃置所有无法指定其他角色的手牌，视为使用等量张随机合法锦囊牌",

  ["$j_qice1"] = "奇策百出，算无遗策！",
  ["$j_qice2"] = "倾力为国，策定乾坤！",
}

-- 出牌阶段限一次主动技
j_qice:addEffect("active", {
  anim_type = "control",
  prompt = "#j_qice",
  card_num = 0,
  target_num = 0,
  can_use = function(self, player)
    return player:usedSkillTimes(j_qice.name, Player.HistoryPhase) == 0
  end,
  card_filter = Util.FalseFunc,
  target_filter = Util.FalseFunc,
  times = function(self, player)
    return 1 - player:usedSkillTimes(j_qice.name, Player.HistoryPhase)
  end,
  on_use = function(self, room, effect)
    local player = effect.from

    -- 1. 找出所有"无法指定其他角色"的手牌
    -- 不能用 canUseTo：它会注入 fix_targets 强制把目标设为被检查角色，
    -- 导致闪电这类 targetFilter 宽松（mod_target_filter=TrueFunc）的牌对任何人都 canUseTo=true，
    -- 被误判为"能指定其他角色"而不弃。
    -- 用 getAvailableTargets（完整模拟正常使用流程：canUse + 目标过滤）判断是否有除自己外的合法目标。
    local unusable = {}
    for _, id in ipairs(player:getCardIds("h")) do
      local card = Fk:getCardById(id)
      local targets = card:getAvailableTargets(player)
      local canTargetOthers = false
      for _, p in ipairs(targets) do
        if p ~= player then
          canTargetOthers = true
          break
        end
      end
      if not canTargetOthers then
        table.insert(unusable, id)
      end
    end
    if #unusable == 0 then return end

    -- 2. 弃置这些手牌
    room:throwCard(unusable, j_qice.name, player, player)

    -- 3. 收集当前"合法"的普通锦囊（有合法目标或无需目标）
    local legal = {}
    for _, name in ipairs(Fk:getAllCardNames("t")) do
      local card = Fk:cloneCard(name)
      local targets = card:getDefaultTarget(player)
      if #targets > 0 or card:getSkill(player):getMinTargetNum(player) == 0 then
        table.insert(legal, name)
      end
    end

    -- 4. 随机抽取等量张并依次视为使用
    -- 必须经由 askToUseVirtualCard：真人玩家会弹出目标选择窗口（AI 由引擎请求循环自动决策最优目标），
    -- 而非直接 useCard{ tos=getDefaultTarget } 静默指定目标导致不弹窗。
    local n = #unusable
    local pool = table.simpleClone(legal)
    room:setTag("j_qice_running", true)
    room:setTag("j_qice_dying", false)
    local used = 0
    while used < n and #pool > 0 do
      local idx = math.random(#pool)
      local name = table.remove(pool, idx)
      local use = room:askToUseVirtualCard(player, {
        name = name,
        skill_name = j_qice.name,
        -- 不传 prompt：使用默认提示 "奇策：请视为使用 <随机牌名>"，玩家先看到随机牌再选择目标
        extra_data = {
          bypass_times = true,
          extraUse = true,
        },
      })
      if use then
        used = used + 1
      end
      if player.dead then break end
    end
    room:setTag("j_qice_running", false)

    -- 5. 若有角色因此进入濒死：你受到一点伤害并令此技能视为未发动过
    if room:getTag("j_qice_dying") then
      room:damage{ from = nil, to = player, damage = 1, damageType = fk.NormalDamage, skillName = j_qice.name }
      if player:isAlive() then
        player:addSkillUseHistory(j_qice.name, -1)
      end
    end
  end,
})

-- 濒死监听：奇策执行期间若有角色进入濒死则记录
j_qice:addEffect(fk.EnterDying, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_qice.name) then return false end
    return player.room:getTag("j_qice_running") == true
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setTag("j_qice_dying", true)
  end,
})

-- 测试：手牌全为"无法指定其他角色"的牌 → 全部弃置并视为使用随机锦囊
j_qice:addTest(function(room, me)
  local c1, c2, c3
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_qice.name)
    c1 = room:printCard("peach", Card.Heart, 3)
    c2 = room:printCard("jink", Card.Heart, 4)
    c3 = room:printCard("jink", Card.Heart, 5)
    room:obtainCard(me, { c1, c2, c3 }, true, fk.ReasonDraw, me, "test")
    me.phase = Player.Play
  end)

  FkTest.runInRoom(function()
    local before = table.simpleClone(me:getCardIds("h"))
    -- 拦截随机锦囊的目标询问，避免测试环境无人响应请求；记录被询问的锦囊名
    local usedNames = {}
    local orig = room.askToUseVirtualCard
    room.askToUseVirtualCard = function(self, player, params)
      table.insert(usedNames, params.name)
      return { from = player, card = Fk:cloneCard(params.name), tos = {} }
    end
    local sk = Fk.skills[j_qice.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = {}, cards = {} })
    end, {})
    room.askToUseVirtualCard = orig
    -- 被弃置的牌不应再在手牌中
    for _, id in ipairs(before) do
      lu.assertFalse(table.contains(me:getCardIds("h"), id), "无法指定其他角色的手牌应被弃置")
    end
    -- 弃 3 张 → 应依次询问使用 3 张随机锦囊
    lu.assertEquals(#usedNames, 3, "弃 3 张牌应随机询问使用 3 张锦囊")
  end)
end)

-- 测试：手牌含可指定其他角色的牌 → 只弃"无法指定"的牌
j_qice:addTest(function(room, me)
  local s1, s2
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_qice.name)
    s1 = room:printCard("slash", Card.Spade, 2)
    s2 = room:printCard("peach", Card.Heart, 6)
    room:obtainCard(me, { s1, s2 }, true, fk.ReasonDraw, me, "test")
    me.phase = Player.Play
  end)

  FkTest.runInRoom(function()
    local usedNames = {}
    local orig = room.askToUseVirtualCard
    room.askToUseVirtualCard = function(self, player, params)
      table.insert(usedNames, params.name)
      return { from = player, card = Fk:cloneCard(params.name), tos = {} }
    end
    local sk = Fk.skills[j_qice.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = {}, cards = {} })
    end, {})
    room.askToUseVirtualCard = orig
    -- 杀（可指定他人）应保留在手牌
    lu.assertTrue(table.contains(me:getCardIds("h"), s1.id), "可指定其他角色的杀应保留")
    -- 桃（无法指定他人）应被弃置
    lu.assertFalse(table.contains(me:getCardIds("h"), s2.id), "无法指定其他角色的桃应被弃置")
    lu.assertEquals(#usedNames, 1, "弃 1 张牌应随机询问使用 1 张锦囊")
  end)
end)

-- 测试：奇策执行期间进入濒死 → 记录 dying 标记（供副作用使用）
j_qice:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_qice.name)
    room:setTag("j_qice_running", true)
    room:setTag("j_qice_dying", false)
  end)
  FkTest.runInRoom(function()
    room.logic:trigger(fk.EnterDying, comp2, {})
    lu.assertEquals(room:getTag("j_qice_dying"), true, "奇策执行期间濒死应被记录")
    room:setTag("j_qice_running", false)
  end)
end)

-- 测试：手牌含闪电（延时锦囊，不能指定别人）→ 奇策应弃置闪电
j_qice:addTest(function(room, me)
  local l1, l2
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_qice.name)
    l1 = room:printCard("lightning", Card.Spade, 1)
    l2 = room:printCard("peach", Card.Heart, 9)
    room:obtainCard(me, { l1, l2 }, true, fk.ReasonDraw, me, "test")
    me.phase = Player.Play
  end)

  FkTest.runInRoom(function()
    local usedNames = {}
    local orig = room.askToUseVirtualCard
    room.askToUseVirtualCard = function(self, player, params)
      table.insert(usedNames, params.name)
      return { from = player, card = Fk:cloneCard(params.name), tos = {} }
    end
    local sk = Fk.skills[j_qice.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = {}, cards = {} })
    end, {})
    room.askToUseVirtualCard = orig
    lu.assertFalse(table.contains(me:getCardIds("h"), l1.id), "无法指定其他角色的闪电应被弃置")
    lu.assertFalse(table.contains(me:getCardIds("h"), l2.id), "无法指定其他角色的桃应被弃置")
    lu.assertEquals(#usedNames, 2, "弃 2 张牌应随机询问使用 2 张锦囊")
  end)
end)

-- 测试：手牌混合——无中（应弃）、顺手（应保留）、闪电（应弃）
j_qice:addTest(function(room, me)
  local e1, e2, e3
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_qice.name)
    e1 = room:printCard("ex_nihilo", Card.Heart, 7)
    e2 = room:printCard("snatch", Card.Spade, 3)
    e3 = room:printCard("lightning", Card.Spade, 1)
    room:obtainCard(me, { e1, e2, e3 }, true, fk.ReasonDraw, me, "test")
    -- 给相邻的 comp2 发一张牌，让顺手牵羊有合法目标（距离1内有牌角色）
    local gift = room:printCard("slash", Card.Spade, 5)
    room:obtainCard(room.players[2], { gift }, true, fk.ReasonDraw, room.players[2], "test")
    me.phase = Player.Play
  end)

  FkTest.runInRoom(function()
    local usedNames = {}
    local orig = room.askToUseVirtualCard
    room.askToUseVirtualCard = function(self, player, params)
      table.insert(usedNames, params.name)
      return { from = player, card = Fk:cloneCard(params.name), tos = {} }
    end
    local sk = Fk.skills[j_qice.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = {}, cards = {} })
    end, {})
    room.askToUseVirtualCard = orig
    lu.assertFalse(table.contains(me:getCardIds("h"), e1.id), "无中生有（无法指定他人）应被弃置")
    lu.assertFalse(table.contains(me:getCardIds("h"), e3.id), "闪电（无法指定他人）应被弃置")
    lu.assertTrue(table.contains(me:getCardIds("h"), e2.id), "顺手牵羊（可指定他人）应保留")
    lu.assertEquals(#usedNames, 2, "弃 2 张牌应随机询问使用 2 张锦囊")
  end)
end)

-- 测试：随机锦囊必须经由 askToUseVirtualCard 弹出目标选择（带奇策技能名与目标提示）
j_qice:addTest(function(room, me)
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_qice.name)
    c1 = room:printCard("peach", Card.Heart, 3)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    me.phase = Player.Play
  end)

  FkTest.runInRoom(function()
    local calls = {}
    local orig = room.askToUseVirtualCard
    room.askToUseVirtualCard = function(self, player, params)
      table.insert(calls, params)
      return { from = player, card = Fk:cloneCard(params.name), tos = {} }
    end
    local sk = Fk.skills[j_qice.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = {}, cards = {} })
    end, {})
    room.askToUseVirtualCard = orig
    lu.assertEquals(#calls, 1, "弃 1 张牌应询问使用 1 张随机锦囊")
    lu.assertEquals(calls[1].skill_name, "j_qice", "随机锦囊应带奇策技能名")
    -- 默认提示应为 "奇策：请视为使用 <随机牌名>"（先展示随机牌，再选目标）
    lu.assertTrue(string.startswith(calls[1].prompt, "#AskForUseVirtualCard:::"), "应使用默认虚拟牌提示")
    lu.assertTrue(string.find(calls[1].prompt, "j_qice") ~= nil, "默认提示应包含奇策技能名")
    -- 牌名必须是合法的普通锦囊（不含延时锦囊）
    local tricks = Fk:getAllCardNames("t")
    lu.assertTrue(table.contains(tricks, calls[1].name), "随机锦囊名应属于普通锦囊")
  end)
end)

return j_qice
