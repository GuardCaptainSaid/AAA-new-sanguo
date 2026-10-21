local j_mumou = fk.CreateSkill {
  name = "j_mumou",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_mumou"] = "幕谋",
  [":j_mumou"] = "锁定技，被“炼魄”指定过的角色的出牌阶段开始时，你观看其手牌并使用其中一张（若无可使用的牌，则其失去一点体力）；当你受到致命伤害时，转移给该角色。当有“炼魄”角色死亡或你成为“炼魄”角色时，你失去“炼魄”并摸两张牌，然后获得“诡智”。",

  ["#j_mumou-choose"] = "幕谋：正面观看其手牌，选择一张牌使用",
  ["#j_mumou-target"] = "幕谋：选择这张牌的使用目标",
  ["#j_mumou-view"] = "幕谋：观看其手牌",
  ["#j_mumou-transfer"] = "幕谋：选择一名“炼魄”角色转移伤害",

  ["$j_mumou1"] = "布幕于前，谋定于后！",
  ["$j_mumou2"] = "汝之败亡，尽在吾算中！",
}

-- 转换：失去炼魄、摸两张、获得诡智（炼魄复活时其“失去所有非锁定技”已移除炼魄，故不强制要求持有）
local function convert(player)
  local room = player.room
  if player:hasSkill("j_lianpo") then
    room:handleAddLoseSkills(player, "-j_lianpo", nil, true, true)
  end
  room:drawCards(player, 2, j_mumou.name)
  if not player:hasSkill("j_guizhi") then
    room:handleAddLoseSkills(player, "j_guizhi", nil, true, true)
  end
end
-- 供【炼魄】在“成为炼魄角色”结算完成后调用（保证顺序：先完成炼魄全部结算，再失去炼魄、摸两张、获得诡智）
j_mumou.__convert = convert

-- 有“炼魄”角色死亡 → 转换
j_mumou:addEffect(fk.Death, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_mumou.name) then return false end
    if not player:hasSkill("j_lianpo") then return false end
    -- 仅当“炼魄”角色真正死亡时转换；被炼魄复活的目标 dead=false，不得误判死亡
    if not target or target.dead == false then return false end
    return target:getMark("@j_lianpo_marked") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    convert(player)
  end,
})

-- 被“炼魄”指定过的角色的出牌阶段开始时：观看其手牌并使用其中一张
j_mumou:addEffect(fk.EventPhaseStart, {
  anim_type = "control",
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_mumou.name) then return false end
    if target == player then return false end
    if not target or target:isAlive() == false then return false end
    if target.phase ~= Player.Play then return false end
    return target:getMark("@j_lianpo_marked") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local usable = {}
    for _, id in ipairs(target:getCardIds("h")) do
      local c = Fk:getCardById(id)
      if c.type == Card.TypeBasic or (c.type == Card.TypeTrick and c.sub_type ~= Card.SubtypeDelayedTrick) then
        table.insert(usable, id)
      end
    end
    -- 无可使用的牌：其失去一点体力
    if #usable == 0 then
      room:loseHp(target, 1, j_mumou.name)
      return
    end
    -- 正面朝上观看其手牌并选择一张（AskForCardsAndChoice 界面同时展示牌面与选牌）
    local selected, _ = room:askToChooseCardsAndChoice(player, {
      cards = target:getCardIds("h"),
      skill_name = j_mumou.name,
      prompt = "#j_mumou-choose",
      choices = { "OK" },
      min_num = 1,
      max_num = 1,
    })
    local cid = selected and selected[1]
    local card
    if cid then
      local c = Fk:getCardById(cid)
      if c.type == Card.TypeBasic or (c.type == Card.TypeTrick and c.sub_type ~= Card.SubtypeDelayedTrick) then
        card = c
      end
    end
    if not card then
      -- 未选或选了不可用牌：自动取第一张可用牌
      card = Fk:getCardById(usable[1])
    end
    if target:isAlive() then
      -- 计算合法目标并让玩家指定目标去使用
      local targets = table.filter(room.alive_players, function(p)
        return player:canUseTo(card, p)
      end)
      if #targets == 0 then return end
      local card_skill = card:getSkill(player)
      local min_num = card_skill and card_skill:getMinTargetNum(player) or 1
      local max_num = card_skill and card_skill:getMaxTargetNum(player, card) or #targets
      if max_num < 1 then max_num = #targets end
      if max_num > #targets then max_num = #targets end
      if min_num > max_num then min_num = max_num end
      local tos = room:askToChoosePlayers(player, {
        targets = targets,
        min_num = min_num,
        max_num = max_num,
        skill_name = j_mumou.name,
        prompt = "#j_mumou-target",
      })
      if tos and #tos > 0 then
        room:useCard{ from = player, tos = tos, card = card, skillName = j_mumou.name }
      end
    end
  end,
})

-- 受到致命伤害时，转移给“炼魄”角色
j_mumou:addEffect(fk.DamageInflicted, {
  anim_type = "defensive",
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_mumou.name) then return false end
    if target ~= player then return false end
    if data.damage < player.hp then return false end
    return table.find(player.room.alive_players, function(p)
      return p ~= player and p:getMark("@j_lianpo_marked") > 0
    end) ~= nil
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local candidates = table.filter(room.alive_players, function(p)
      return p ~= player and p:getMark("@j_lianpo_marked") > 0
    end)
    if #candidates == 0 then return false end
    if #candidates == 1 then
      event:setCostData(self, { to = candidates[1] })
      return true
    end
    local t = room:askToChoosePlayers(player, {
      targets = candidates,
      min_num = 1,
      max_num = 1,
      skill_name = j_mumou.name,
      prompt = "#j_mumou-transfer",
    })
    if t and #t > 0 then
      event:setCostData(self, { to = t[1] })
      return true
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    local to = event:getCostData(self).to
    if to and to:isAlive() then
      data.to = to
    end
  end,
})

-- 测试：炼魄角色死亡 → 失去炼魄、摸两张、获得诡智
j_mumou:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_mumou.name)
    room:handleAddLoseSkills(me, "j_lianpo")
    room:setPlayerMark(comp3, "@j_lianpo_marked", 1)
  end)

  FkTest.runInRoom(function()
    room:killPlayer{ who = comp3, killer = comp2 }
    lu.assertFalse(me:hasSkill("j_lianpo"), "应失去炼魄")
    lu.assertTrue(me:hasSkill("j_guizhi"), "应获得诡智")
    lu.assertEquals(#me:getCardIds("h"), 2, "应摸两张牌")
  end)
end)

-- 测试：被炼魄角色出牌阶段开始，正面观看其手牌并选择一张，指定目标使用
j_mumou:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_mumou.name)
    room:setPlayerMark(comp3, "@j_lianpo_marked", 1)
    local c1 = room:printCard("slash", Card.Spade, 5)
    room:obtainCard(comp3, { c1.id }, true, fk.ReasonDraw, comp3, "test")
    comp3.phase = Player.Play
  end)

  FkTest.runInRoom(function()
    local use = UseCardData:new{ from = comp3, card = Fk:cloneCard("slash"), tos = {} }
    -- askToChooseCardsAndChoice（选牌：cards+choice）+ askToChoosePlayers（选目标：comp2）
    FkTest.setNextReplies(me, { { cards = { comp3:getCardIds("h")[1] }, choice = "OK" }, FkTest.ReplyChoosePlayer({ comp2 }) })
    room.logic:trigger(fk.EventPhaseStart, comp3, use)
    lu.assertEquals(comp3.hp, 4, "有可用牌时不应失去体力")
    lu.assertEquals(#comp3:getCardIds("h"), 0, "使用后其手牌应被消耗")
  end)
end)

-- 测试：被炼魄角色出牌阶段开始，无可使用牌时其失去一点体力
j_mumou:addTest(function(room, me)
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_mumou.name)
    room:setPlayerMark(comp3, "@j_lianpo_marked", 1)
    -- 给 comp3 全是装备牌（无可使用的牌）
    local c1 = room:printCard("crossbow", Card.Spade, 1)
    local c2 = room:printCard("eight_diagram", Card.Heart, 2)
    room:obtainCard(comp3, { c1.id, c2.id }, true, fk.ReasonDraw, comp3, "test")
    comp3.phase = Player.Play
  end)

  FkTest.runInRoom(function()
    local use = UseCardData:new{ from = comp3, card = Fk:cloneCard("slash"), tos = {} }
    room.logic:trigger(fk.EventPhaseStart, comp3, use)
    lu.assertEquals(comp3.hp, 3, "无可使用牌应失去一点体力")
  end)
end)

-- 测试：受到致命伤害时转移给炼魄角色
j_mumou:addTest(function(room, me)
  local comp2 = room.players[2]
  local comp3 = room.players[3]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_mumou.name)
    room:setPlayerMark(comp3, "@j_lianpo_marked", 1)
  end)

  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { FkTest.ReplyChoosePlayer({ comp3 }) })
    room:damage{ from = comp2, to = me, damage = 4, damageType = fk.NormalDamage }
    lu.assertEquals(me.hp, 4, "致命伤害应转移，me 不受伤害")
    lu.assertEquals(comp3.hp, 0, "伤害应转移给炼魄角色")
  end)
end)

-- 测试：指定自己为目标（自己死亡被炼魄复活）→ 先完成炼魄（复活、调体、摸4-x、失技），
--       再失去“炼魄”并摸两张，然后获得“诡智”
j_mumou:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_mumou.name)
    room:handleAddLoseSkills(me, "j_lianpo")
    local ids = me:getCardIds("h")
    if #ids > 0 then
      room:moveCards{ ids = ids, toArea = Card.DiscardPile, moveReason = fk.ReasonPut }
    end
  end)

  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "1" })
    room:killPlayer{ who = me, killer = comp2 }
    lu.assertFalse(me.dead, "炼魄应复活自己")
    lu.assertEquals(me.hp, 2, "复活后体力应调整至 3-x（x=1）")
    lu.assertEquals(me:getMark("@j_lianpo_marked"), 1, "应成为“炼魄”角色")
    lu.assertFalse(me:hasSkill("j_lianpo"), "炼魄结算后应失去炼魄")
    lu.assertTrue(me:hasSkill("j_guizhi"), "最后应获得诡智")
    -- 炼魄摸 4-x=3 张 + 幕谋摸 2 张 = 5 张（复活时手牌保留为空，死亡弃牌不影响）
    lu.assertEquals(#me:getCardIds("h"), 5, "应先摸炼魄的3张，再摸幕谋的2张")
  end)
end)

return j_mumou
