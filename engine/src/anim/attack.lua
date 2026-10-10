-- Cena de ataque ORIGINAL reimplementada em Lua (sem emulador): as rotinas do jogo que montam a
-- cena foram transliteradas uma a uma, com as variáveis nos mesmos endereços da WRAM, e leem os
-- dados (scripts de animação, quadros, tiles, cenário, paletas) da ROM do jogador através de um
-- leitor rom:u8(banco, endereço). Ver docs/FINDINGS.md, "Animação de batalha".
--
-- Rotinas (endereço do original -> função aqui):
--   $01:$63B9 início do ataque (cenário $38:$7124, música $01:$64AB)      -> Scene.new / flow
--   $09:$62EC / $09:$64C7 ApplyAttack (aliado / inimigo ataca)              -> applyAlly / applyEnemy
--   $00:$083F laço da cena e fim por objetos parados ($086A)               -> sceneLoop
--   $00:$1D7E objetos: scripts de 4 bytes, comandos $80-$92 ($20AC)        -> updateObjects
--   $00:$3B22 cria objeto a partir do modelo $1C:$4000 + personagem*16     -> spawn
--   $2D:$423F caixas de colisão por quadro ($2D:$43ED)                     -> boxes
--   $2D:$4BE9 / $4DCB colisão do golpe com o alvo                           -> collide1 / collide2
--   $00:$1AC2 / $1BD4 montagem da OAM (metasprites $80:$4000)              -> buildOAM
--   $00:$0C3C VBlank: contador, tiles dos quadros ($2572, tabela $80:$4400) -> vblank
--   $00:$2CEB / $2D35 scripts de cenário do banco $BC                      -> runBG
--   $08:$4BEC barra de HP, $09:$695F / $6993 dano, $09:$66AA desmaio
local bit = require("src.util.bit")
local band, bor, bxor = bit.band, bit.bor, bit.bxor
local floor = math.floor

local Attack = {}
Attack.__index = Attack

local function sx(v) if v >= 128 then return v - 256 end return v end

-- ---------------------------------------------------------------------------------------------
-- Memória: WRAM ($C000-$DFFF) e HRAM num vetor plano; VRAM em dois bancos; paletas CGB.

local function newState(rom)
  local M = {}
  for a = 0xC000, 0xDFFF do M[a] = 0 end
  for a = 0xFF80, 0xFFFF do M[a] = 0 end
  local V = { [0] = {}, [1] = {} }
  for b = 0, 1 do for i = 0, 0x1FFF do V[b][i] = 0 end end
  local bp, op, oam = {}, {}, {}
  for i = 0, 63 do bp[i] = 0; op[i] = 0 end
  for i = 0, 159 do oam[i] = 0 end
  return { rom = rom, M = M, V = V, bgpal = bp, obpal = op, oam = oam, vbk = 0, bcps = 0, ocps = 0,
    lcdc = 0xE7, dirtyTiles = {}, dirtyCells = {}, dirtyMap = true, tileVer = {}, obpalVer = {} }
end

function Attack:r16(a) local M = self.M return M[a] + M[a + 1] * 256 end
function Attack:w16(a, v)
  v = v % 65536
  self.M[a] = v % 256
  self.M[a + 1] = floor(v / 256)
end
function Attack:R(bank, a) return self.rom:u8(a < 0x4000 and 0 or bank, a) end
function Attack:R16(bank, a) return self:R(bank, a) + self:R(bank, a + 1) * 256 end

-- Escrita na VRAM (registra tiles alterados para o desenho).
function Attack:vwrite(bank, off, v)
  off = band(off, 0x1FFF)
  if self.V[bank][off] == v then return end
  self.V[bank][off] = v
  if off < 0x1800 then
    local t = bank * 384 + floor(off / 16)
    self.dirtyTiles[t] = true
    self.tileVer[t] = (self.tileVer[t] or 0) + 1
  else
    self.dirtyCells[off - 0x1800] = true
  end
end

-- Escritas que esperam o modo do LCD ($00:$2B3A) gastam tempo: cerca de 640 por quadro (medido no
-- executor). Passando disso, o VBlank acontece no meio da cópia.
local SLOW_PER_FRAME = 640
function Attack:slow()
  self.slowCount = (self.slowCount or 0) + 1
  if self.slowCount >= SLOW_PER_FRAME then self:waitVBlank() end
end

-- Escrita de cor (BCPS/BCPD = 0, OCPS/OCPD = 1) com autoincremento.
function Attack:palSpec(which, v) if which == 0 then self.bcps = v else self.ocps = v end end
function Attack:palData(which, v)
  if which == 0 then
    if self.bgpal[band(self.bcps, 63)] ~= v then
      self.bgpal[band(self.bcps, 63)] = v
      self.dirtyMap = true
    end
    if self.bcps >= 128 then self.bcps = 128 + band(self.bcps + 1, 63) end
  else
    local i = band(self.ocps, 63)
    if self.obpal[i] ~= v then
      self.obpal[i] = v
      self.obpalVer[floor(i / 8)] = (self.obpalVer[floor(i / 8)] or 0) + 1
    end
    if self.ocps >= 128 then self.ocps = 128 + band(self.ocps + 1, 63) end
  end
end

-- ---------------------------------------------------------------------------------------------
-- Quadros: wait() = esperar o próximo VBlank (a corrotina devolve o controle ao motor).

function Attack:waitVBlank() coroutine.yield() end

-- $00:$2A02: espera o contador de quadros ($C030) mudar.
function Attack:waitFrame()
  local M = self.M
  while M[0xC030] == M[0xC031] do self:waitVBlank() end
  M[0xC031] = M[0xC030]
end

-- $00:$2A12: espera [$C034] quadros (botões são tratados pelo motor: pular a cena).
function Attack:waitN()
  local M = self.M
  local e = M[0xC034]
  local b = M[0xC031]
  while true do
    while M[0xC030] == b do self:waitVBlank() end
    b = M[0xC030]
    M[0xC031] = b
    e = (e - 1) % 256
    if e == 0 then return end
  end
end

-- VBlank ($00:$0C3C), só o que a cena usa.
function Attack:vblank()
  local M = self.M
  local c = M[0xC030] + 1
  M[0xC030] = c % 256
  M[0xC032] = (M[0xC032] + floor(c / 256)) % 256
  M[0xC037] = M[0xC032]
  self.slowCount = 0
  if M[0xC062] ~= 0 then return end
  -- $2572: tiles do quadro de cada objeto por HDMA
  for slot = 0, 11 do
    local o = 0xDB00 + slot * 0x40
    if M[o] ~= 0 and M[o + 5] ~= 0 and M[o + 0x2C] ~= 0 then
      local bank = M[o + 0x2C]
      local dst = M[o + 0x2D] + M[o + 0x2E] * 256
      local src = M[o + 0x2A] + M[o + 0x2B] * 256
      local len = self:R(bank, src) * 256 + self:R(bank, src + 1)
      local n = (band(floor(len / 16) - 1, 0x7F) + 1) * 16
      src = band(src + 16, 0xFFF0)
      dst = band(dst, 0x1FF0)
      local vb = band(M[o + 0x33], 1)
      for i = 0, n - 1 do self:vwrite(vb, dst + i, self:R(bank, src + i)) end
    end
  end
  -- DMA da OAM a partir de $C600
  if M[0xC43F] ~= 0 then
    for i = 0, 159 do self.oam[i] = M[0xC600 + i] end
    M[0xC43F] = 0
  end
  -- $0D7A: aleatório
  local r = M[0xC035] + 1 + band(M[0xC037], 0x3F)
  if r >= 100 then r = r - 100 end
  M[0xC035] = r % 256
end

-- ---------------------------------------------------------------------------------------------
-- Objetos ($DB00 + $40 * n, 12 objetos)

-- $2D:$423F: caixas do quadro atual (tabela $2D:$43ED[personagem] -> 10 bytes por quadro).
function Attack:boxes(o)
  local M = self.M
  if M[o] == 0 then return end
  local tp = self:R16(0x2D, 0x43ED + M[o + 0x0F] * 2)
  if self:R(0x2D, tp) == 0xFF and self:R(0x2D, tp + 1) == 0xFF then return end
  local e = tp + M[o + 5] * 10
  local t = {}
  for i = 0, 9 do t[i] = sx(self:R(0x2D, e + i)) end
  local Y, X = self:r16(o + 1), self:r16(o + 3)
  local flip = M[o + 0x12] ~= 0
  self:w16(o + 0x15, Y + t[0]); self:w16(o + 0x19, self:r16(o + 0x15) + t[1])
  self:w16(o + 0x13, X + (flip and t[3] or t[2])); self:w16(o + 0x17, self:r16(o + 0x13) + t[4])
  self:w16(o + 0x1F, Y + t[5]); self:w16(o + 0x23, self:r16(o + 0x1F) + t[6])
  self:w16(o + 0x1D, X + (flip and t[8] or t[7])); self:w16(o + 0x21, self:r16(o + 0x1D) + t[9])
end

-- $00:$3B22: cria um objeto do personagem [$C20C] em ($C208, $C20A). Devolve o endereço.
function Attack:spawn()
  local M = self.M
  local tp = 0x4000 + M[0xC20C] * 16
  local o
  for slot = 0, 11 do
    if M[0xDB00 + slot * 0x40] == 0 then o = 0xDB00 + slot * 0x40 break end
  end
  if not o then return nil end
  for i = 0, 0x3F do M[o + i] = 0 end
  M[o] = 1
  local t = {}
  for i = 0, 15 do t[i] = self:R(0x1C, tp + i) end
  M[o + 0x0F] = t[0]
  M[o + 0x10] = t[1]
  M[o + 0x12] = t[2]
  M[o + 0x11] = (M[0xC076] ~= 3) and M[0xC076] or t[6]
  M[0xC065] = t[7]
  M[o + 0x06] = t[8]
  M[o + 0x07] = t[9]
  M[o + 0x2D] = t[10]
  M[o + 0x2E] = t[11]
  M[o + 0x32] = t[12]
  for i = 0, 3 do M[o + 1 + i] = M[0xC208 + i] end
  M[o + 0x1D] = (M[o + 3] + 4) % 256
  M[o + 0x1E] = M[o + 4]
  M[o + 0x23] = M[o + 1]
  M[o + 0x24] = M[o + 2]
  self:w16(o + 0x21, self:r16(o + 3) + t[13])
  self:w16(o + 0x1F, self:r16(o + 1) - t[14])
  M[o + 0x0B] = M[0xC20D]
  M[o + 0x0C] = M[0xC20E]
  M[o + 0x33] = t[15]
  M[0xC40D] = 0
  return o
end

-- $00:$20AC: comando do script em hl (só os usados pelas animações: $80, $81, $85, $8C, $8E).
function Attack:command(o, bank, hl)
  local M = self.M
  local a = self:R(bank, hl)
  if a >= 0x93 then return hl end
  if a == 0x80 then                      -- vai para a animação n
    M[o + 0x10] = self:R(bank, hl + 1)
    return 0
  elseif a == 0x81 then                  -- vira
    M[o + 0x12] = bxor(M[o + 0x12], 1)
    return hl + 4
  elseif a == 0x85 then                  -- cria efeito: personagem, dy, dx, dx virado, ?, anim, ?
    local p = {}
    for i = 1, 7 do p[i] = self:R(bank, hl + i) end
    for i = 1, 7 do M[0xC0E2 + i] = p[i] end
    M[0xC20C] = p[1]
    self:w16(0xC208, self:r16(o + 1) + sx(p[2]))
    self:w16(0xC20A, self:r16(o + 3) + sx(M[o + 0x12] == 1 and p[4] or p[3]))
    local n = self:spawn()
    if n then
      M[n + 0x12] = M[o + 0x12]
      M[n + 0x10] = p[6]
    end
    return hl + 8
  elseif a == 0x8C then                  -- espera o sinal de $8E
    if M[0xC255] == 0 then return hl - 4 end
    M[0xC253] = 0
    M[0xC255] = 0
    return hl + 4
  elseif a == 0x8E then                  -- sinal
    M[0xC255] = 1
    return hl + 4
  end
  error(("animação: comando $%02X não implementado (personagem $%02X anim %d em %02X:%04X)"):format(a, M[o + 0x0F], M[o + 0x10], bank, hl))
end

-- $00:$1D7E
function Attack:updateObjects()
  local M = self.M
  M[0xC177] = 0
  for slot = 0, 11 do
    local o = 0xDB00 + slot * 0x40
    if M[o] ~= 0 and M[o + 0x10] ~= 0 then
      if M[o + 0x0A] ~= 0 then
        M[o + 0x0A] = M[o + 0x0A] - 1
      else
        self:boxes(o)
        local sp = self:r16(o + 0x28)
        if sp == 0 then
          local t = 0x4000 + M[o + 0x0F] * 4
          local list, bank = self:R16(0x04, t), self:R(0x04, t + 2)
          M[o + 0x27] = bank
          sp = self:R16(bank, list + M[o + 0x10] * 2)
          self:w16(o + 0x28, sp)
        end
        local bank = M[o + 0x27]
        local b0, b1 = self:R(bank, sp), self:R(bank, sp + 1)
        if band(b0, b1) == 0xFF then
          M[o] = 0
          self:w16(o + 0x28, 0)
        else
          M[o + 0x0D] = b0
          local dx = b1
          if M[o + 0x12] ~= 0 then dx = (256 - dx) % 256 end
          M[o + 0x0E] = dx
          self:w16(o + 1, self:r16(o + 1) + sx(b0))
          self:w16(o + 3, self:r16(o + 3) + sx(dx))
          M[o + 5] = self:R(bank, sp + 2)
          M[o + 0x0A] = self:R(bank, sp + 3)
          local hl = sp + 4
          if self:R(bank, hl) >= 0x80 then hl = self:command(o, bank, hl) end
          self:w16(o + 0x28, hl)
          -- tiles do quadro: $80:$4400 + personagem*4 -> lista; quadro*4 -> [banco, ?, ptr]
          local load = false
          if self:r16(o + 0x2D) ~= 0 then
            local t = 0x4400 + M[o + 0x0F] * 4
            local fb, fp = self:R(0x80, t), self:R16(0x80, t + 2)
            local e = fp + M[o + 5] * 4
            local gb, gp = self:R(fb, e), self:R16(fb, e + 2)
            M[o + 0x2A] = gp % 256
            M[o + 0x2B] = floor(gp / 256)
            M[o + 0x2C] = gb
            if gp ~= 0 and not (M[o + 0x2F] == gp % 256 and M[o + 0x30] == floor(gp / 256)
                and M[o + 0x31] == gb) then
              M[o + 0x2F] = gp % 256
              M[o + 0x30] = floor(gp / 256)
              M[o + 0x31] = gb
              load = true
            end
          end
          if not load then M[o + 0x2C] = 0 end
          M[0xC177] = 1
        end
      end
    end
  end
end

-- Comparações de $00:$2A70 (com sinal) e $00:$2ADC (sem sinal): 0 igual, 1 menor, 2 maior.
local function s16(v) if v >= 0x8000 then return v - 0x10000 end return v end
local function cmpS(a, b) a, b = s16(a), s16(b) if a == b then return 0 elseif a < b then return 1 end return 2 end

-- $2D:$4BE9 (alvo = objeto 0) e $2D:$4DCB (alvo = objeto 1).
function Attack:collide(which)
  local M = self.M
  local T = which == 1 and 0xDB00 or 0xDB40
  if M[T + 0x10] == 0x10 then return end
  for slot = 2, 11 do
    local o = 0xDB00 + slot * 0x40
    if M[o] ~= 0 and M[o + 5] ~= 0 and M[o + 0x26] == 0
        and not (M[T + 0x1D] == M[T + 0x21] and M[T + 0x1E] == M[T + 0x22])
        and not (M[o + 0x13] == M[o + 0x17] and M[o + 0x14] == M[o + 0x18])
        and not (self:r16(T + 0x1D) > self:r16(o + 0x17))
        and not (self:r16(o + 0x13) > self:r16(T + 0x21))
        and not (self:r16(T + 0x1F) > self:r16(o + 0x19))
        and not (self:r16(o + 0x15) > self:r16(T + 0x23)) then
      M[T + 0x10] = band(M[0xC035], 1) ~= 0 and 0x0D or 0x0F
      M[T + 0x0A] = 0
      self:w16(T + 0x28, 0)
      local tp = self:R16(0x2D, 0x4FA7 + M[o + 0x0F] * 2) + M[o + 0x10] * 2
      M[0xC1D7] = self:R(0x2D, tp)
      M[o] = self:R(0x2D, tp + 1)
      M[o + 0x26] = 1
      M[0xC1D9] = M[o + 0x12]
      M[0xC20C] = 0x79
      if which == 1 then
        self:w16(0xC20A, self:r16(o + 0x13) - 8)
        self:w16(0xC208, self:r16(o + 0x19) + 8)
        local n = self:spawn() or o
        M[n + 0x10] = 1
        M[n + 0x12] = bxor(M[0xC1D9], 1)
      else
        self:w16(0xC20A, self:r16(o + 0x17) - 0x18)
        self:w16(0xC208, self:r16(o + 0x19) + 8)
        M[o + 0x10] = M[0xC1D7]
        M[o + 0x12] = bxor(M[0xC1D9], 1)
      end
    end
  end
end

-- $38:$716B: paletas de sprite 0 (aliado, $C905) e 1 (inimigo, $C985) por espécie ($38:$71BC).
function Attack:speciesPalettes()
  local M = self.M
  for k, sp in ipairs({ M[0xC905], M[0xC985] }) do
    local p = self:R16(0x38, 0x71BC + sp * 2)
    self:palSpec(1, k == 1 and 0x80 or 0x88)
    for i = 0, 7 do self:palData(1, self:R(0x38, p + i)) end
  end
end

local ORDER_A = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local ORDER_B = { 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 }

-- $00:$1AC2: OAM em $C600 (ordem dos objetos alterna a cada chamada)
function Attack:buildOAM()
  local M = self.M
  local sy, sx0
  if M[0xC36A] == 1 then
    self:speciesPalettes(); sy, sx0 = 0, 0
  elseif M[0xC36A] == 2 then
    self:speciesPalettes(); sy, sx0 = 0, M[0xC36C]
  else
    sy, sx0 = self:r16(0xC230), self:r16(0xC232)
  end
  M[0xC366], M[0xC367] = sy % 256, floor(sy / 256)
  M[0xC368], M[0xC369] = sx0 % 256, floor(sx0 / 256)
  local n = M[0xC11C]
  M[0xC361] = band(M[0xC361] + 1, 1)
  local order = M[0xC361] ~= 0 and ORDER_A or ORDER_B
  for _, slot in ipairs(order) do
    local o = 0xDB00 + slot * 0x40
    if M[o] ~= 0 and M[o + 5] ~= 0 then
      n = self:drawObject(o, n, sy, sx0)
      if n >= 40 then break end
    end
  end
  for i = n * 4, 0x9E do M[0xC600 + i] = 0 end
  M[0xC11C] = 0
  M[0xC43F] = 1
end

-- $00:$1BD4: metasprite do objeto ($80:$4000 + personagem*4 -> [ptr, x base, banco]).
function Attack:drawObject(o, n, sy, sx0)
  local M = self.M
  local y = (self:r16(o + 1) - sy) % 65536
  local r = cmpS(y, 0xFFE0)
  if r == 1 or (r == 2 and cmpS(y, 0xB0) ~= 1) then return n end
  local x = (self:r16(o + 3) - sx0) % 65536
  r = cmpS(x, 0xFFE0)
  if r == 1 or (r == 2 and cmpS(x, 0xC0) ~= 1) then return n end
  if M[o + 0x1C] ~= 0 then
    local v = M[o + 0x1C] - 1
    M[o + 0x1C] = v
    if band(v, 4) == 0 then return n end
  end
  local mt = 0x4000 + M[o + 0x0F] * 4
  local ptr, xb, bank = self:R16(0x80, mt), self:R(0x80, mt + 2), self:R(0x80, mt + 3)
  local fp = self:R16(bank, ptr + M[o + 5] * 2)
  local count = self:R(bank, fp)
  if count == 0 then count = 256 end
  local e = fp + 2
  local flip = M[o + 0x12] ~= 0
  local cy, cx = y % 256, x % 256
  for _ = 1, count do
    local base = 0xC600 + n * 4
    M[base] = (cy + self:R(bank, e)) % 256
    M[base + 1] = (cx + xb + self:R(bank, e + (flip and 2 or 1))) % 256
    M[base + 2] = (self:R(bank, e + 3) + M[o + 7]) % 256
    local at = (bor(self:R(bank, e + 4), M[o + 6]) + M[o + 9]) % 256
    if flip then at = bxor(at, 0x20) end
    M[base + 3] = at
    e = e + 5
    n = n + 1
    if n >= 40 then break end
  end
  return n
end

-- $00:$086A: fim da cena quando os objetos 0 e 1 estão parados (anim < 2) por 100 quadros.
function Attack:sceneEnded()
  local M = self.M
  if (M[0xDB00] ~= 0 and M[0xDB10] >= 2) or (M[0xDB40] ~= 0 and M[0xDB50] >= 2) then
    M[0xC0DA] = 0
    return false
  end
  M[0xC0DA] = (M[0xC0DA] + 1) % 256
  return M[0xC0DA] >= 100
end

-- $00:$083F
function Attack:sceneLoop()
  local M = self.M
  self:waitFrame()
  self:updateObjects()
  self:buildOAM()
  self:waitFrame()
  while true do
    self:waitFrame()
    self:updateObjects()
    if M[0xC439] == 1 then self:collide(1) elseif M[0xC439] == 2 then self:collide(2) end
    M[0xC062] = 1
    self:buildOAM()
    M[0xC062] = 0
    if self:sceneEnded() then return end
  end
end

-- $09:$676A: objeto 0 (alvo, esquerda) e objeto 1 (direita, virado) prontos para a fase.
function Attack:setupObjects()
  local M = self.M
  M[0xDB01] = 0x60; M[0xDB03] = 0x20; M[0xDB02] = 0; M[0xDB04] = 0; M[0xDB05] = 0
  M[0xDB12] = 0; M[0xDB07] = 0; M[0xDB2D] = 0x20; M[0xDB2E] = 0x80; M[0xDB09] = 1
  M[0xC06D] = 1
  M[0xDB0A] = 0; M[0xDB28] = 0; M[0xDB29] = 0; M[0xDB31] = 0; M[0xDB33] = 0
  M[0xDB41] = 0x60; M[0xDB43] = 0xB0; M[0xDB42] = 0; M[0xDB44] = 0; M[0xDB45] = 0
  M[0xDB52] = 1; M[0xDB47] = 0; M[0xDB6D] = 0x20; M[0xDB6E] = 0x80; M[0xDB49] = 0
  M[0xC06D] = 0
  M[0xDB4A] = 0; M[0xDB68] = 0; M[0xDB69] = 0; M[0xDB71] = 0; M[0xDB73] = 0
  M[0xDB00] = 1; M[0xDB40] = 1
end

-- $09:$67F7: apaga os objetos 2-11
function Attack:clearEffects()
  for a = 0xDB80, 0xDDFF do self.M[a] = 0 end
end

-- $09:$695F / $6993: tira o dano do HP mostrado na cena (registro em $C980 / $C900).
function Attack:applyDamage(result, unit, dmg)
  local M = self.M
  if M[result] == 0x10 then return end
  local hp, d = self:r16(unit + 0x0E), self:r16(dmg)
  self:w16(unit + 0x0E, hp > d and hp - d or 0)          -- $00:$3ED0 / $3ED9 (mínimo 0)
end

-- ---------------------------------------------------------------------------------------------
-- Cenário: scripts do banco $BC ($00:$2D35). Comandos: $2DA0 memória, $2DDB HDMA, $2E3B paleta,
-- $2EB0 bloco do mapa, $5940 desvio, $322B número, $5D49 barra.

function Attack:runBG(p)
  local M = self.M
  while true do
    local h = self:R16(0xBC, p)
    if h == 0xFFFF then break end
    if h == 0x2DA0 then
      local q = p + 2
      while true do
        local e = self:R(0xBC, q)
        if e == 0xFF then p = q + 2 break end
        local de = e + self:R(0xBC, q + 1) * 256
        local c, b = self:R(0xBC, q + 2), self:R(0xBC, q + 3)
        M[de] = c
        if b >= 0x80 then M[de] = M[b * 256 + c] or 0 end
        q = q + 4
      end
    elseif h == 0x2DDB then
      M[0xC062] = 1
      self:waitFrame()
      local vb = band(self:R(0xBC, p + 2), 1)
      local dst = self:R(0xBC, p + 5) * 256 + self:R(0xBC, p + 4)
      local bank = self:R(0xBC, p + 6)
      local src = self:R(0xBC, p + 9) * 256 + self:R(0xBC, p + 8)
      local n = (band(self:R(0xBC, p + 10), 0x7F) + 1) * 16
      src, dst = band(src, 0xFFF0), band(dst, 0x1FF0)
      for i = 0, n - 1 do self:vwrite(vb, dst + i, self:R(bank, src + i)) end
      p = p + 12
      M[0xC062] = 0
    elseif h == 0x2E3B then
      local which = self:R(0xBC, p + 2)
      local bank = self:R(0xBC, p + 4)
      local src = self:R16(0xBC, p + 6)
      self:palSpec(which, self:R(0xBC, p + 8))
      for i = 0, self:R(0xBC, p + 10) - 1 do self:slow(); self:palData(which, self:R(bank, src + i)) end
      p = p + 12
    elseif h == 0x2EB0 then
      local vb = band(self:R(0xBC, p + 2), 1)
      local dst = self:R16(0xBC, p + 4) - 0x8000
      local bank = self:R(0xBC, p + 6)
      local src = self:R16(0xBC, p + 8)
      local rows, cols = self:R(0xBC, p + 10), self:R(0xBC, p + 11)
      for _ = 1, rows do
        for i = 0, cols - 1 do self:slow(); self:vwrite(vb, dst + i, self:R(bank, src + i)) end
        src = src + cols
        dst = dst + 32
      end
      p = p + 12
    elseif h == 0x5940 then
      p = self:R16(0xBC, p + 2)
    elseif h == 0x322B then
      self:drawNumber(p)
      p = p + 10
    elseif h == 0x5D49 or h == 0x5E23 then
      self:drawBar(p, h == 0x5E23)
      p = p + 10
    else
      error(("cenário: comando $%04X não implementado"):format(h))
    end
  end
  M[0xC177] = 1
end

-- $BC:$5EFF + $B5:$402E: número em dígitos (estilo $BC:$60A2), da direita para a esquerda.
function Attack:drawNumber(p)
  local M = self.M
  local dest = self:R16(0xBC, p + 2) - 0x8000
  local vaddr = self:R16(0xBC, p + 4)
  local count = self:R(0xBC, p + 6)
  local mode = self:R(0xBC, p + 7)
  local style = self:R(0xBC, p + 8)
  local flags = self:R(0xBC, p + 9)
  local d = {}
  for i = 0, 7 do d[i] = 0 end                    -- $C4A6..$C4AD
  local v
  if mode == 3 then v = M[vaddr] + M[vaddr + 1] * 256 + M[vaddr + 2] * 65536
  elseif mode == 2 then v = M[vaddr] + M[vaddr + 1] * 256
  elseif mode == 1 then v = M[vaddr]
  else v = nil end
  if v then
    local nd = mode == 3 and 8 or (mode == 2 and 5 or 3)
    for i = 7, 8 - nd, -1 do d[i] = v % 10; v = floor(v / 10) end
  end
  -- $BC:$5F54: dígitos acima do mostrado -> 9s; zeros à esquerda -> vazio ($FF)
  if count ~= 0 and count < 8 then
    local over = false
    for i = 7 - count, 0, -1 do if d[i] ~= 0 then over = true break end end
    if over then
      for i = 7, 8 - count, -1 do d[i] = 9 end
      for i = 7 - count, 0, -1 do d[i] = 0xFF end
    else
      for i = 0, 6 do
        if d[i] ~= 0 then break end
        d[i] = 0xFF
      end
    end
  end
  -- $BC:$5F9A
  local st = 0x60A2 + style * 6
  local tbl, h, w = self:R16(0xBC, st), self:R(0xBC, st + 2), self:R(0xBC, st + 4)
  if band(flags, 0x0F) ~= 0 then error("cenário: número alinhado ($BC:$6077) não implementado") end
  local i = 7
  for _ = 1, count do
    local c = d[i]
    if c == 0xFF then c = 0 end
    local hl = tbl + 2 * c * h * w
    local col = dest
    for _ = 1, h do
      local de = col
      for k = 1, w do
        self:slow()
        if band(flags, 0xF0) ~= 0 then self:vwrite(1, de, self:R(0xBC, hl)) end
        self:vwrite(0, de, self:R(0xBC, hl + 1))
        hl = hl + 2
        if k < w then de = de + 32 end
      end
      col = col - 1
    end
    dest = band(dest, 0xFF00) + band(dest - h, 0xFF)
    i = i - 1
  end
end

-- $BC:$5D49 / $5E23: barra de tiles ($C07B cheio, $C07A + n parcial), valor/máximo em pixels.
function Attack:drawBar(p, reverse)
  local M = self.M
  local partial, full = 0x0B, 0x13
  if reverse then partial, full = 0x23, 0x2B end
  local dest = self:R16(0xBC, p + 2) - 0x8000
  local va, ma = self:R16(0xBC, p + 4), self:R16(0xBC, p + 6)
  local len = self:R(0xBC, p + 8)
  local val, max = M[va] + M[va + 1] * 256, M[ma] + M[ma + 1] * 256
  if val == 0 then return end
  local c
  if max <= val then
    c = len
  else
    local de = floor(max / len) + 1
    c = (floor(val / de) + 1) % 256
  end
  local step = reverse and -1 or 1
  while c >= 8 do
    c = c - 8
    self:slow()
    self:vwrite(0, dest, full)
    dest = dest + step
  end
  if c > 0 then self:slow(); self:vwrite(0, dest, partial + c) end
end

-- $08:$4BEC: barra de HP desce 30 por quadro do HP mostrado (+$46) até o atual (+$0E).
function Attack:hpBars()
  local M = self.M
  local a, b = 0xC900, 0xC980
  if M[0xC008] ~= 0 then a, b = 0xC980, 0xC900 end
  local units = { { a, 0x9DCB, 0x54BE }, { b, 0x9DC2, 0x54E8 } }
  for _, u in ipairs(units) do
    local real, shown = self:r16(u[1] + 0x0E), self:r16(u[1] + 0x46)
    local l = shown
    while true do
      l = (l - 0x1E) % 65536
      if cmpS(l, real) ~= 2 then break end
      self:waitFrame()
      for i = 0, 6 do self:slow(); self:vwrite(0, u[2] - 0x8000 + i, 0x0C) end
      self:runBG(u[3])
    end
    for i = 0, 6 do self:slow(); self:vwrite(0, u[2] - 0x8000 + i, 0x0C) end
    self:runBG(u[3])
  end
  self:w16(0xC946, self:r16(0xC90E))
  self:w16(0xC9C6, self:r16(0xC98E))
  M[0xC034] = 0x14
  self:waitN()
end

-- $09:$66AA: alguém ficou sem HP -> animação $12 por 200 quadros e fim da cena.
function Attack:faint()
  local M = self.M
  M[0xC066] = 0
  if self:r16(0xC90E) ~= 0 and self:r16(0xC98E) ~= 0 then return end
  M[0xC066] = 1
  M[0xC034] = 0xC8
  local slot = M[0xDB00] ~= 0 and 0xDB10 or 0xDB50
  repeat
    M[slot] = 0x12
    self:waitFrame()
    self:updateObjects()
    self:buildOAM()
    M[0xC034] = M[0xC034] - 1
  until M[0xC034] == 0
end

-- $01:$64AB: música da cena pela espécie ($01:$64DF)
function Attack:music()
  local M = self.M
  local a = M[0xC905]
  if not (a == 0x15 or a == 0x38) then
    local e = M[0xC985]
    if e == 0x15 or e == 0x38 or e < 0x15 then a = e end
  end
  self.musicId = self:R(0x01, 0x64DF + a)
  if self.onMusic then self.onMusic(self.musicId) end
end

-- ---------------------------------------------------------------------------------------------
-- Fluxo

function Attack:phase(o0, a0, o1, a1)
  local M = self.M
  M[0xDB0F] = M[o0]; M[0xDB10] = a0
  M[0xDB4F] = M[o1]; M[0xDB50] = a1
  self:setupObjects()
end

-- $09:$62EC: aliado (objeto 1, direita) ataca; contra do inimigo (objeto 0)
function Attack:applyAlly()
  local M = self.M
  self:music()
  M[0xC154] = 1; M[0xC255] = 0
  self:phase(0xC1D3, 0, 0xC1D0, M[0xC1D1])
  self:waitVBlank()                                   -- $2B41 (espera o VBlank para ligar o LCD)
  M[0xC36A] = 2; M[0xC36C] = 0x90
  self:sceneLoop()
  self:clearEffects()
  M[0xC034] = 0x14; self:waitN()
  M[0xC36A] = 2; M[0xC36C] = 0
  self:phase(0xC1D3, M[0xC1D5], 0xC1D0, (M[0xC1D1] + 1) % 256)
  M[0xC439] = 1
  self:sceneLoop()
  self:applyDamage(0xC1D5, 0xC980, 0xCD43)
  M[0xC154] = 2
  self:hpBars()
  self:clearEffects()
  M[0xC439] = 0
  self:faint()
  M[0xC154] = 0
  if M[0xC066] ~= 0 then return end
  self:music()
  if M[0xC1D4] ~= 1 then
    M[0xC154] = 3; M[0xC255] = 0
    M[0xC36A] = 2; M[0xC36C] = 0
    self:phase(0xC1D3, M[0xC1D4], 0xC1D0, 0)
    M[0xDB03] = 0x20
    self:sceneLoop()
    self:clearEffects()
    M[0xC034] = 0x14; self:waitN()
    M[0xC36A] = 2; M[0xC36C] = 0x90
    self:phase(0xC1D3, (M[0xC1D4] + 1) % 256, 0xC1D0, M[0xC1D2])
    M[0xC439] = 2
    self:sceneLoop()
    self:applyDamage(0xC1D2, 0xC900, 0xCD03)
    M[0xC154] = 4
    self:hpBars()
    self:clearEffects()
    self:faint()
    M[0xC154] = 0
  end
  M[0xC034] = 0x14; self:waitN()
end

-- $09:$64C7: inimigo (objeto 0, esquerda) ataca; contra do aliado (objeto 1)
function Attack:applyEnemy()
  local M = self.M
  self:music()
  M[0xC154] = 3; M[0xC255] = 0
  M[0xC36A] = 2; M[0xC36C] = 0
  self:phase(0xC1D3, M[0xC1D4], 0xC1D0, 0)
  self:waitVBlank()                                   -- $2B41
  self.lcdc = 0x8F
  self:vblank()                                       -- IF = 3 pede outro VBlank na hora
  M[0xDB03] = 0x20
  self:sceneLoop()
  self:clearEffects()
  M[0xC034] = 0x14; self:waitN()
  M[0xC36A] = 2; M[0xC36C] = 0x90
  self:phase(0xC1D3, (M[0xC1D4] + 1) % 256, 0xC1D0, M[0xC1D2])
  M[0xC439] = 2
  self:sceneLoop()
  self:applyDamage(0xC1D2, 0xC900, 0xCD03)
  M[0xC154] = 4
  self:hpBars()
  self:clearEffects()
  M[0xC439] = 0
  self:faint()
  M[0xC154] = 0
  if M[0xC066] ~= 0 then return end
  self:music()
  M[0xC154] = 1
  if M[0xC1D1] ~= 1 then
    M[0xC255] = 0
    self:phase(0xC1D3, 0, 0xC1D0, M[0xC1D1])
    M[0xC36A] = 2; M[0xC36C] = 0x90
    self:sceneLoop()
    self:clearEffects()
    M[0xC034] = 0x14; self:waitN()
    M[0xC36A] = 2; M[0xC36C] = 0
    self:phase(0xC1D3, M[0xC1D5], 0xC1D0, (M[0xC1D1] + 1) % 256)
    M[0xC439] = 1
    self:sceneLoop()
    self:applyDamage(0xC1D5, 0xC980, 0xCD43)
    M[0xC154] = 2
    self:hpBars()
    self:clearEffects()
    M[0xC439] = 0
    self:faint()
    M[0xC154] = 0
  end
  M[0xC034] = 0x14; self:waitN()
end

-- $00:$2CEB: carrega o cenário [$C080] (scripts $BC:$4000)
function Attack:loadScene()
  local M = self.M
  self:waitFrame()
  M[0xC244] = 0
  for slot = 0, 7 do M[0xDB00 + slot * 0x40] = 0 end    -- $307D
  self:updateObjects()
  self:buildOAM()
  self:waitFrame()
  M[0xC244] = 1
  self:runBG(self:R16(0xBC, 0x4000 + M[0xC080] * 2))
end

function Attack:flow()
  local M = self.M
  -- $01:$63B9
  M[0xC350] = 1
  M[0xC1CA] = 3
  M[0xC1D7] = (self:R(0x38, 0x7139 + M[0xC220]) + 0x2F) % 256      -- $38:$7124
  M[0xC1CB] = 0
  M[0xC080] = M[0xC1D7]; M[0xC081] = M[0xC1D7]
  self:loadScene()
  M[0xC490] = 0
  M[0xC036] = M[0xC035]
  if M[0xC008] ~= 0 then self:applyEnemy() else self:applyAlly() end
  -- fim ($09:$646C): objetos apagados
  for a = 0xDB00, 0xDDFF do M[a] = 0 end
  M[0xC439] = 0; M[0xC154] = 0
end

-- ---------------------------------------------------------------------------------------------
-- Entradas

-- Animação de ação do golpe para a espécie: $09:$6F4D[espécie] -> 4 pares [golpe, anim];
-- sem par igual vale o último ($09:$6EAD).
function Attack.skillAnim(rom, species, skill)
  local list = rom:u8(0x09, 0x6F4D + species * 2) + rom:u8(0x09, 0x6F4D + species * 2 + 1) * 256
  for i = 0, 2 do
    if rom:u8(0x09, list + i * 2) == skill then return rom:u8(0x09, list + i * 2 + 1) end
  end
  return rom:u8(0x09, list + 7)
end

local function writeUnit(self, base, u)
  local M = self.M
  for i = 0, 0x7F do M[base + i] = 0 end
  M[base] = 1
  M[base + 2] = u.level or 1
  M[base + 5] = u.species
  M[base + 6] = u.type or 1
  self:w16(base + 12, u.sp or 0)
  self:w16(base + 14, u.hp or 0)
  self:w16(base + 16, u.maxsp or 0)
  self:w16(base + 18, u.maxhp or 0)
  self:w16(base + 0x46, u.hp or 0)
end

-- ev = { att, def (unidades antes do golpe), skill = id|nil, hit, dmg,
--        counter = nil | { skill = id|nil, hit, dmg }, enemyTurn = bool, terrain = n }
-- rom: leitor com rom:u8(banco, endereço).
-- O registro $C900 é sempre o do aliado e $C980 o do inimigo ($01:$4368 / $01:$6B0E); C1D1/C1D2/
-- CD03 são a ação e o resultado do aliado, C1D4/C1D5/CD43 os do inimigo.
function Attack.new(rom, ev)
  local self = setmetatable(newState(rom), Attack)
  local M = self.M
  local ally, enemy = ev.att, ev.def
  local allyAct, enemyAct = ev.skill, ev.counter and ev.counter.skill
  local allyHit, enemyHit = ev.counter, ev                    -- quem acerta o aliado / o inimigo
  if ev.enemyTurn then
    ally, enemy = ev.def, ev.att
    allyAct, enemyAct = ev.counter and ev.counter.skill, ev.skill
    allyHit, enemyHit = ev, ev.counter
  end
  writeUnit(self, 0xC900, ally)
  writeUnit(self, 0xC980, enemy)
  M[0xC008] = ev.enemyTurn and 1 or 0
  M[0xC1D0] = 0x7C + ally.species
  M[0xC1D3] = 0x7C + enemy.species
  local hasAlly = (not ev.enemyTurn) or ev.counter
  local hasEnemy = ev.enemyTurn or ev.counter
  M[0xC1D1] = hasAlly and (allyAct and Attack.skillAnim(rom, ally.species, allyAct) or 2) or 1
  M[0xC1D4] = hasEnemy and (enemyAct and Attack.skillAnim(rom, enemy.species, enemyAct) or 2) or 1
  -- resultado contra o aliado (C1D2/CD03) e contra o inimigo (C1D5/CD43)
  M[0xC1D2] = (allyHit and allyHit.hit) and 0x0C or 0x10
  self:w16(0xCD03, (allyHit and allyHit.hit) and allyHit.dmg or 0)
  M[0xC1D5] = (enemyHit and enemyHit.hit) and 0x0C or 0x10
  self:w16(0xCD43, (enemyHit and enemyHit.hit) and enemyHit.dmg or 0)
  M[0xC220] = ev.terrain or 0
  M[0xC035] = ev.random or 50
  self.co = coroutine.create(function() self:flow() end)
  self.done = false
  self.frames = 0
  return self
end

-- Avança um quadro (60 por segundo). Devolve false quando a cena acabou.
function Attack:advance()
  local ok, err = coroutine.resume(self.co)
  if not ok then error(err, 0) end
  if coroutine.status(self.co) == "dead" then self.done = true end
  return not self.done
end

function Attack:step()
  if self.done then return false end
  if not self:advance() then return false end
  self:vblank()
  self.frames = self.frames + 1
  return true
end

return Attack
