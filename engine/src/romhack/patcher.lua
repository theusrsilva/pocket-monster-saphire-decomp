-- Conversor de ROM: gera, a partir da ROM do jogador, uma ROM de GBC com as melhorias que dá para
-- levar para o cartucho (falas em português, nomes em imagem redesenhados, correção da autocura).
-- Nada da ROM fica no repositório: tudo é calculado na hora sobre a ROM do jogador.
local Buffer = require("src.romhack.buffer")
local Dialogs = require("src.romhack.dialogs")

local Patcher = {}

local at = Buffer.at

-- Correção da autocura do inimigo ($18:$6934, ver docs/FINDINGS.md "IA dos inimigos"): o original
-- faz HP += cura sem limitar ao HP máximo. Troca "ld de,$C98E / call $2B12" por uma chamada a uma
-- rotina nova no fim do banco 0 ($3F80, área zerada depois do último código em $3F6A) que soma e
-- limita a [$C992] (HP máx da cópia da unidade em $C980).
Patcher.HEAL_AT = 0x3F80
function Patcher.fixHeal(rom)
  local o = at(0x18, 0x6968)
  rom:expect(o, "118ec9cd122b")
  for i = 0, 31 do
    if rom:u8(Patcher.HEAL_AT + i) ~= 0 then error("área do banco 0 em uso") end
  end
  rom:write(Patcher.HEAL_AT, {
    0x09,                   -- add hl, bc
    0xFA, 0x93, 0xC9,       -- ld a, [$C993]      HP máx (alto)
    0xBC,                   -- cp h
    0x38, 0x08,             -- jr c, .limita
    0x20, 0x0E,             -- jr nz, .grava
    0xFA, 0x92, 0xC9,       -- ld a, [$C992]      HP máx (baixo)
    0xBD,                   -- cp l
    0x30, 0x08,             -- jr nc, .grava
    0xFA, 0x92, 0xC9, 0x6F, -- .limita: ld a, [$C992] / ld l, a
    0xFA, 0x93, 0xC9, 0x67, --          ld a, [$C993] / ld h, a
    0x7D, 0xEA, 0x8E, 0xC9, -- .grava: ld a, l / ld [$C98E], a
    0x7C, 0xEA, 0x8F, 0xC9, --         ld a, h / ld [$C98F], a
    0xC9,                   -- ret
  })
  rom:write(o, { 0xCD, Patcher.HEAL_AT % 256, math.floor(Patcher.HEAL_AT / 256), 0x00, 0x00, 0x00 })
end

-- Bancos vazios no original (o jogo só usa bancos com o bit 1 desligado; os outros são zerados).
function Patcher.freeBanks(rom)
  local out = {}
  for b = 0x40, rom.size / 0x4000 - 1 do
    if rom:bankEmpty(b) then out[#out + 1] = b end
  end
  return out
end

-- opts: { pt = true, fixHeal = true, images = true }. Devolve bytes da ROM nova e um relatório.
function Patcher.build(bytes, opts)
  opts = opts or {}
  local rom = Buffer.new(bytes)
  local report = {}
  local free = Patcher.freeBanks(rom)
  local nextFree = 1
  local function takeBanks(n)
    local t = {}
    for i = 1, n do t[i] = free[nextFree]; nextFree = nextFree + 1 end
    return t
  end
  if opts.pt ~= false then
    local PT = require("src.game.translation_pt")
    Dialogs.font(rom)
    report.dialogs = Dialogs.apply(rom, PT, takeBanks(4))
    if opts.images ~= false then
      report.images = require("src.romhack.images").apply(rom)
      report.menus = require("src.romhack.menus").apply(rom)
    end
  end
  if opts.fixHeal ~= false then
    Patcher.fixHeal(rom)
    report.fixHeal = true
  end
  return rom:build(), report
end

return Patcher
