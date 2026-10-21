local j_zhaoxin = fk.CreateSkill {
  name = "j_zhaoxin",
}

Fk:loadTranslationTable{
  ["j_zhaoxin"] = "昭心",
  [":j_zhaoxin"] = "每轮开始时，你可以依次指定两种卡牌花色；每当连续两张被使用的牌的花色与你指定的顺序相同时，你可以从牌堆获得两张你选择的不同点数的牌。",

  ["#j_zhaoxin-invoke"] = "昭心：是否指定两种花色？",
  ["#j_zhaoxin-suit1"] = "昭心：请选择第一个花色",
  ["#j_zhaoxin-suit2"] = "昭心：请选择第二个花色（需与第一个不同）",
  ["#j_zhaoxin-num1"] = "昭心：选择要获得的第一张牌的点数",
  ["#j_zhaoxin-num2"] = "昭心：选择要获得的第二张牌的点数（需与第一张不同）",
  ["#j_zhaoxin-gain"] = "昭心：是否从牌堆获得两张指定点数的牌？",

  ["spade"] = "黑桃",
  ["heart"] = "红桃",
  ["club"] = "梅花",
  ["diamond"] = "方块",

  ["$j_zhaoxin1"] = "司马氏之心，路人皆知。",
  ["$j_zhaoxin2"] = "三马同槽，岂偶然哉。",
}

local ALL_SUITS = { "spade", "heart", "club", "diamond" }

-- 牌堆中存在的不同点数（升序）
local function draw_pile_numbers(room)
  local nums = {}
  for _, id in ipairs(room.draw_pile) do
    local n = Fk:getCardById(id):getNumber()
    if not table.contains(nums, n) then
      table.insert(nums, n)
    end
  end
  table.sort(nums)
  return nums
end

-- 按指定两个点数各取一张（牌堆中）
local function pick_by_numbers(room, n1, n2)
  local ids = {}
  local taken = {}
  for _, id in ipairs(room.draw_pile) do
    local c = Fk:getCardById(id)
    local n = c:getNumber()
    if (n == n1 or n == n2) and not taken[n] then
      table.insert(ids, id)
      taken[n] = true
    end
    if #ids >= 2 then break end
  end
  return ids
end

-- 每轮开始：依次指定两种花色
j_zhaoxin:addEffect(fk.RoundStart, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(j_zhaoxin.name)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_zhaoxin.name, prompt = "#j_zhaoxin-invoke" })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local s1 = room:askToChoice(player, {
      choices = ALL_SUITS,
      skill_name = j_zhaoxin.name,
      prompt = "#j_zhaoxin-suit1",
    })
    local rest = {}
    for _, s in ipairs(ALL_SUITS) do
      if s ~= s1 then table.insert(rest, s) end
    end
    local s2 = room:askToChoice(player, {
      choices = rest,
      skill_name = j_zhaoxin.name,
      prompt = "#j_zhaoxin-suit2",
    })
    room:setPlayerMark(player, "j_zhaoxin_suits-round", { s1, s2 })
    room:setPlayerMark(player, "j_zhaoxin_prev-round", 0)
  end,
})

-- 连续两张使用牌的花色与指定顺序相同 → 获得两张指定点数的牌
j_zhaoxin:addEffect(fk.CardUsing, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(j_zhaoxin.name) and type(player:getMark("j_zhaoxin_suits-round")) == "table"
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cur = data.card:getSuitString()
    local prev = player:getMark("j_zhaoxin_prev-round")
    local suits = player:getMark("j_zhaoxin_suits-round")
    if prev and prev ~= 0 and prev ~= "" and prev == suits[1] and cur == suits[2] then
      if room:askToSkillInvoke(player, { skill_name = j_zhaoxin.name, prompt = "#j_zhaoxin-gain" }) then
        local nums = draw_pile_numbers(room)
        if #nums >= 2 then
          local choices1 = {}
          for _, n in ipairs(nums) do table.insert(choices1, tostring(n)) end
          local n1 = tonumber(room:askToChoice(player, {
            choices = choices1,
            skill_name = j_zhaoxin.name,
            prompt = "#j_zhaoxin-num1",
          }))
          local rest = {}
          for _, n in ipairs(nums) do
            if n ~= n1 then table.insert(rest, n) end
          end
          local choices2 = {}
          for _, n in ipairs(rest) do table.insert(choices2, tostring(n)) end
          local n2 = tonumber(room:askToChoice(player, {
            choices = choices2,
            skill_name = j_zhaoxin.name,
            prompt = "#j_zhaoxin-num2",
          }))
          local ids = pick_by_numbers(room, n1, n2)
          if #ids > 0 then
            room:obtainCard(player, ids, true, fk.ReasonPrey, player, "j_zhaoxin")
            room:setPlayerMark(player, "j_zhaoxin_gain-round", 1)
            room:setPlayerMark(player, "j_zhaoxin_justgained-round", 1)
            local got = player:getMark("j_zhaoxin_gotids-round")
            if type(got) ~= "table" then got = {} end
            for _, id in ipairs(ids) do table.insert(got, id) end
            room:setPlayerMark(player, "j_zhaoxin_gotids-round", got)
          end
        end
      end
    end
    room:setPlayerMark(player, "j_zhaoxin_prev-round", cur)
  end,
})

-- 测试：轮开始时指定花色；当连续两张使用牌花色匹配时可获得牌堆牌
j_zhaoxin:addTest(function(room, me)
  local comp2 = room.players[2]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, j_zhaoxin.name)
    room:setPlayerMark(me, "j_zhaoxin_suits-round", { "spade", "heart" })
    room:setPlayerMark(me, "j_zhaoxin_prev-round", "spade")
    -- 额外塞入一张红桃5到牌堆顶，便于获得
    local c = room:printCard("slash", Card.Heart, 5)
    table.insert(room.draw_pile, 1, c.id)
  end)

  FkTest.runInRoom(function()
    local origInvoke = room.askToSkillInvoke
    room.askToSkillInvoke = function(self, who, params)
      return true
    end
    local origChoice = room.askToChoice
    room.askToChoice = function(self, who, params)
      if params.prompt == "#j_zhaoxin-num1" then return "5" end
      if params.prompt == "#j_zhaoxin-num2" then return "6" end
      return "spade"
    end
    local before = #me:getCardIds("h")
    -- 模拟使用一张红桃牌（spade 在前，heart 在后 → 匹配）
    local card = room:printCard("slash", Card.Heart, 7)
    room.logic:trigger(fk.CardUsing, me, { card = card })
    room.askToSkillInvoke = origInvoke
    room.askToChoice = origChoice
    lu.assertEquals(me:getMark("j_zhaoxin_gain-round"), 1, "连续两张花色匹配应标记获得")
    lu.assertTrue(#me:getCardIds("h") >= before, "获得后手牌不应减少")
  end)
end)

return j_zhaoxin
