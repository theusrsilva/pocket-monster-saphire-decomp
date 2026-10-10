-- Referência de desenvolvimento: executa o código ORIGINAL da cena de ataque no executor GBC
-- (src/emu/gbc.lua) a partir de $01:$63B9 até a volta de ApplyAttack ($09:$62EC / $09:$64C7),
-- com as mesmas entradas da reimplementação (src/anim/attack.lua), para conferi-la quadro a quadro.
-- O jogo usa a reimplementação; isto fica para os testes e --attack-emu. Ver docs/FINDINGS.md,
-- "Animação de batalha".
--
-- Entradas (montadas por Attack.new): $C900/$C980 registros do aliado/inimigo, $C1D0-$C1D5 personagens,
-- ações e resultados, $CD03/$CD43 dano, $C008 quem ataca, $C220 terreno.
local GBC = require("src.emu.gbc")

local Scene = {}
Scene.__index = Scene

local SENTINEL = 0xFFFE

local function at(bank, addr) return bank * 0x4000 + addr - 0x4000 end

local function poke(m, a, v) m:write(a, v % 256) end

-- ev: como em Attack.new, com ev.rom = a ROM inteira (string).
function Scene.new(ev)
  local rom = assert(ev.rom, "battlescene: precisa de ev.rom")
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
  -- unidades e resultado: as mesmas entradas da cena reimplementada (src/anim/attack.lua)
  local A = require("src.anim.attack").new(require("src.anim.slice").fromRom(rom), ev)
  for a = 0xC900, 0xC9FF do poke(m, a, A.M[a]) end
  for _, a in ipairs({ 0xC1D0, 0xC1D1, 0xC1D2, 0xC1D3, 0xC1D4, 0xC1D5, 0xCD03, 0xCD04, 0xCD43, 0xCD44,
      0xC008, 0xC220, 0xC035 }) do
    poke(m, a, A.M[a])
  end
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
