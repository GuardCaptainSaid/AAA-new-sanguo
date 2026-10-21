local j_guizhi = fk.CreateSkill {
  name = "j_guizhi",
}

Fk:loadTranslationTable{
  ["j_guizhi"] = "诡智",
  [":j_guizhi"] = "每种牌名限一次，每轮开始时，你记录一种牌名。其他角色使用与你本轮记录过的“诡智”牌牌名相同的牌时，其失去一点体力，然后你摸一张牌。出牌阶段，你可以将x+1张牌当“诡智”记录过的牌使用。（x为本轮此技能发动次数）",

  ["#j_guizhi-record"] = "诡智：记录一种牌名",

  ["$j_guizhi1"] = "虚实之间，生死一线！",
  ["$j_guizhi2"] = "谋而诡，诡而胜！",
}

-- 每轮开始时：清空本轮发动次数，并记录一种牌名（每种牌名限一次）
j_guizhi:addEffect(fk.RoundStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(j_guizhi.name)
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "j_guizhi_round", 0)
    local records = room:getTag("j_guizhi_records") or {}
    local choices = {}
    for _, name in ipairs(Fk:getAllCardNames("btde", true)) do
      if not records[name] then
        table.insert(choices, name)
      end
    end
    if #choices == 0 then return false end
    local c = room:askToChoice(player, {
      choices = choices,
      skill_name = j_guizhi.name,
      prompt = "#j_guizhi-record",
    })
    if c and c ~= "" then
      event:setCostData(self, { name = c })
      return true
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local name = event:getCostData(self).name
    local records = room:getTag("j_guizhi_records") or {}
    records[name] = true
    room:setTag("j_guizhi_records", records)
    local currents = room:getTag("j_guizhi_current") or {}
    currents[player.id] = name
    room:setTag("j_guizhi_current", currents)
  end,
})

-- 其他角色使用与本轮记录牌名相同的牌时：其失去一点体力，你摸一张牌
j_guizhi:addEffect(fk.CardUsing, {
  anim_type = "control",
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_guizhi.name) then return false end
    if not data or not data.card then return false end
    if data.from == player then return false end
    local currents = player.room:getTag("j_guizhi_current") or {}
    local rec = currents[player.id]
    if not rec then return false end
    return data.card.trueName == rec
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if data.from and not data.from.dead then
      room:loseHp(data.from, 1, j_guizhi.name)
    end
    room:drawCards(player, 1, j_guizhi.name)
  end,
})

-- 出牌阶段：将 x+1 张牌当本轮记录过的牌使用
j_guizhi:addEffect("viewas", {
  anim_type = "offensive",
  card_num = function(self, player)
    return player:getMark("j_guizhi_round") + 1
  end,
  card_filter = function(self, player, to_select, selected, selected_targets)
    return #selected < player:getMark("j_guizhi_round") + 1 and
      table.contains(player:getCardIds("h"), to_select)
  end,
  view_as = function(self, player, cards)
    local currents = player.room:getTag("j_guizhi_current") or {}
    local rec = currents[player.id]
    if not rec then return end
    if #cards ~= player:getMark("j_guizhi_round") + 1 then return end
    local card = Fk:cloneCard(rec)
    card.skillName = j_guizhi.name
    for _, id in ipairs(cards) do
      card:addSubcard(id)
    end
    return card
  end,
  can_use = function(self, player)
    local currents = player.room:getTag("j_guizhi_current") or {}
    return currents[player.id] ~= nil and
      #player:getCardIds("h") >= player:getMark("j_guizhi_round") + 1
  end,
  enabled_at_play = function(self, player)
    local currents = player.room:getTag("j_guizhi_current") or {}
    return currents[player.id] ~= nil
  end,
  after_use = function(self, player, use)
    if use and use.card and use.card.skillName == j_guizhi.name then
      player.room:addPlayerMark(player, "j_guizhi_round", 1)
    end
  end,
})

-- 测试：每轮开始时记录一种牌名（每种限一次）
j_guizhi:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_guizhi.name)
  end)

  FkTest.runInRoom(function()
    FkTest.setNextReplies(me, { "slash" })
    local use = UseCardData:new{ from = me, card = Fk:cloneCard("slash"), tos = {} }
    room.logic:trigger(fk.RoundStart, me, use)
    local currents = room:getTag("j_guizhi_current") or {}
    lu.assertEquals(currents[me.id], "slash", "应记录牌名")
    local records = room:getTag("j_guizhi_records") or {}
    lu.assertTrue(records["slash"], "应记录到全局限一次集合")
  end)
end)

-- 测试：其他角色使用同名牌时失去体力，诡智拥有者摸牌
j_guizhi:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_guizhi.name)
    room:setTag("j_guizhi_records", { ["slash"] = true })
    room:setTag("j_guizhi_current", { [me.id] = "slash" })
  end)

  FkTest.runInRoom(function()
    local use = UseCardData:new{ from = comp2, card = Fk:cloneCard("slash"), tos = {} }
    room.logic:trigger(fk.CardUsing, comp2, use)
    lu.assertEquals(comp2.hp, 3, "使用同名牌应失去一点体力")
    lu.assertEquals(#me:getCardIds("h"), 1, "诡智拥有者应摸一张牌")
  end)
end)

-- 测试：转化 x+1 张牌为记录过的牌
j_guizhi:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_guizhi.name)
    room:setTag("j_guizhi_current", { [me.id] = "slash" })
    local c1 = room:printCard("dismantlement", Card.Spade, 5)
    local c2 = room:printCard("snatch", Card.Heart, 6)
    room:obtainCard(me, { c1, c2 }, true, fk.ReasonDraw, me, "test")
    local skel = Fk.skills[j_guizhi.name]:getSkeleton()
    local eff = skel.effects[1]

    -- 第一次：1 张牌转化（x=0）
    local card1 = eff:viewAs(me, { c1.id })
    lu.assertNotNil(card1, "第一次应能以 1 张牌转化")
    lu.assertEquals(card1.name, "slash")
    lu.assertEquals(card1.type, Card.TypeBasic)

    -- 第二次：需 2 张牌（x=1）
    room:addPlayerMark(me, "j_guizhi_round", 1)
    local card2 = eff:viewAs(me, { c1.id })
    lu.assertNil(card2, "x=1 时 1 张牌不足以转化")
    local card3 = eff:viewAs(me, { c1.id, c2.id })
    lu.assertNotNil(card3, "x=1 时应能以 2 张牌转化")
  end)
end)

return j_guizhi
