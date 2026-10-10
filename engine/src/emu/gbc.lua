-- Executor mínimo de Game Boy Color para rodar trechos do código ORIGINAL da ROM do jogador
-- (a animação de batalha, ver docs/FINDINGS.md "Animação de batalha"). Não é um emulador completo:
-- não tem som próprio nem entrada, e o vídeo é montado por quadro a partir da VRAM/OAM/paletas, com
-- os registradores de rolagem guardados linha a linha (o jogo muda o SCX no meio da tela).
-- A CPU é o interpretador de src/util/sm83.lua.
local CPU = require("src.util.sm83")
local bit = require("src.util.bit")
local band, bor, rshift = bit.band, bit.bor, bit.rshift

local GBC = {}
GBC.__index = GBC

-- Ciclos (T) por opcode, sem o acréscimo de desvio tomado.
local CYC = {
  4, 12, 8, 8, 4, 4, 8, 4, 20, 8, 8, 8, 4, 4, 8, 4,
  4, 12, 8, 8, 4, 4, 8, 4, 12, 8, 8, 8, 4, 4, 8, 4,
  8, 12, 8, 8, 4, 4, 8, 4, 8, 8, 8, 8, 4, 4, 8, 4,
  8, 12, 8, 8, 12, 12, 12, 4, 8, 8, 8, 8, 4, 4, 8, 4,
}
for op = 0x40, 0xBF do
  local c = 4
  if op % 8 == 6 or (op >= 0x70 and op < 0x78) then c = 8 end
  CYC[op + 1] = c
end
CYC[0x76 + 1] = 4
local HI = {
  8, 12, 12, 16, 12, 16, 8, 16, 8, 16, 12, 4, 12, 24, 8, 16,
  8, 12, 12, 4, 12, 16, 8, 16, 8, 16, 12, 4, 12, 4, 8, 16,
  12, 12, 8, 4, 4, 16, 8, 16, 16, 4, 16, 4, 4, 4, 8, 16,
  12, 12, 8, 4, 4, 16, 8, 16, 12, 8, 16, 4, 4, 4, 8, 16,
}
for i = 1, 64 do CYC[0xC0 + i] = HI[i] end

local function zeros(n) local t = {} for i = 0, n - 1 do t[i] = 0 end return t end

-- rom: string com a ROM inteira.
function GBC.new(rom)
  local self = setmetatable({
    rom = rom, romBanks = {}, romBank = 1, ramBank = 0, ramOn = true,
    wram = {}, svbk = 1, vram = { [0] = zeros(0x2000), [1] = zeros(0x2000) }, vbk = 0,
    sram = {}, oam = zeros(0xA0), io = zeros(0x80), hram = zeros(0x80), ie = 0, iflag = 0,
    bgpal = zeros(64), obpal = zeros(64), bcps = 0, ocps = 0,
    ly = 0, lineCyc = 0, double = false, frames = 0, lines = {}, cycles = 0,
    halted = false, hooks = {}, writeHooks = {},
  }, GBC)
  for b = 0, 7 do self.wram[b] = zeros(0x1000) end
  for b = 0, 3 do self.sram[b] = zeros(0x2000) end
  self.cpu = CPU.new(function(a) return self:read(a) end, function(a, v) self:write(a, v) end)
  self.cpu.ime = true
  return self
end

function GBC:romByte(bank, off)
  local t = self.romBanks[bank]
  if not t then
    t = {}
    local s = self.rom:sub(bank * 0x4000 + 1, bank * 0x4000 + 0x4000)
    for i = 1, #s, 1024 do
      local chunk = { s:byte(i, math.min(i + 1023, #s)) }
      for j = 1, #chunk do t[i + j - 2] = chunk[j] end
    end
    self.romBanks[bank] = t
  end
  return t[off] or 0xFF
end

function GBC:read(a)
  if a < 0x4000 then return self:romByte(0, a) end
  if a < 0x8000 then return self:romByte(self.romBank, a - 0x4000) end
  if a < 0xA000 then return self.vram[self.vbk][a - 0x8000] end
  if a < 0xC000 then return self.sram[self.ramBank % 4][a - 0xA000] end
  if a < 0xD000 then return self.wram[0][a - 0xC000] end
  if a < 0xE000 then return self.wram[self.svbk][a - 0xD000] end
  if a < 0xFE00 then return self:read(a - 0x2000) end
  if a < 0xFEA0 then return self.oam[a - 0xFE00] end
  if a < 0xFF00 then return 0xFF end
  if a >= 0xFF80 then
    if a == 0xFFFF then return self.ie end
    return self.hram[a - 0xFF80]
  end
  local r = a - 0xFF00
  if r == 0x00 then return 0xFF end                          -- nenhum botão
  if r == 0x04 then return band(rshift(self.cycles, 8), 0xFF) end
  if r == 0x0F then return bor(self.iflag, 0xE0) end
  if r == 0x41 then
    local mode
    local line = self.double and 912 or 456
    if self.ly >= 144 then mode = 1
    elseif self.lineCyc < line * 80 / 456 then mode = 2
    elseif self.lineCyc < line * 252 / 456 then mode = 3
    else mode = 0 end
    return bor(band(self.io[0x41], 0x78), (self.ly == self.io[0x45]) and 4 or 0, mode)
  end
  if r == 0x44 then return self.ly end
  if r == 0x4D then return bor(self.double and 0x80 or 0, band(self.io[0x4D], 1)) end
  if r == 0x4F then return bor(self.vbk, 0xFE) end
  if r == 0x55 then return 0xFF end
  if r == 0x69 then return self.bgpal[band(self.bcps, 63)] end
  if r == 0x6B then return self.obpal[band(self.ocps, 63)] end
  if r == 0x70 then return self.svbk end
  return self.io[r]
end

function GBC:write(a, v)
  if a < 0x8000 then
    if a < 0x2000 then self.ramOn = band(v, 0x0F) == 0x0A
    elseif a < 0x3000 then self.romBank = band(self.romBank, 0x100) + v
    elseif a < 0x4000 then self.romBank = band(self.romBank, 0xFF) + band(v, 1) * 256
    elseif a < 0x6000 then self.ramBank = band(v, 0x0F) end
    return
  end
  if a < 0xA000 then self.vram[self.vbk][a - 0x8000] = v return end
  if a < 0xC000 then self.sram[self.ramBank % 4][a - 0xA000] = v return end
  if a < 0xD000 then self.wram[0][a - 0xC000] = v return end
  if a < 0xE000 then self.wram[self.svbk][a - 0xD000] = v return end
  if a < 0xFE00 then return self:write(a - 0x2000, v) end
  if a < 0xFEA0 then self.oam[a - 0xFE00] = v return end
  if a < 0xFF00 then return end
  if a >= 0xFF80 then
    if a == 0xFFFF then self.ie = v return end
    self.hram[a - 0xFF80] = v
    local h = self.writeHooks[a]
    if h then h(v) end
    return
  end
  local r = a - 0xFF00
  if r == 0x0F then self.iflag = band(v, 0x1F) return end
  if r == 0x44 then return end
  if r == 0x46 then
    for i = 0, 0x9F do self.oam[i] = self:read(v * 0x100 + i) end
    return
  end
  if r == 0x4F then self.vbk = band(v, 1) return end
  if r == 0x55 then                                          -- HDMA: copia na hora
    local src = band(self.io[0x51] * 256 + self.io[0x52], 0xFFF0)
    local dst = band(self.io[0x53] * 256 + self.io[0x54], 0x1FF0)
    local n = (band(v, 0x7F) + 1) * 16
    local vr = self.vram[self.vbk]
    for i = 0, n - 1 do vr[band(dst + i, 0x1FFF)] = self:read(band(src + i, 0xFFFF)) end
    return
  end
  if r == 0x68 then self.bcps = v return end
  if r == 0x69 then
    self.bgpal[band(self.bcps, 63)] = v
    if self.bcps >= 128 then self.bcps = 128 + band(self.bcps + 1, 63) end
    return
  end
  if r == 0x6A then self.ocps = v return end
  if r == 0x6B then
    self.obpal[band(self.ocps, 63)] = v
    if self.ocps >= 128 then self.ocps = 128 + band(self.ocps + 1, 63) end
    return
  end
  if r == 0x70 then self.svbk = math.max(1, band(v, 7)) return end
  self.io[r] = v
end

-- Guarda os registradores de vídeo da linha (o jogo muda SCX numa interrupção de linha).
function GBC:latchLine()
  local io = self.io
  self.lines[self.ly] = { scx = io[0x43], scy = io[0x42], wx = io[0x4B], wy = io[0x4A], lcdc = io[0x40] }
end

function GBC:advance(c)
  self.cycles = self.cycles + c
  local line = self.double and 912 or 456
  local before = self.lineCyc
  self.lineCyc = before + c
  local mid = line * 252 / 456
  if before < mid and self.lineCyc >= mid and self.ly < 144 then self:latchLine() end
  while self.lineCyc >= line do
    self.lineCyc = self.lineCyc - line
    self.ly = (self.ly + 1) % 154
    if self.ly == 144 then
      self.iflag = bor(self.iflag, 1)
      self.frameDone = true
    end
    if self.ly == self.io[0x45] and band(self.io[0x41], 0x40) ~= 0 then self.iflag = bor(self.iflag, 2) end
  end
end

local VEC = { [0] = 0x40, 0x48, 0x50, 0x58, 0x60 }

-- Roda até o próximo VBlank (um quadro). limit = máximo de instruções.
function GBC:frame(limit)
  local cpu = self.cpu
  limit = limit or 400000
  self.frameDone = false
  for _ = 1, limit do
    local pending = band(self.ie, self.iflag)
    if pending ~= 0 then
      self.halted = false
      if cpu.ime then
        for i = 0, 4 do
          if band(pending, 2 ^ i) ~= 0 then
            self.iflag = self.iflag - 2 ^ i
            cpu.ime = false
            CPU.push(cpu, cpu.pc)
            cpu.pc = VEC[i]
            self:advance(20)
            break
          end
        end
      end
    end
    if self.halted then
      self:advance(4)
    else
      local pc = cpu.pc
      local hook = self.hooks[pc]
      if hook and hook(self) then
        -- o gancho tratou a instrução (por exemplo, simulou um retorno)
      else
        local op = self:read(pc)
        local c = CYC[op + 1]
        if op == 0xCB then
          local o2 = self:read(band(pc + 1, 0xFFFF))
          c = (o2 % 8 == 6) and ((o2 >= 0x40 and o2 < 0x80) and 12 or 16) or 8
        end
        if cpu:step() == "halt" then self.halted = true end
        if op == 0x10 and band(self.io[0x4D], 1) == 1 then     -- STOP com troca de velocidade
          self.double = not self.double
          self.io[0x4D] = 0
        end
        self:advance(c)
      end
    end
    if self.frameDone then
      self.frames = self.frames + 1
      return true
    end
    if self.stopped then return false end
  end
  return false
end

-- Cor RGB555 -> 0..1
local function rgb(lo, hi)
  local v = lo + hi * 256
  return (v % 32) / 31, (math.floor(v / 32) % 32) / 31, (math.floor(v / 1024) % 32) / 31
end

-- Monta o quadro atual: chama plot(x, y, r, g, b) para cada pixel.
function GBC:render(plot)
  local v0, v1 = self.vram[0], self.vram[1]
  local bgc, obc = {}, {}
  for p = 0, 7 do
    for c = 0, 3 do
      bgc[p * 4 + c] = { rgb(self.bgpal[p * 8 + c * 2], self.bgpal[p * 8 + c * 2 + 1]) }
      obc[p * 4 + c] = { rgb(self.obpal[p * 8 + c * 2], self.obpal[p * 8 + c * 2 + 1]) }
    end
  end
  local winLine = 0
  local lineBuf, prio = {}, {}
  for y = 0, 143 do
    local L = self.lines[y] or { scx = self.io[0x43], scy = self.io[0x42], wx = self.io[0x4B], wy = self.io[0x4A], lcdc = self.io[0x40] }
    local lcdc = L.lcdc
    if lcdc < 128 then
      for x = 0, 159 do plot(x, y, 1, 1, 1) end
    else
      local winOn = band(lcdc, 0x20) ~= 0 and y >= L.wy and L.wx <= 166
      local usedWin = false
      for x = 0, 159 do
        local mapBase, tx, ty, px, py
        if winOn and x >= L.wx - 7 then
          mapBase = band(lcdc, 0x40) ~= 0 and 0x1C00 or 0x1800
          local wx = x - (L.wx - 7)
          tx, ty, px, py = math.floor(wx / 8), math.floor(winLine / 8), wx % 8, winLine % 8
          usedWin = true
        else
          mapBase = band(lcdc, 0x08) ~= 0 and 0x1C00 or 0x1800
          local bx, by = (x + L.scx) % 256, (y + L.scy) % 256
          tx, ty, px, py = math.floor(bx / 8), math.floor(by / 8), bx % 8, by % 8
        end
        local mi = mapBase + ty * 32 + tx
        local idx, attr = v0[mi], v1[mi]
        local base
        if band(lcdc, 0x10) ~= 0 then base = idx * 16 else base = 0x1000 + (idx >= 128 and idx - 256 or idx) * 16 end
        if band(attr, 0x40) ~= 0 then py = 7 - py end
        if band(attr, 0x20) ~= 0 then px = 7 - px end
        local vr = band(attr, 8) ~= 0 and v1 or v0
        local lo, hi = vr[base + py * 2], vr[base + py * 2 + 1]
        local b = 7 - px
        local c = (math.floor(lo / 2 ^ b) % 2) + 2 * (math.floor(hi / 2 ^ b) % 2)
        lineBuf[x] = bgc[band(attr, 7) * 4 + c]
        prio[x] = (c ~= 0) and ((band(attr, 0x80) ~= 0) and 2 or 1) or 0
      end
      if usedWin then winLine = winLine + 1 end
      if band(lcdc, 2) ~= 0 then
        local h = band(lcdc, 4) ~= 0 and 16 or 8
        local n, drawn = 0, {}
        for s = 0, 39 do
          local sy = self.oam[s * 4] - 16
          if y >= sy and y < sy + h then
            n = n + 1
            if n > 10 then break end
            drawn[#drawn + 1] = s
          end
        end
        for i = #drawn, 1, -1 do                      -- índice menor fica por cima
          local s = drawn[i]
          local sy, sx = self.oam[s * 4] - 16, self.oam[s * 4 + 1] - 8
          local tile, attr = self.oam[s * 4 + 2], self.oam[s * 4 + 3]
          if h == 16 then tile = band(tile, 0xFE) end
          local row = y - sy
          if band(attr, 0x40) ~= 0 then row = h - 1 - row end
          local vr = band(attr, 8) ~= 0 and v1 or v0
          local base = tile * 16 + row * 2
          local lo, hi = vr[base], vr[base + 1]
          for px = 0, 7 do
            local x = sx + px
            if x >= 0 and x < 160 then
              local b = band(attr, 0x20) ~= 0 and px or 7 - px
              local c = (math.floor(lo / 2 ^ b) % 2) + 2 * (math.floor(hi / 2 ^ b) % 2)
              if c ~= 0 then
                local behind = prio[x] == 2 or (band(attr, 0x80) ~= 0 and prio[x] == 1)
                if band(lcdc, 1) == 0 or not behind then lineBuf[x] = obc[band(attr, 7) * 4 + c] end
              end
            end
          end
        end
      end
      for x = 0, 159 do local c = lineBuf[x]; plot(x, y, c[1], c[2], c[3]) end
    end
  end
end

return GBC
