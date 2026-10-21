local j_ejin = fk.CreateSkill {
  name = "j_ejin",
}

Fk:loadTranslationTable{
  ["j_ejin"] = "扼津",
  [":j_ejin"] = "出牌阶段限一次，你可以弃置任意张手牌，选择一名角色：本回合其不能使用、打出与弃置牌花色相同的牌，然后你可以将牌堆底等量张牌置于武将牌上，称为「垒」。若你弃置牌不少于2张，该角色本回合无法回复体力。",

  ["#j_ejin-target"] = "扼津：选择一名角色",
  ["#j_ejin-discard"] = "扼津：弃置任意张手牌",

  ["$j_ejin1"] = "扼其要津，断其粮道。",
  ["$j_ejin2"] = "险地据守，以寡扼众。",
}

-- 取牌的实用花色（优先取子牌花色，与转化牌表现一致）
local function effectiveSuit(card)
  if card.subcards and #card.subcards > 0 then
    return Fk:getCardById(card.subcards[1]):getSuitString()
  end
  return card:getSuitString()
end

-- 出牌阶段限一次：弃置任意张手牌，选择一名角色，禁其本回合使用/打出同花色牌，并将牌堆底等量张牌置于武将牌上称为「垒」
j_ejin:addEffect("active", {
  anim_type = "control",
  prompt = "#j_ejin-target",
  card_num = 0,
  target_num = 1,
  can_use = function(self, player)
    return player.phase == Player.Play and
      player:usedSkillTimes(j_ejin.name, Player.HistoryPhase) == 0
  end,
  card_filter = Util.FalseFunc,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0
  end,
  times = function(self, player)
    return 1 - player:usedSkillTimes(j_ejin.name, Player.HistoryPhase)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos[1]
    if not target then return end
    if #player:getCardIds("h") == 0 then return end

    -- 弃置任意张手牌
    local cards = room:askToDiscard(player, {
      min_num = 1,
      max_num = #player:getCardIds("h"),
      include_equip = false,
      pattern = ".|.|.|hand",
      skill_name = j_ejin.name,
      prompt = "#j_ejin-discard",
      cancelable = false,
      skip = true,
    })
    if #cards == 0 then return end
    room:throwCard(cards, j_ejin.name, player, player)
    if player.dead then return end

    -- 记录禁用花色（去重）
    local suits = {}
    for _, cid in ipairs(cards) do
      local s = Fk:getCardById(cid):getSuitString()
      if s ~= "nosuit" and s ~= "unknown" and not table.contains(suits, s) then
        table.insert(suits, s)
      end
    end
    if #suits > 0 then
      room:setPlayerMark(target, "j_ejin_caster-turn", player.id)
      room:setPlayerMark(target, "j_ejin_suits-turn", suits)
    end
    -- 弃置不少于2张：本回合无法回复体力
    if #cards >= 2 then
      room:setPlayerMark(target, "j_ejin_norecover-turn", 1)
    end

    -- 将牌堆底等量张牌置于武将牌上，称为「垒」（注意：table.slice 的 end 是开区间，须 +1 取足数量）
    if #room.draw_pile >= #cards then
      local bottom = table.slice(room.draw_pile, #room.draw_pile - #cards + 1, #room.draw_pile + 1)
      room:moveCards{
        ids = bottom,
        to = player,
        toArea = Card.PlayerSpecial,
        specialName = "j_gulei",
        moveReason = fk.ReasonPut,
        skillName = j_ejin.name,
      }
    end
  end,
})

-- 本回合不能使用同花色牌
j_ejin:addEffect(fk.PreCardUse, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_ejin.name) or player.dead then return false end
    if target == nil or target.dead then return false end
    if target:getMark("j_ejin_caster-turn") ~= player.id then return false end
    if not data.card then return false end
    local suits = target:getTableMark("j_ejin_suits-turn")
    local suit = effectiveSuit(data.card)
    return table.contains(suits, suit)
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    -- 返回 true 使引擎中断本次使用
    return true
  end,
})

-- 本回合不能打出同花色牌
j_ejin:addEffect(fk.PreCardRespond, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_ejin.name) or player.dead then return false end
    if target == nil or target.dead then return false end
    if target:getMark("j_ejin_caster-turn") ~= player.id then return false end
    if not data.card then return false end
    local suits = target:getTableMark("j_ejin_suits-turn")
    local suit = effectiveSuit(data.card)
    return table.contains(suits, suit)
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    -- 返回 true 使引擎中断本次打出
    return true
  end,
})

-- 弃置不少于2张时：本回合无法回复体力
j_ejin:addEffect(fk.PreHpRecover, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_ejin.name) or player.dead then return false end
    if target == nil or target.dead then return false end
    return target:getMark("j_ejin_norecover-turn") == 1 and target:getMark("j_ejin_caster-turn") == player.id
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    data.num = 0
  end,
})

-- 测试：弃 N 张手牌应置入等量 N 张「垒」（回归：table.slice 开区间少取一张）
j_ejin:addTest(function(room, me)
  local c1, c2, c3
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_ejin.name)
    c1 = room:printCard("slash", Card.Spade, 1)
    c2 = room:printCard("slash", Card.Spade, 2)
    c3 = room:printCard("peach", Card.Heart, 3)
    room:obtainCard(me, { c1, c2, c3 }, true, fk.ReasonDraw, me, "test")
    me.phase = Player.Play
  end)

  FkTest.runInRoom(function()
    local origDiscard = room.askToDiscard
    room.askToDiscard = function(self, who, params)
      return { c1.id, c2.id, c3.id }
    end
    local sk = Fk.skills[j_ejin.name]
    room:useSkill(me, sk, function()
      sk:onUse(room, { from = me, tos = { room.players[2] }, cards = {} })
    end, {})
    room.askToDiscard = origDiscard
    lu.assertEquals(#me:getPile("j_gulei"), 3, "弃 3 张手牌应置入 3 张「垒」")
  end)
end)

return j_ejin
