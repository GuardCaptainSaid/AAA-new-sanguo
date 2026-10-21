local extension = Package:new("qunxing_cuican")

extension.extensionName = "AAA new sanguo"

extension:loadSkillSkelsByPath("./packages/AAA new sanguo/pkg/qunxing_cuican/skills")

Fk:loadTranslationTable{
  ["qunxing_cuican"] = "群星璀璨",
}

General:new(extension, "songxian_weixu", "qun", 4):addSkills {
  "j_daoge", "j_qishe", "j_yuji", "j_xianji", "j_kuiwei", "j_motu",
}
Fk:loadTranslationTable{
  ["songxian_weixu"] = "宋宪 & 魏续",
  ["#songxian_weixu"] = "叛戟双枭",
  ["designer:songxian_weixu"] = "袁焉",
  ["illustrator:songxian_weixu"] = "豆包AI",
  ["cv:songxian_weixu"] = "佚名",

  ["~songxian_weixu"] = "白门楼下，戟折人亡……",
}

local sp_caocao = General:new(extension, "sp_caocao", "wei", 3, 3)
sp_caocao:addSkills { "j_jiedao", "j_xiandao" }
sp_caocao:addRelatedSkills { "j_yifeng", "j_qiangxi" }
Fk:loadTranslationTable{
  ["sp_caocao"] = "SP曹操",
  ["#sp_caocao"] = "借刀刺董",
  ["designer:sp_caocao"] = "袁焉",
  ["illustrator:sp_caocao"] = "豆包AI",
  ["cv:sp_caocao"] = "佚名",

  ["~sp_caocao"] = "孟德愿献宝刀……为天下除此国贼……",
}

return extension
