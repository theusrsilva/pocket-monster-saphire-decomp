-- Descrições de golpes (script $46) e de itens (scripts $47 em diante) em português, para a ROM convertida.
-- Quase todas seguem um modelo com números ("Power up60, Attack scope1-2"); os números saem do
-- próprio texto da ROM do jogador, então aqui só ficam os modelos. As descrições únicas (itens-chave
-- e insígnias) são traduzidas à mão.
local Buffer = require("src.romhack.buffer")

local Descriptions = {}

local MODELS = {
  { "^Reply troops one Yuan vitality%s*(%d+)points", "Cura %s de HP de um aliado." },
  { "^Reply self vitality%s*(%d+)points", "Recupera %s do próprio HP." },
  { "^Power up(%d+),%s*Attack scope(%d+%-%d+)", "Poder %s, alcance %s." },
  { "^Power up(%d+),%s*Attack scope(%d+)", "Poder %s, alcance %s." },
  { "^Reply our one%s*(%d+)Vitality", "Recupera %s de HP." },
  { "^Reply our one%s*(%d+)Quick power", "Recupera %s de SP." },
  { "^VitalityLimit promotion%s*(%d+)points", "HP máximo +%s." },
  { "^Quick powerLimit promotion%s*(%d+)points", "SP máximo +%s." },
  { "^attack powerLimit promotion%s*(%d+)points", "ATK +%s." },
  { "^Hit the target powerLimit promotion%s*(%d+)points", "PRE +%s." },
  { "^SpeedLimit promotion%s*(%d+)points", "ESQ +%s." },
  { "^Move powerLimit promotion%s*(%d+)points", "MOV +%s (máximo 15)." },
}

local FIXED = {
  ["One  possess the stone of supernatural dense strength."] = "Uma pedra com uma força sobrenatural.",
  ["Can enter the clear barrier goods of RainbowCity."] = "Abre a barreira que protege a Cidade Arco-Íris.",
  ["Can awaken allegedly the monster that is fast asleeep."] = "Dizem que acorda o Pokémon que dorme pesado.",
  ["Is the scale with fiery monster."] = "Escama de um Pokémon de fogo.",
  ["One defend the tooth that takes off to fall."] = "Um dente que caiu de um dragão.",
  ["Possess the pretty feather of 7 color pools."] = "Uma linda pena de sete cores.",
  ["Quick department evolve stone."] = "Insígnia que evolui o tipo Agilidade.",
  ["Balanced department evolve stone."] = "Insígnia que evolui o tipo Equilíbrio.",
  ["Strength department evolve stone."] = "Insígnia que evolui o tipo Força.",
  ["Exceed badge evolve stone."] = "Insígnia que evolui o tipo Superpoder.",
  ["Defence department evolve stone."] = "Insígnia que evolui o tipo Defesa.",
}

-- Tradução de um texto original (nil = sem modelo).
function Descriptions.translate(text)
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  if FIXED[text] then return FIXED[text] end
  for _, m in ipairs(MODELS) do
    local a, b = text:match(m[1])
    if a then return m[2]:format(a, b) end
  end
end

-- Acrescenta em PT (chave "BB:AAAA" -> { página }) as descrições dos scripts $46 e $47.
function Descriptions.add(rom, PT, entries)
  local out = setmetatable({}, { __index = PT })
  local n = 0
  for _, e in ipairs(entries) do
    if e.script >= 0x46 then                  -- $46 golpes, $47-$4A itens
      local key = ("%02X:%04X"):format(e.bank, e.addr)
      if not PT[key] then
        local o, t = Buffer.at(e.bank, e.addr), {}
        for i = 0, 200 do
          local c = rom:u8(o + i)
          if c == 0xFF then break end
          if c == 0xE8 then t = {} elseif c >= 32 and c < 127 then t[#t + 1] = string.char(c) end
        end
        local pt = Descriptions.translate(table.concat(t))
        if pt and not rawget(out, key) then out[key] = { pt }; n = n + 1 end
      end
    end
  end
  return out, n
end

return Descriptions
