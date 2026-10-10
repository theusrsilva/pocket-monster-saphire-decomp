-- Animação de batalha ORIGINAL: executa o código do jogo (ROM do jogador) no executor GBC
-- (src/emu/gbc.lua) a partir de $01:$63B9 até a volta de ApplyAttack ($09:$62EC / $09:$64C7),
-- com o estado montado a partir do resultado já calculado pelo motor. Ver docs/FINDINGS.md,
-- "Animação de batalha".
--
-- Entradas que o código original lê (rastreadas no executor):
--   $C900 / $C980  cópias de 128 bytes do atacante e do defensor (formato da SRAM; +$42/+$43 =
--                  endereço do registro na SRAM, +$46/+$47 = HP mostrado na barra)
--   $C1D0 / $C1D3  personagem = $7C + espécie (atacante / defensor)
--   $C1D1 / $C1D4  ação: 2 = ataque normal, golpe = tabela $09:$6F4D; $C1D4 = 1: sem contra
--   $C1D5 / $C1D2  resultado: $0C acertou, $10 errou (ataque / contra)
--   $CD43 / $CD03  dano (ataque / contra)
--   $C008          0 = aliado ataca ($09:$62EC), 1 = inimigo ataca ($09:$64C7)
--   $C220          terreno -> cenário e música ($38:$7124)
local GBC = require("src.emu.gbc")

local Scene = {}
Scene.__index = Scene

local ROMFILE = "generated/rom.bin"
local SENTINEL = 0xFFFE

function Scene.available()
  return love.filesystem.getInfo(ROMFILE) ~= nil
end

local romCache
local function romBytes()
  romCache = romCache or love.filesystem.read(ROMFILE)
  return romCache
end

local function at(bank, addr) return bank * 0x4000 + addr - 0x4000 end

-- Animação de ação do golpe para a espécie: tabela $09:$6F4D[espécie] -> 4 pares [golpe, anim];
-- sem par igual vale o último ($09:$6EAD).
function Scene.skillAnim(rom, species, skill)
  local p = at(0x09, 0x6F4D) + species * 2
  local list = rom:byte(p + 1) + rom:byte(p + 2) * 256
  local o = at(0x09, list)
  for i = 0, 2 do
    if rom:byte(o + i * 2 + 1) == skill then return rom:byte(o + i * 2 + 2) end
  end
  return rom:byte(o + 3 * 2 + 2)
end

local function poke(m, a, v) m:write(a, v % 256) end
local function poke16(m, a, v) poke(m, a, v); poke(m, a + 1, math.floor(v / 256)) end

-- Registro de unidade (formato da SRAM, docs/FINDINGS.md "SRAM") em base.
local function writeUnit(m, base, u, hpShown, sramAddr)
  for i = 0, 0x7F do poke(m, base + i, 0) end
  poke(m, base + 0, 1)
  poke(m, base + 2, u.level or 1)
  poke(m, base + 5, u.species)
  poke(m, base + 6, u.type or 1)
  poke16(m, base + 7, (u.y or 0) * 16)
  poke16(m, base + 9, (u.x or 0) * 16)
  poke16(m, base + 12, u.sp or 0)
  poke16(m, base + 14, u.hp or 0)
  poke16(m, base + 16, u.maxsp or 0)
  poke16(m, base + 18, u.maxhp or 0)
  poke16(m, base + 20, u.atk or 0)
  poke16(m, base + 22, u.acc or 0)
  poke16(m, base + 24, u.eva or 0)
  poke(m, base + 26, u.move or 0)
  poke(m, base + 27, u.strong or 0)
  poke(m, base + 28, u.weak or 0)
  poke(m, base + 34, u.rmin or 1)
  poke(m, base + 35, u.rmax or 1)
  poke16(m, base + 0x42, sramAddr)
  poke16(m, base + 0x46, hpShown)
end

-- ev = { att = unidade antes do golpe, def = unidade antes, skill = id|nil, hit, dmg,
--        counter = nil | { skill = id|nil, hit, dmg }, enemyTurn = bool, stage = n, terrain = n }
function Scene.new(ev)
  local rom = ev.rom or romBytes()
  local m = GBC.new(rom)
  local self = setmetatable({ m = m, ev = ev, done = false, frames = 0, acc = 0 }, Scene)
  m.double = true
  for i = 0, 14 do poke(m, 0xFFA0 + i, rom:byte(0x2A60 + i + 1)) end   -- rotina de DMA (ROM0:$2A48)
  poke(m, 0xFF9F, 0x11)                                                 -- console = GBC
  m.ie = 1
  -- paletas de interface (BG 4-7) da fase, como no mapa: cabeçalho $7D:$4000 + fase*64, bloco 0
  local h = at(0x7D, 0x4000) + (ev.stage or 1) * 64
  local pb, pa = rom:byte(h + 1), rom:byte(h + 3) + rom:byte(h + 4) * 256
  local po = at(pb, pa)
  for i = 0, 63 do m.bgpal[i] = rom:byte(po + i + 1) end
  -- unidades e resultado
  local a, d = ev.att, ev.def
  writeUnit(m, 0xC900, a, a.hp, ev.enemyTurn and 0xB200 or 0xAA00)
  writeUnit(m, 0xC980, d, d.hp, ev.enemyTurn and 0xAA00 or 0xB200)
  poke(m, 0xC008, ev.enemyTurn and 1 or 0)
  poke(m, 0xC1D0, 0x7C + a.species)
  poke(m, 0xC1D3, 0x7C + d.species)
  poke(m, 0xC1D1, ev.skill and Scene.skillAnim(rom, a.species, ev.skill) or 2)
  poke(m, 0xC1D5, ev.hit and 0x0C or 0x10)
  poke16(m, 0xCD43, ev.hit and ev.dmg or 0)
  local c = ev.counter
  if c then
    poke(m, 0xC1D4, c.skill and Scene.skillAnim(rom, d.species, c.skill) or 2)
    poke(m, 0xC1D2, c.hit and 0x0C or 0x10)
    poke16(m, 0xCD03, c.hit and c.dmg or 0)
  else
    poke(m, 0xC1D4, 1)
    poke(m, 0xC1D2, 0x10)
  end
  poke(m, 0xC220, ev.terrain or 0)
  poke(m, 0xC035, 50)
  -- inicializa o driver de som ($2C:$4000) e entra em $01:$63B9 (início do ataque)
  self:callFar(0x2C, 0x4000)
  m.hooks[SENTINEL] = function(mm) mm.stopped = true; return true end
  m.hooks[0x6440] = function(mm) if mm.romBank == 1 then mm.stopped = true; return true end end
  local cpu = m.cpu
  cpu.sp = 0xCFF0
  require("src.util.sm83").push(cpu, SENTINEL)
  m.romBank = 1
  cpu.pc = 0x63B9
  cpu.ime = true
  m.stopped = false
  self.img = love.image.newImageData(160, 144)
  self.image = love.graphics.newImage(self.img)
  self.image:setFilter("nearest", "nearest")
  return self
end

-- Chama uma rotina (fora do laço de quadros) até ela retornar.
function Scene:callFar(bank, addr)
  local m, cpu = self.m, self.m.cpu
  local saveBank = m.romBank
  m.romBank = bank
  cpu.sp = 0xCFF0
  cpu:call(addr, 2000000)
  m.romBank = saveBank
end

-- Avança um quadro do jogo original (60 por segundo). Devolve false quando a cena acabou.
function Scene:step()
  if self.done then return false end
  local m = self.m
  local ok = m:frame(600000)
  if m.stopped or not ok then
    self.done = true
    return false
  end
  self.frames = self.frames + 1
  local img = self.img
  m:render(function(x, y, r, g, b) img:setPixel(x, y, r, g, b, 1) end)
  self.image:replacePixels(img)
  return true
end

-- Roda no ritmo do jogo (60 quadros/s). skip = pular a cena.
function Scene:update(dt)
  self.acc = self.acc + dt
  local n = 0
  while self.acc >= 1 / 60 and n < 4 do
    self.acc = self.acc - 1 / 60
    n = n + 1
    if not self:step() then return false end
  end
  return not self.done
end

function Scene:draw(x, y, scale)
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(self.image, x, y, 0, scale, scale)
end

return Scene
