local j_qun = fk.CreateSkill {
  name = "j_qun",
  tags = { Skill.Compulsory },
  derived_piles = "j_qun",
}

Fk:loadTranslationTable{
  ["j_qun"] = "囷",
  [":j_qun"] = "锁定技，一名角色的判定区内有【指仓相赠】并判定时，若判定结果与此【指仓相赠】花色相同或点数奇偶相同，判定者获得此判定牌并置于其武将牌上，称为“囷”，然后继续判定；否则其摸两张牌。“囷”可以视为手牌使用或打出，使用“囷”无次数限制。",
  ["@j_qun"] = "囷",
}

-- 同步“囷”计数标记（囷被使用/打出/移动后刷新武将牌上的标记）
local function syncQunMark(room, player)
  if not player or player.dead then return end
  room:setPlayerMark(player, "@j_qun", #player:getPile("j_qun"))
end

-- 判定结算：任意角色判定【指仓相赠】时，由拥有“囷”的计鲁肃处理
-- （触发者 player = 技能拥有者；判定者 target 即“此角色”）
j_qun:addEffect(fk.FinishJudge, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(j_qun.name) or player.dead then return false end
    if not target:isAlive() then return false end
    if data.reason ~= "j_zicangxiangzeng" then return false end
    return target:getMark("j_zicang_in_judge") ~= 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local zicang_card_id = target:getMark("j_zicang_in_judge")
    local zicang_card = Fk:getCardById(zicang_card_id)
    if not zicang_card then
      room:setPlayerMark(target, "j_zicang_in_judge", 0)
      return
    end

    -- 统一以实体牌操作（转化使用时判定区为虚拟牌，取其子牌）
    local real_id = zicang_card:isVirtual() and zicang_card.subcards[1] or zicang_card.id
    local real_card = real_id and Fk:getCardById(real_id)
    if not real_card then
      room:setPlayerMark(target, "j_zicang_in_judge", 0)
      return
    end

    local judge_card = data.card
    if not judge_card then
      room:setPlayerMark(target, "j_zicang_in_judge", 0)
      return
    end

    local match_suit = real_card.suit ~= Card.NoSuit and real_card.suit == judge_card.suit
    local match_parity = (real_card.number % 2) == (judge_card.number % 2)

    if match_suit or match_parity then
      -- 判定成功：判定者获得此判定牌，置于其武将牌上，称为“囷”，然后继续判定（标记保留）
      local judge_id = judge_card:getEffectiveId()
      local move = {
        ids = { judge_id },
        to = target,
        toArea = Card.PlayerSpecial,
        specialName = "j_qun",
        moveReason = fk.ReasonPut,
        skillName = j_qun.name,
      }
      room:moveCards(move)
      syncQunMark(room, target)
      -- 指仓相赠保留在判定流程中，由指仓相赠技能循环继续判定
    else
      -- 判定失败：判定者摸两张牌，指仓相赠进入弃牌堆，判定结束
      if target:isAlive() then
        target:drawCards(2, j_qun.name)
      end
      room:setPlayerMark(target, "j_zicang_in_judge", 0)
      local move = {
        ids = { real_id },
        toArea = Card.DiscardPile,
        moveReason = fk.ReasonPut,
        skillName = j_qun.name,
      }
      if zicang_card:isVirtual() then
        move.virtualEquip = zicang_card
      end
      room:moveCards(move)
    end
  end,
})

-- 同步“囷”标记（囷被使用/打出/移动后刷新武将牌上的计数）
j_qun:addEffect(fk.AfterCardsMove, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    for _, move in ipairs(data) do
      for _, info in ipairs(move.moveInfo) do
        if (info.fromArea == Card.PlayerSpecial and info.fromSpecialName == "j_qun") or
           (move.toArea == Card.PlayerSpecial and move.specialName == "j_qun") then
          return true
        end
      end
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for _, move in ipairs(data) do
      if move.toArea == Card.PlayerSpecial and move.specialName == "j_qun" and move.to then
        syncQunMark(room, move.to)
      end
      for _, info in ipairs(move.moveInfo) do
        if info.fromArea == Card.PlayerSpecial and info.fromSpecialName == "j_qun" and move.from then
          syncQunMark(room, move.from)
        end
      end
    end
  end,
})

-- “囷”视为手牌：武将牌上的囷可如手牌般使用或打出（全局生效）
j_qun:addEffect("filter", {
  global = true,
  handly_cards = function(self, player)
    return player:getPile("j_qun")
  end,
})

-- 测试：指仓相赠判定匹配 → 判定者获得判定牌置于武将牌（囷），保留判定区记录以便继续判定
j_qun:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_qun.name)
  end)

  FkTest.runInRoom(function()
    local zicang = room:printCard("j_zicangxiangzeng")
    zicang.suit = Card.Heart
    zicang.number = 5
    room:setCardMark(zicang, "j_zicang_source", me.id)
    room:moveCardTo(zicang.id, Card.PlayerJudge, comp2, fk.ReasonPut, "test")
    room:setPlayerMark(comp2, "j_zicang_in_judge", zicang.id)

    -- 模拟判定阶段：判定区牌移入处理区后再判定
    room:moveCardTo(zicang.id, Card.Processing, nil, fk.ReasonPut, "phase_judge")

    local judge_card = room:printCard("peach")
    judge_card.suit = Card.Heart
    judge_card.number = 5
    -- 用 moveCards 正确置顶（同步维护 card_place，避免脏 id 导致判定取不到牌）
    room:moveCards{ ids = { judge_card.id }, toArea = Card.DrawPile, moveReason = fk.ReasonJustMove, drawPilePosition = 1 }

    room:judge{ who = comp2, reason = "j_zicangxiangzeng", pattern = "." }
    lu.assertEquals(#comp2:getPile("j_qun"), 1, "匹配时判定牌应置于武将牌")
    lu.assertEquals(comp2:getPile("j_qun")[1], judge_card.id, "囷应为判定牌本身")
    lu.assertEquals(comp2:getMark("@j_qun"), 1, "判定者应有囷标记")
    lu.assertEquals(comp2:getMark("j_zicang_in_judge"), zicang.id, "匹配后应保留判定区记录以继续判定")
  end)
end)

-- 测试：指仓相赠判定不匹配 → 判定者摸两张牌，指仓相赠进入弃牌堆，判定区记录清除
j_qun:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_qun.name)
  end)

  FkTest.runInRoom(function()
    local zicang = room:printCard("j_zicangxiangzeng")
    zicang.suit = Card.Heart
    zicang.number = 5
    room:setCardMark(zicang, "j_zicang_source", me.id)
    room:moveCardTo(zicang.id, Card.PlayerJudge, comp2, fk.ReasonPut, "test")
    room:setPlayerMark(comp2, "j_zicang_in_judge", zicang.id)
    room:moveCardTo(zicang.id, Card.Processing, nil, fk.ReasonPut, "phase_judge")

    local judge_card = room:printCard("slash")
    judge_card.suit = Card.Spade
    judge_card.number = 4
    room:moveCards{ ids = { judge_card.id }, toArea = Card.DrawPile, moveReason = fk.ReasonJustMove, drawPilePosition = 1 }

    local hand_before = #comp2:getCardIds("h")
    room:judge{ who = comp2, reason = "j_zicangxiangzeng", pattern = "." }
    lu.assertEquals(#comp2:getCardIds("h"), hand_before + 2, "失败时判定者应摸两张牌")
    lu.assertEquals(comp2:getMark("j_zicang_in_judge"), 0, "失败时判定区记录应清除")
    lu.assertEquals(comp2:getMark("@j_qun"), 0, "失败时不应有囷标记")
    lu.assertEquals(room:getCardArea(zicang.id), Card.DiscardPile, "失败时指仓相赠应进入弃牌堆")
  end)
end)

-- 测试：计鲁肃失去“囷”（死亡/失去技能）后，判定指仓相赠不再处理
j_qun:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_qun.name)
  end)

  FkTest.runInRoom(function()
    local zicang = room:printCard("j_zicangxiangzeng")
    zicang.suit = Card.Heart
    zicang.number = 5
    room:setCardMark(zicang, "j_zicang_source", me.id)
    room:moveCardTo(zicang.id, Card.PlayerJudge, comp2, fk.ReasonPut, "test")
    room:setPlayerMark(comp2, "j_zicang_in_judge", zicang.id)
    room:moveCardTo(zicang.id, Card.Processing, nil, fk.ReasonPut, "phase_judge")

    local judge_card = room:printCard("peach")
    judge_card.suit = Card.Heart
    judge_card.number = 5
    room:moveCards{ ids = { judge_card.id }, toArea = Card.DrawPile, moveReason = fk.ReasonJustMove, drawPilePosition = 1 }

    -- 鲁肃失去技能后判定：囷不应再处理（底层 loseSkill，绕过扩展包对 handleAddLoseSkills 的覆盖）
    me:loseSkill(j_qun.name)
    room:judge{ who = comp2, reason = "j_zicangxiangzeng", pattern = "." }
    lu.assertEquals(#comp2:getPile("j_qun"), 0, "失去囷技能后判定不应产生囷")
  end)
end)

return j_qun
