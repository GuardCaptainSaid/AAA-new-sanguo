local j_duying = fk.CreateSkill {
  name = "j_duying",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_duying"] = "妒英",
  [":j_duying"] = "锁定技，你的红桃牌视为黑桃牌。",
}

-- 花色视为：同 delight 红颜（dl__hongyan）写法
j_duying:addEffect("filter", {
  mute = true,
  card_filter = function(self, to_select, player, is_judge)
    return to_select.suit == Card.Heart and player:hasSkill(j_duying.name) and
      (table.contains(player:getCardIds("he"), to_select.id) or is_judge)
  end,
  view_as = function(self, player, to_select)
    return Fk:cloneCard(to_select.name, Card.Spade, to_select.number)
  end,
})

return j_duying
