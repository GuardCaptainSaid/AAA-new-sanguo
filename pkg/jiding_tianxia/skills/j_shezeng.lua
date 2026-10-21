local j_shezeng = fk.CreateSkill {
  name = "j_shezeng",
  tags = { Skill.Locked },
}

Fk:loadTranslationTable{
  ["j_shezeng"] = "奢赠",
  [":j_shezeng"] = "锁定技，游戏开始时，你将四张【指仓相赠】加入牌堆。",
}

j_shezeng:addEffect(fk.GameStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(j_shezeng.name)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for i = 1, 4 do
      local card = Fk:cloneCard("j_zicangxiangzeng")
      table.insert(room.draw_pile, card.id)
      room:setCardArea(card.id, Card.DrawPile)
    end
    table.shuffle(room.draw_pile)
  end,
})

return j_shezeng