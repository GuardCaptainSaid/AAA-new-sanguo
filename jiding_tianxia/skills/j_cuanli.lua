local j_cuanli = fk.CreateSkill {
  name = "j_cuanli",
  tags = { Skill.Awaken },
}

Fk:loadTranslationTable{
  ["j_cuanli"] = "篡立",
  [":j_cuanli"] = "觉醒技，结束阶段，若你本轮未因【昭心】获得过牌，你增加一点体力上限，并选择获得以下技能之一：【伉厉】、【潜龙】、【权谋】、【震扰】。",

  ["#j_cuanli-choice"] = "篡立：选择获得一个技能",

  ["$j_cuanli1"] = "受诏辅政，终履至尊。",
  ["$j_cuanli2"] = "司马昭之心，已路人皆知。",
}

local J_CUANLI_SKILLS = { "kangli", "dl__qianlong", "dl__quanmou", "dl__zhenrao" }

-- 结束阶段：本轮未因昭心获得过牌 → 觉醒
j_cuanli:addEffect(fk.EventPhaseEnd, {
  anim_type = "wake",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or player.phase ~= Player.Finish then return false end
    if not player:hasSkill(j_cuanli.name) then return false end
    return player:getMark("j_zhaoxin_gain-round") == 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = j_cuanli.name })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:changeMaxHp(player, 1)
    local choice = room:askToChoice(player, {
      choices = table.simpleClone(J_CUANLI_SKILLS),
      skill_name = j_cuanli.name,
      prompt = "#j_cuanli-choice",
    })
    room:handleAddLoseSkills(player, choice, nil, false, true)
  end,
})

return j_cuanli
