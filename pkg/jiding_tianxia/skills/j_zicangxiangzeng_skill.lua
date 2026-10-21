local j_zicangxiangzeng_skill = fk.CreateSkill {
  name = "j_zicangxiangzeng_skill",
}

Fk:loadTranslationTable{
  ["#j_zicangxiangzeng_skill"] = "指仓相赠",
}

j_zicangxiangzeng_skill:addEffect("cardskill", {
  prompt = "#j_zicangxiangzeng_skill",
  mod_target_filter = Util.TrueFunc,
  can_use = function(self, player)
    return player.phase == Player.Play
  end,
  target_filter = function(self, target, player)
    return target ~= player
  end,
  on_effect = function(self, room, effect)
    local from = effect.from
    local to = effect.to

    local card = Fk:getCardById(effect.card.id)
    room:setCardMark(card, "j_zicang_target", to.id)
    room:setCardMark(card, "j_zicang_source", from.id)
    room:setPlayerMark(to, "j_zicang_in_judge", effect.card.id)

    -- 延时锦囊的判定由自身技能执行：进行判定，由“囷”技能在 FinishJudge 时处理结果
    local judge = {
      who = to,
      reason = "j_zicangxiangzeng",
      pattern = ".",
    }
    room:judge(judge)

    -- 若判定被终止（如被改判技能打断）或无“囷”接管，将牌置入弃牌堆并清除标记
    if not judge.results then
      room:moveCardTo(effect.card.id, Card.DiscardPile, nil, fk.ReasonPut, "j_zicangxiangzeng")
      room:setPlayerMark(to, "j_zicang_in_judge", 0)
    end
  end,
})

return j_zicangxiangzeng_skill