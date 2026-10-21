local j_shezeng = fk.CreateSkill {
  name = "j_shezeng",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["j_shezeng"] = "奢赠",
  [":j_shezeng"] = "锁定技，游戏开始时，若牌堆中不足四张【指仓相赠】，你将其补齐至四张（花色点数固定为方块A、梅花6、黑桃Q、红桃K）。",
}

-- 固定四张：方块A、梅花6、黑桃Q、红桃K
local fixed_specs = {
  { Card.Diamond, 1 }, -- 方块A
  { Card.Club, 6 },    -- 梅花6
  { Card.Spade, 12 },  -- 黑桃Q
  { Card.Heart, 13 },  -- 红桃K
}

-- 指仓相赠是衍生牌（& 前缀），默认不进初始牌堆；
-- 计鲁肃（拥有【奢赠】）入场时，游戏开始（GameStart）将其补齐至四张。
j_shezeng:addEffect(fk.GameStart, {
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(j_shezeng.name, true)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local existing = 0
    for _, id in ipairs(room.draw_pile) do
      local c = Fk:getCardById(id)
      if c and c.name == "j_zicangxiangzeng" then
        existing = existing + 1
      end
    end
    local to_add = math.max(0, 4 - existing)
    if to_add <= 0 then return end
    for i = 1, to_add do
      local spec = fixed_specs[i]
      -- cloneCard 的牌 id=0（虚拟牌）不能直接入堆；用 printCard 分配真实 id（置于 void），再移入牌堆
      local card = room:printCard("j_zicangxiangzeng", spec[1], spec[2])
      table.removeOne(room.void, card.id)
      table.insert(room.draw_pile, card.id)
      room:setCardArea(card.id, Card.DrawPile)
    end
    table.shuffle(room.draw_pile)
  end,
})

-- 测试1：鲁肃（奢赠）入场时，游戏开始后牌堆补入四张【指仓相赠】
-- 预处理：衍生牌不进初始牌堆，触发 GameStart 前牌堆应为 0 张
j_shezeng:addTest(function(room, me)
  FkTest.runInRoom(function()
    -- 重置牌堆为真实构建结果（buildDrawPile 过滤衍生牌）
    room:prepareDrawPile()
    room:handleAddLoseSkills(me, j_shezeng.name)
    lu.assertTrue(me:hasSkill(j_shezeng.name, true), "me 应拥有奢赠技能")
  end)

  FkTest.runInRoom(function()
    room.logic:trigger(fk.GameStart, me, {})
    local count = 0
    for _, id in ipairs(room.draw_pile) do
      if Fk:getCardById(id).name == "j_zicangxiangzeng" then
        count = count + 1
      end
    end
    lu.assertEquals(count, 4, "鲁肃入场后牌堆应有4张指仓相赠")
  end)
end)

-- 测试2：牌堆已含四张指仓相赠时，触发奢赠不再重复加入
j_shezeng:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:prepareDrawPile()
    room:handleAddLoseSkills(me, j_shezeng.name)
  end)

  FkTest.runInRoom(function()
    room.logic:trigger(fk.GameStart, me, {})
    local count = 0
    for _, id in ipairs(room.draw_pile) do
      if Fk:getCardById(id).name == "j_zicangxiangzeng" then
        count = count + 1
      end
    end
    lu.assertEquals(count, 4, "首次触发后牌堆应有4张指仓相赠")
    local before = #room.draw_pile
    room.logic:trigger(fk.GameStart, me, {})
    lu.assertEquals(#room.draw_pile, before, "已有四张指仓相赠时不应重复加入")
  end)
end)

-- 测试3：无鲁肃（无奢赠）时，即使触发 GameStart，牌堆也不应有指仓相赠（衍生牌从源头不进牌堆）
j_shezeng:addTest(function(room, me)
  FkTest.runInRoom(function()
    room:prepareDrawPile()
  end)

  FkTest.runInRoom(function()
    room.logic:trigger(fk.GameStart, me, {})
    local count = 0
    for _, id in ipairs(room.draw_pile) do
      if Fk:getCardById(id).name == "j_zicangxiangzeng" then
        count = count + 1
      end
    end
    lu.assertEquals(count, 0, "无鲁肃入场时牌堆不应有指仓相赠")
  end)
end)

-- 测试4：真实构建链路——buildDrawPile 不产出指仓相赠（衍生牌），void 中亦不含（不随初始牌堆进入游戏）
j_shezeng:addTest(function(room, me)
  FkTest.runInRoom(function()
    local pile, void = Fk.game_modes["testmode"]:buildDrawPile()
    local countPile = 0
    for _, id in ipairs(pile) do
      if Fk:getCardById(id).name == "j_zicangxiangzeng" then
        countPile = countPile + 1
      end
    end
    lu.assertEquals(countPile, 0, "初始牌堆构建不应包含衍生牌指仓相赠")
    -- 卡牌一览数据源（pack.cards）仍保留四张实体
    local pack = Fk.packages["yansheng_pai"]
    local countCards = 0
    for _, c in ipairs(pack.cards) do
      if c.name == "j_zicangxiangzeng" then
        countCards = countCards + 1
      end
    end
    lu.assertEquals(countCards, 4, "衍生牌包应保留四张指仓相赠实体（卡牌一览可见）")
  end)
end)

return j_shezeng
