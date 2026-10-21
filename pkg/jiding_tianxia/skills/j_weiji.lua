local j_weiji = fk.CreateSkill {
  name = "j_weiji",
}

Fk:loadTranslationTable{
  ["j_weiji"] = "伪计",
  [":j_weiji"] = "出牌阶段，你可以弃置一张手牌，将你装备区里的任意一张牌当作【杀】使用。",

  ["#j_weiji"] = "伪计：弃置一张手牌，将装备区里的一张牌当作【杀】使用",

  ["$j_weiji1"] = "伪作病笃，以慢其心。",
  ["$j_weiji2"] = "示之以虚，击之以实。",
}

-- 转化技：先选手牌，再选装备区的牌，二者作为【杀】的子牌（手牌即被弃置）
j_weiji:addEffect("viewas", {
  anim_type = "offensive",
  pattern = "slash",
  prompt = "#j_weiji",
  card_filter = function(self, player, to_select, selected)
    if #selected == 0 then
      return table.contains(player:getCardIds("h"), to_select)
    elseif #selected == 1 then
      return table.contains(player:getCardIds("e"), to_select)
    end
    return false
  end,
  view_as = function(self, player, cards)
    if #cards ~= 2 then return end
    local card = Fk:cloneCard("slash")
    card.skillName = j_weiji.name
    card:addSubcards(cards)
    return card
  end,
  enabled_at_play = function(self, player)
    return player.phase == Player.Play and #player:getCardIds("h") > 0 and #player:getCardIds("e") > 0
  end,
})

return j_weiji
