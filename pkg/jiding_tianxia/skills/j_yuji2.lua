local j_yuji2 = fk.CreateSkill {
  name = "j_yuji2",
}

Fk:loadTranslationTable{
  ["j_yuji2"] = "豫计",
  [":j_yuji2"] = "每名角色的结束阶段限一次，你可以选择一张其本回合使用过的牌，然后将一张花色与其相同的手牌当做你使用。",

  ["#j_yuji2-choose"] = "豫计：选择%src本回合使用过的一张牌",
  ["#j_yuji2-card"] = "豫计：选择一张与其花色相同的手牌",
  ["#j_yuji2-target"] = "豫计：选择此牌的目标",

  ["$j_yuji21"] = "豫立不虞，计定后动。",
  ["$j_yuji22"] = "汝之所为，早在我计之中。",
}

-- 花色文字（黑桃/红桃/梅花/方块）
local function suitText(suit_str)
  local t = Fk:translate(suit_str)
  if t == suit_str then return suit_str end
  return t
end

-- 记录每名角色本回合使用过的牌（牌名+花色，-turn 标记，回合结束自动清空）
j_yuji2:addEffect(fk.CardUseFinished, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_yuji2.name) or player.dead then return false end
    if data.from == nil or data.card == nil then return false end
    -- 有可用花色才记录
    local subcards = data.card.subcards or {}
    local suit
    if #subcards > 0 then
      suit = Fk:getCardById(subcards[1]):getSuitString()
    else
      suit = data.card:getSuitString()
    end
    return suit ~= "nosuit" and suit ~= "unknown"
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    local subcards = data.card.subcards or {}
    local suit
    if #subcards > 0 then
      suit = Fk:getCardById(subcards[1]):getSuitString()
    else
      suit = data.card:getSuitString()
    end
    local entry = data.card.trueName .. "|" .. suit
    local records = from:getTableMark("j_yuji2_used-turn")
    if not table.contains(records, entry) then
      table.insert(records, entry)
      room:setPlayerMark(from, "j_yuji2_used-turn", records)
    end
  end,
})

-- 每名角色的结束阶段限一次：选择其用过的一张牌，将同花色手牌当做其使用
j_yuji2:addEffect(fk.EventPhaseStart, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target:isAlive() and target.phase == Player.Finish and
      player:hasSkill(j_yuji2.name) and not player.dead and
      #target:getTableMark("j_yuji2_used-turn") > 0 and
      #player:getHandlyIds() > 0 and
      not table.contains(player:getTableMark("j_yuji2_targets-turn"), target.id)
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    -- 1. 选择其本回合使用过的一张牌（按 牌名|花色 去重展示）
    local records = target:getTableMark("j_yuji2_used-turn")
    local display = {}
    local map = {}
    for _, entry in ipairs(records) do
      local name, suit = entry:match("^(.+)|(.+)$")
      if name and suit then
        local text = Fk:translate(name) .. "（" .. suitText(suit) .. "）"
        if not table.contains(display, text) then
          table.insert(display, text)
          map[text] = { name = name, suit = suit }
        end
      end
    end
    if #display == 0 then return false end
    local choice = room:askToChoice(player, {
      choices = display,
      skill_name = j_yuji2.name,
      prompt = "#j_yuji2-choose::" .. target.id,
      cancelable = true,
    })
    if not choice or not map[choice] then return false end
    local picked = map[choice]
    -- 2. 选择一张花色相同的手牌（pattern 7 段格式：trueName|number|suit|place，花色必须在第 3 段）
    local cards = room:askToCards(player, {
      min_num = 1,
      max_num = 1,
      include_equip = false,
      pattern = ".|.|" .. picked.suit .. "|hand",
      skill_name = j_yuji2.name,
      prompt = "#j_yuji2-card",
      cancelable = true,
    })
    if #cards == 0 then return false end
    -- 3. 选择目标（按该牌的合法目标，以豫计拥有者“我”为使用者计算）
    local use_card = Fk:cloneCard(picked.name)
    use_card.skillName = j_yuji2.name
    use_card:addSubcard(cards[1])
    local cs = use_card:getSkill(player)
    local valid = {}
    for _, p in ipairs(room:getAlivePlayers()) do
      if cs:targetFilter(player, p, {}, use_card.subcards, use_card, nil) then
        table.insert(valid, p)
      end
    end
    local tos = {}
    if #valid > 0 then
      tos = room:askToChoosePlayers(player, {
        targets = valid,
        min_num = 1,
        max_num = 1,
        skill_name = j_yuji2.name,
        prompt = "#j_yuji2-target",
        cancelable = true,
      })
      if tos == nil or #tos == 0 then return false end
    end
    event:setCostData(self, { to = target, card = use_card, tos = tos })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 记录本回合已对该角色发动过（每名角色的结束阶段限一次）
    local used_targets = player:getTableMark("j_yuji2_targets-turn")
    if not table.contains(used_targets, target.id) then
      table.insert(used_targets, target.id)
      room:setPlayerMark(player, "j_yuji2_targets-turn", used_targets)
    end
    local cost = event:getCostData(self)
    -- 当做“我”（豫计拥有者）使用
    room:useCard{
      from = player,
      tos = cost.tos,
      card = cost.card,
      extraUse = true,
    }
  end,
})

-- 测试：他人结束阶段，选择其用过的一张牌 → 花色相同的手牌被选中，由“我”使用
j_yuji2:addTest(function(room, me)
  local comp2 = room.players[2]
  local s1, s2, h1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_yuji2.name)
    -- comp2 本回合用过的牌：黑桃杀（记录 entry = slash|spade）
    s1 = room:printCard("slash", Card.Spade, 7)
    -- me 手牌：黑桃闪 + 红桃桃
    s2 = room:printCard("jink", Card.Spade, 2)
    h1 = room:printCard("peach", Card.Heart, 3)
    room:obtainCard(me, { s2, h1 }, true, fk.ReasonDraw, me, "test")
    room:setPlayerMark(comp2, "j_yuji2_used-turn", { "slash|spade" })
    comp2.phase = Player.Finish
  end)

  FkTest.runInRoom(function()
    local choiceText = nil
    local origChoice = room.askToChoice
    room.askToChoice = function(self, who, params)
      choiceText = params.choices[1]
      return choiceText
    end
    local patternSeen = nil
    local origCards = room.askToCards
    room.askToCards = function(self, who, params)
      patternSeen = params.pattern
      local cards = table.filter(who:getCardIds("h"), function(cid)
        return Exppattern:Parse(params.pattern):match(Fk:getCardById(cid))
      end)
      lu.assertEquals(#cards, 1, "同花色手牌应恰好 1 张可被 pattern 选出")
      lu.assertEquals(cards[1], s2.id, "选出的应是黑桃手牌")
      return { cards[1] }
    end
    local origChoosePlayers = room.askToChoosePlayers
    room.askToChoosePlayers = function(self, who, params)
      return { params.targets[1] }
    end
    local useFrom, useCard
    local origUse = room.useCard
    room.useCard = function(self, params)
      useFrom = params.from
      useCard = params.card
      origUse(self, params)
    end
    room.logic:trigger(fk.EventPhaseStart, comp2, {})
    room.askToChoice = origChoice
    room.askToCards = origCards
    room.askToChoosePlayers = origChoosePlayers
    room.useCard = origUse
    lu.assertNotNil(choiceText, "应弹窗选择其本回合用过的一张牌")
    lu.assertEquals(patternSeen, ".|.|spade|hand", "选牌 pattern 的花色应位于第 3 段")
    lu.assertNotNil(useCard, "应实际使用牌")
    lu.assertEquals(useFrom.id, me.id, "使用者应是豫计拥有者（我），而不是结束阶段角色")
    lu.assertFalse(table.contains(me:getCardIds("h"), s2.id), "选中的黑桃手牌应被当杀使用掉")
  end)
end)

-- 测试：自己的回合结束阶段也能发动豫计（记录自己本回合用过的牌）
j_yuji2:addTest(function(room, me)
  local comp2 = room.players[2]
  local s1, s2, h1
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_yuji2.name)
    -- me 本回合用过的牌：黑桃杀（记录到 me 身上）
    s1 = room:printCard("slash", Card.Spade, 7)
    room:obtainCard(me, { s1 }, true, fk.ReasonDraw, me, "test")
    room:useCard{ from = me, card = Fk:getCardById(s1.id), tos = { comp2 } }
    -- me 手牌：黑桃闪 + 红桃桃
    s2 = room:printCard("jink", Card.Spade, 2)
    h1 = room:printCard("peach", Card.Heart, 3)
    room:obtainCard(me, { s2, h1 }, true, fk.ReasonDraw, me, "test")
    me.phase = Player.Finish
  end)

  FkTest.runInRoom(function()
    lu.assertGreater(#me:getTableMark("j_yuji2_used-turn"), 0, "自己回合用过的牌应被记录")
    local choiceText = nil
    local origChoice = room.askToChoice
    room.askToChoice = function(self, who, params)
      choiceText = params.choices[1]
      return choiceText
    end
    local origCards = room.askToCards
    room.askToCards = function(self, who, params)
      local cards = table.filter(who:getCardIds("h"), function(cid)
        return Exppattern:Parse(params.pattern):match(Fk:getCardById(cid))
      end)
      return #cards > 0 and { cards[1] } or {}
    end
    local origChoosePlayers = room.askToChoosePlayers
    room.askToChoosePlayers = function(self, who, params)
      return { params.targets[1] }
    end
    local useFrom
    local origUse = room.useCard
    room.useCard = function(self, params)
      useFrom = params.from
      origUse(self, params)
    end
    room.logic:trigger(fk.EventPhaseStart, me, {})
    room.askToChoice = origChoice
    room.askToCards = origCards
    room.askToChoosePlayers = origChoosePlayers
    room.useCard = origUse
    lu.assertNotNil(choiceText, "自己的回合结束阶段也应弹窗发动豫计")
    lu.assertEquals(useFrom.id, me.id, "自己回合结束使用时仍是“我”使用")
  end)
end)

return j_yuji2
