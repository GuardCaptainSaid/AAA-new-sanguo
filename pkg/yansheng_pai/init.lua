-- SPDX-License-Identifier: GPL-3.0-or-later
-- 新三国衍生牌扩充包：【指仓相赠】延时锦囊定义 + 四张实体
-- 说明：【指仓相赠】是计鲁肃的专属衍生牌（"&" 前缀 = 衍生牌）：
--        - 衍生牌不进入初始牌堆（GameMode:buildDrawPile 自动排除 is_derived），
--          因此计鲁肃不在场时牌堆中绝不会有【指仓相赠】；
--        - 计鲁肃（拥有【奢赠】）入场时，由【奢赠】在游戏开始时将四张补入牌堆；
--        - 卡牌一览（Ltk.getCards）按包取牌、不过滤衍生牌，四张实体（方块A、梅花6、黑桃Q、红桃K）仍可见。

local extension = Package:new("yansheng_pai", Package.CardPack)

extension.extensionName = "AAA-new-sanguo"

-- 卡牌定义（供卡牌一览/翻译/技能引用）；"&" 前缀标记为衍生牌：不进初始牌堆
local j_zicangxiangzeng = fk.CreateCard {
  name = "&j_zicangxiangzeng",
  type = Card.TypeTrick,
  sub_type = Card.SubtypeDelayedTrick,
  skill = "j_zicangxiangzeng_skill",
}
extension:loadCardSkels { j_zicangxiangzeng }

-- 四张【指仓相赠】实体（卡牌一览可见；衍生牌不进初始牌堆，仅由奢赠在鲁肃入场时补入牌堆）
extension:addCardSpec("j_zicangxiangzeng", Card.Diamond, 1)
extension:addCardSpec("j_zicangxiangzeng", Card.Club, 6)
extension:addCardSpec("j_zicangxiangzeng", Card.Spade, 12)
extension:addCardSpec("j_zicangxiangzeng", Card.Heart, 13)

Fk:loadTranslationTable{
  ["yansheng_pai"] = "新三国衍生牌",

  ["j_zicangxiangzeng"] = "指仓相赠",
  [":j_zicangxiangzeng"] = "出牌阶段，对一名角色使用，将其置于其判定区。判定阶段，若判定结果与此牌花色相同或点数奇偶相同，判定者获得此判定牌并置于其武将牌上（可以当手牌使用），然后继续判定；否则判定者摸两张牌。",
}

return extension
