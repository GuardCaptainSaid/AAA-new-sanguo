local j_jianzhi = fk.CreateSkill {
  name = "j_jianzhi",
  derived_piles = "j_jianzhi",
}

Fk:loadTranslationTable{
  ["j_jianzhi"] = "间智",
  [":j_jianzhi"] = "当你成为一张牌的目标时，你记录该牌牌名；当你使用牌被抵消时，你记录抵消牌的牌名。你可以将一张“间谋”牌当作已记录的牌名使用，并移除一张该牌名的记录。回合结束时，你可以弃置至多三张“间谋”牌记录牌名。同名记录可叠加。",

  ["#j_jianzhi-turnend"] = "间智：弃置至多三张“间谋”牌记录牌名",
}

-- 已记录牌名存储（玩家 mark，同步到客户端；interaction/enabled_at_play 客户端会读）
-- 说明：同名记录不去重，按条累加（记录算次数、可叠加）
local function get_records(player)
  return player:getTableMark("j_jianzhi_records")
end

-- 记录牌名时，印一张同名实体牌置于武将牌上的"间智"私人牌堆（与计程昱「垒」一致：
-- 武将牌上出现"间智"标记，点击可查看里面记录/拥有的牌；该堆仅作展示，不视为手牌）
local function addRecordCard(room, player, name)
  if not name or name == "" then return end
  local card = room:printCard(name)
  if not card then return end
  room:moveCards{
    ids = { card.id },
    to = player,
    toArea = Card.PlayerSpecial,
    specialName = "j_jianzhi",
    moveReason = fk.ReasonPut,
    skillName = j_jianzhi.name,
  }
end

-- 移除记录时，同步移走武将牌"间智"堆中对应的同名实体牌（注意：从私人牌堆移出必须带 from）
local function removeRecordCard(room, player, name)
  local pile = player:getPile("j_jianzhi")
  for _, id in ipairs(pile) do
    if Fk:getCardById(id).name == name then
      room:moveCards{
        ids = { id },
        from = player,
        toArea = Card.DiscardPile,
        moveReason = fk.ReasonPut,
        skillName = j_jianzhi.name,
      }
      return
    end
  end
end

-- 追加一条记录（同名可叠加，不做去重）
local function add_record(player, name)
  if not name or name == "" then return end
  local records = get_records(player)
  local new = {}
  for _, n in ipairs(records) do
    table.insert(new, n)
  end
  table.insert(new, name)
  player.room:setPlayerMark(player, "j_jianzhi_records", new)
  addRecordCard(player.room, player, name)
end

-- 移除一条同名记录（只消耗一条，其余同名记录保留）
local function remove_record(player, name)
  local records = get_records(player)
  if not table.contains(records, name) then return end
  local removed = false
  local new = {}
  for _, n in ipairs(records) do
    if not removed and n == name then
      removed = true
    else
      table.insert(new, n)
    end
  end
  player.room:setPlayerMark(player, "j_jianzhi_records", new)
  removeRecordCard(player.room, player, name)
end

-- 成为一张牌的目标时：记录该牌牌名（同名可叠加）
j_jianzhi:addEffect(fk.TargetConfirmed, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_jianzhi.name) then return false end
    if player.dead then return false end
    if data.to ~= player then return false end
    if not data.card then return false end
    local name = data.card.trueName
    return name ~= nil and name ~= ""
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    add_record(player, data.card.trueName)
  end,
})

-- 你使用牌被抵消时：记录抵消牌的牌名（同名可叠加）
j_jianzhi:addEffect(fk.CardRespondFinished, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_jianzhi.name) then return false end
    if player.dead then return false end
    -- data.from 为响应者，data.card 为响应牌（抵消牌），data.responseToEvent 为被响应事件
    if not data.responseToEvent then return false end
    local use = data.responseToEvent.use
    if not use or use.from ~= player then return false end
    local name = data.card and data.card.trueName
    return name ~= nil and name ~= ""
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    add_record(player, data.card.trueName)
  end,
})

-- 取手牌中带“间谋”标记的牌
local function get_jianmou_hand_ids(player)
  return table.filter(player:getCardIds("h"), function(id)
    return Fk:getCardById(id):getMark("@@j_jianmou-inhand") > 0
  end)
end

-- 回合结束时：你可以弃置至多三张“间谋”牌，记录其牌名（每张各记一条，同名可叠加）
j_jianzhi:addEffect(fk.TurnEnd, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_jianzhi.name) then return false end
    if player.dead then return false end
    if target ~= player then return false end
    return #get_jianmou_hand_ids(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local ids = get_jianmou_hand_ids(player)
    if #ids == 0 then return end
    local chosen = room:askToChooseCards(player, {
      target = player,
      flag = { card_data = { { "j_jianmou", ids } } },
      min = 1,
      max = math.min(3, #ids),
      skill_name = j_jianzhi.name,
      prompt = "#j_jianzhi-turnend",
      cancelable = true,
    })
    if #chosen == 0 then return end

    -- 逐张记录牌名（同名各记一条，可叠加）
    local names = {}
    for _, cid in ipairs(chosen) do
      local card = Fk:getCardById(cid)
      if card and card.trueName and card.trueName ~= "" then
        table.insert(names, card.trueName)
      end
      -- 弃置后该牌不再是“间谋”牌，清除标记避免之后重复生效
      room:setCardMark(card, "@@j_jianmou-inhand", 0)
    end
    room:throwCard(chosen, j_jianzhi.name, player, player)
    for _, name in ipairs(names) do
      add_record(player, name)
    end
  end,
})

-- 将一张“间谋”牌当作已记录的牌名使用，并移除一张该牌名的记录
j_jianzhi:addEffect("viewas", {
  anim_type = "offensive",
  card_num = 1,
  card_filter = function(self, player, to_select, selected, selected_targets)
    if #selected >= 1 then return false end
    if not table.contains(player:getCardIds("h"), to_select) then return false end
    return Fk:getCardById(to_select):getMark("@@j_jianmou-inhand") > 0
  end,
  interaction = function(self, player)
    local records = get_records(player)
    if #records == 0 then return nil end
    -- 记录可同名叠加，弹窗按牌名去重展示（使用一次只消耗其中一条）
    local names = {}
    for _, n in ipairs(records) do
      if not table.contains(names, n) then
        table.insert(names, n)
      end
    end
    return UI.CardNameBox { choices = names, all_choices = names }
  end,
  view_as = function(self, player, cards)
    if #cards ~= 1 then return end
    if not self.interaction.data then return end
    local name = self.interaction.data
    if not table.contains(get_records(player), name) then return end
    local card = Fk:cloneCard(name)
    card.skillName = j_jianzhi.name
    card:addSubcard(cards[1])
    return card
  end,
  enabled_at_play = function(self, player)
    -- 客户端也会执行此判定，须用 mark（同步到客户端）
    return #get_records(player) > 0
  end,
  after_use = function(self, player, use)
    local used = self.interaction.data
    if used then
      remove_record(player, used)
    end
  end,
})

-- 测试：成为目标时记录牌名（每种一次，武将牌"间智"堆同步实体记录牌）
j_jianzhi:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jianzhi.name)
  end)
  FkTest.runInRoom(function()
    local aim = AimData:new{ from = comp2, card = Fk:cloneCard("slash", Card.Spade, 5), tos = { me }, to = me }
    room.logic:trigger(fk.TargetConfirmed, me, aim)
    lu.assertTrue(table.contains(me:getTableMark("j_jianzhi_records"), "slash"), "应记录杀牌名")
    local pile = me:getPile("j_jianzhi")
    lu.assertEquals(#pile, 1, "记录后武将牌上应有 1 张记录牌")
    lu.assertEquals(Fk:getCardById(pile[1]).name, "slash", "记录牌应为同名实体牌")
  end)
end)

-- 测试：使用牌被抵消时记录抵消牌的牌名
j_jianzhi:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jianzhi.name)
  end)
  FkTest.runInRoom(function()
    local use = UseCardData:new{ from = me, card = Fk:cloneCard("slash"), tos = {} }
    local effect = CardEffectData:new{ use = use }
    local resp = RespondCardData:new{ from = comp2, card = Fk:cloneCard("jink"), responseToEvent = effect }
    room.logic:trigger(fk.CardRespondFinished, comp2, resp)
    lu.assertTrue(table.contains(me:getTableMark("j_jianzhi_records"), "jink"), "应记录抵消牌（闪）牌名")
  end)
end)

-- 测试：同名记录可叠加，转化使用只消耗其中一条
j_jianzhi:addTest(function(room, me)
  local c1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jianzhi.name)
    c1 = room:printCard("slash", Card.Spade, 5)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    room:setCardMark(c1, "@@j_jianmou-inhand", 1)
    room:setPlayerMark(me, "j_jianzhi_records", { "slash", "slash" })
    -- 同步真实游戏流程：记录"杀"时武将牌"间智"堆应有同名实体牌
    local rec = room:printCard("slash")
    room:moveCards{ ids = { rec.id }, to = me, toArea = Card.PlayerSpecial, specialName = "j_jianzhi", moveReason = fk.ReasonPut, skillName = "test" }
    local rec2 = room:printCard("slash")
    room:moveCards{ ids = { rec2.id }, to = me, toArea = Card.PlayerSpecial, specialName = "j_jianzhi", moveReason = fk.ReasonPut, skillName = "test" }
  end)
  FkTest.runInRoom(function()
    local skel = Fk.skills[j_jianzhi.name]:getSkeleton()
    local eff
    for _, e in ipairs(skel.effects) do
      if e.viewAs then eff = e break end
    end
    lu.assertNotNil(eff, "应存在 viewas 效果实例")
    -- 引擎中 interaction 为可调用对象且交互后写入 .data；测试直接模拟该数据
    eff.interaction = { data = "slash" }
    local card = eff:viewAs(me, { c1.id })
    lu.assertNotNil(card, "间谋牌应能转化为已记录的牌名")
    lu.assertEquals(card.name, "slash")
    lu.assertEquals(card.skillName, "j_jianzhi")

    local use = UseCardData:new{ from = me, card = card, tos = {} }
    eff:afterUse(me, use)
    local recs = me:getTableMark("j_jianzhi_records")
    lu.assertEquals(#recs, 1, "叠加两条同名记录，使用一次后应剩一条")
    lu.assertEquals(recs[1], "slash", "剩余记录仍为杀")
    lu.assertEquals(#me:getPile("j_jianzhi"), 1, "武将牌“间智”堆只应移走一张同名记录牌")
  end)
end)

-- 测试：回合结束时弃置至多三张“间谋”牌记录牌名（同名叠加）
j_jianzhi:addTest(function(room, me)
  local c1, c2, c3
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_jianzhi.name)
    c1 = room:printCard("slash", Card.Spade, 5)
    c2 = room:printCard("slash", Card.Heart, 6)
    c3 = room:printCard("peach", Card.Diamond, 7)
    room:obtainCard(me, { c1 }, true, fk.ReasonDraw, me, "test")
    room:obtainCard(me, { c2 }, true, fk.ReasonDraw, me, "test")
    room:obtainCard(me, { c3 }, true, fk.ReasonDraw, me, "test")
    room:setCardMark(c1, "@@j_jianmou-inhand", 1)
    room:setCardMark(c2, "@@j_jianmou-inhand", 1)
    room:setCardMark(c3, "@@j_jianmou-inhand", 1)
  end)

  FkTest.runInRoom(function()
    local asked, offered
    local origChoose = room.askToChooseCards
    room.askToChooseCards = function(self, who, params)
      asked = true
      offered = #params.flag.card_data[1][2]
      lu.assertEquals(params.max, 3, "至多三张间谋牌")
      return { c1.id, c2.id }
    end
    local hand_before = #me:getCardIds("h")
    room.logic:trigger(fk.TurnEnd, me, {})
    room.askToChooseCards = origChoose
    lu.assertTrue(asked, "回合结束时应有弃置间谋牌的弹窗")
    lu.assertEquals(offered, 3, "应提供全部 3 张间谋牌供选择")
    lu.assertEquals(#me:getCardIds("h"), hand_before - 2, "应弃置选中的 2 张牌")
    local recs = me:getTableMark("j_jianzhi_records")
    lu.assertEquals(#recs, 2, "两张同名【杀】应记两条记录")
    lu.assertEquals(recs[1], "slash", "记录为杀")
    lu.assertEquals(recs[2], "slash", "同名记录可叠加")
    lu.assertEquals(#me:getPile("j_jianzhi"), 2, "武将牌上应有 2 张记录牌")
  end)
end)

return j_jianzhi
