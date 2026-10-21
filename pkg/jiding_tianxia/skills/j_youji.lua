local j_youji = fk.CreateSkill {
  name = "j_youji",
}

Fk:loadTranslationTable{
  ["j_youji"] = "诱机",
  [":j_youji"] = "出牌阶段限一次，你可令一名其他角色摸至多X张牌，令你本回合对其使用的下X张牌其不能响应并不计入次数限制。回合结束时，若其本回合进入过濒死状态，你获得本回合进入弃牌堆的牌。（X为其体力上限）",

  ["#j_youji-target"] = "诱机：选择一名其他角色",
  ["#j_youji-number"] = "诱机：选择令其摸牌的数量（至多 %arg 张）",

  ["$j_youji1"] = "以饵诱之，待其乱而动。",
  ["$j_youji2"] = "机已设下，只待君入。",
}

-- 出牌阶段限一次：令一名其他角色摸至多X张牌，并标记本回合对其的下X张牌不可响应、不计入次数
j_youji:addEffect("active", {
  anim_type = "control",
  prompt = "#j_youji-target",
  card_num = 0,
  target_num = 1,
  can_use = function(self, player)
    return player:usedSkillTimes(j_youji.name, Player.HistoryPhase) == 0
  end,
  card_filter = Util.FalseFunc,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player
  end,
  times = function(self, player)
    return 1 - player:usedSkillTimes(j_youji.name, Player.HistoryPhase)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos[1]
    if not target or target.dead then return end
    local x = target.maxHp
    if x <= 0 then return end
    local num = room:askToNumber(player, {
      min = 1,
      max = x,
      cancelable = true,
      skill_name = j_youji.name,
      prompt = "#j_youji-number:::" .. x,
    })
    if not num then return end
    room:drawCards(target, num, j_youji.name)
    room:setPlayerMark(target, "j_youji_caster-turn", player.id)
    room:setPlayerMark(target, "j_youji_times-turn", x)
  end,
})

-- 本回合对其使用的下X张牌：不可响应 + 不计入次数限制
j_youji:addEffect(fk.PreCardUse, {
  global = true,
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(j_youji.name) or player.dead then return false end
    if data.from ~= player or not data.tos then return false end
    for _, to in ipairs(data.tos) do
      if to:getMark("j_youji_caster-turn") == player.id and to:getMark("j_youji_times-turn") > 0 then
        return true
      end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    data.disresponsiveList = data.disresponsiveList or {}
    for _, to in ipairs(data.tos) do
      if to:getMark("j_youji_caster-turn") == player.id and to:getMark("j_youji_times-turn") > 0 then
        table.insertIfNeed(data.disresponsiveList, to)
        room:setPlayerMark(to, "j_youji_times-turn", to:getMark("j_youji_times-turn") - 1)
      end
    end
    data.extraUse = true
  end,
})

-- 记录其本回合是否进入过濒死状态
j_youji:addEffect(fk.EnterDying, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_youji.name) or player.dead then return false end
    return target:getMark("j_youji_caster-turn") == player.id
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(target, "j_youji_dying-turn", 1)
  end,
})

-- 记录本回合进入弃牌堆的牌（-turn 标记，回合结束自动清空）
j_youji:addEffect(fk.AfterCardsMove, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_youji.name) or player.dead then return false end
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile and #move.moveInfo > 0 then
        return true
      end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local ids = player:getTableMark("j_youji_discard-turn")
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile then
        for _, info in ipairs(move.moveInfo) do
          table.insertIfNeed(ids, info.cardId)
        end
      end
    end
    room:setPlayerMark(player, "j_youji_discard-turn", ids)
  end,
})

-- 回合结束时：若其本回合进入过濒死状态，你获得本回合进入弃牌堆的牌
j_youji:addEffect(fk.TurnEnd, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(j_youji.name) and not player.dead
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 找到本回合被诱机的角色
    local marked
    for _, p in ipairs(room:getAlivePlayers()) do
      if p:getMark("j_youji_caster-turn") == player.id and p ~= player then
        marked = p
        break
      end
    end
    if not marked or marked:getMark("j_youji_dying-turn") ~= 1 then return end
    -- 仍留在弃牌堆中的牌
    local valid = table.filter(player:getTableMark("j_youji_discard-turn"), function(cid)
      return table.contains(room.discard_pile, cid)
    end)
    if #valid > 0 then
      room:obtainCard(player, valid, true, fk.ReasonDraw, player, j_youji.name)
    end
  end,
})

return j_youji
