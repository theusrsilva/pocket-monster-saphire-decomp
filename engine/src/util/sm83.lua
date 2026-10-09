-- Interpretador da CPU do Game Boy (SM83), usado só no importador para executar o driver de som
-- original da ROM do jogador e capturar o que ele escreve nos registradores de áudio.
-- Não emula vídeo, interrupções nem temporização fina: roda rotinas até elas retornarem.
local bit = require("bit")
local band, bor, bxor, lshift, rshift = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift

local CPU = {}
CPU.__index = CPU

-- read(addr) -> byte, write(addr, byte)
function CPU.new(read, write)
  return setmetatable({
    a = 0, f = 0, b = 0, c = 0, d = 0, e = 0, h = 0, l = 0, sp = 0xDFFF, pc = 0,
    read = read, write = write, steps = 0, ime = false,
  }, CPU)
end

-- flags: Z=0x80 N=0x40 H=0x20 C=0x10
local function setf(cpu, z, n, h, c)
  cpu.f = (z and 0x80 or 0) + (n and 0x40 or 0) + (h and 0x20 or 0) + (c and 0x10 or 0)
end

local function fetch(cpu)
  local v = cpu.read(cpu.pc)
  cpu.pc = band(cpu.pc + 1, 0xFFFF)
  return v
end

local function fetch16(cpu)
  local lo = fetch(cpu)
  return lo + fetch(cpu) * 256
end

local function push(cpu, v)
  cpu.sp = band(cpu.sp - 1, 0xFFFF); cpu.write(cpu.sp, rshift(v, 8))
  cpu.sp = band(cpu.sp - 1, 0xFFFF); cpu.write(cpu.sp, band(v, 0xFF))
end

local function pop(cpu)
  local lo = cpu.read(cpu.sp); cpu.sp = band(cpu.sp + 1, 0xFFFF)
  local hi = cpu.read(cpu.sp); cpu.sp = band(cpu.sp + 1, 0xFFFF)
  return lo + hi * 256
end

-- registradores de 8 bits por índice (b c d e h l (hl) a)
local R8 = { "b", "c", "d", "e", "h", "l", nil, "a" }

local function get8(cpu, i)
  if i == 6 then return cpu.read(cpu.h * 256 + cpu.l) end
  return cpu[R8[i + 1]]
end

local function set8(cpu, i, v)
  if i == 6 then cpu.write(cpu.h * 256 + cpu.l, v) else cpu[R8[i + 1]] = v end
end

local function getRR(cpu, i) -- bc de hl sp
  if i == 0 then return cpu.b * 256 + cpu.c
  elseif i == 1 then return cpu.d * 256 + cpu.e
  elseif i == 2 then return cpu.h * 256 + cpu.l end
  return cpu.sp
end

local function setRR(cpu, i, v)
  v = band(v, 0xFFFF)
  if i == 0 then cpu.b, cpu.c = rshift(v, 8), band(v, 0xFF)
  elseif i == 1 then cpu.d, cpu.e = rshift(v, 8), band(v, 0xFF)
  elseif i == 2 then cpu.h, cpu.l = rshift(v, 8), band(v, 0xFF)
  else cpu.sp = v end
end

local function cond(cpu, i) -- nz z nc c
  if i == 0 then return band(cpu.f, 0x80) == 0
  elseif i == 1 then return band(cpu.f, 0x80) ~= 0
  elseif i == 2 then return band(cpu.f, 0x10) == 0 end
  return band(cpu.f, 0x10) ~= 0
end

local function alu(cpu, op, v)
  local a = cpu.a
  local cy = band(cpu.f, 0x10) ~= 0 and 1 or 0
  if op == 0 then -- add
    local r = a + v
    setf(cpu, band(r, 0xFF) == 0, false, band(a, 0xF) + band(v, 0xF) > 0xF, r > 0xFF)
    cpu.a = band(r, 0xFF)
  elseif op == 1 then -- adc
    local r = a + v + cy
    setf(cpu, band(r, 0xFF) == 0, false, band(a, 0xF) + band(v, 0xF) + cy > 0xF, r > 0xFF)
    cpu.a = band(r, 0xFF)
  elseif op == 2 then -- sub
    local r = a - v
    setf(cpu, band(r, 0xFF) == 0, true, band(a, 0xF) < band(v, 0xF), r < 0)
    cpu.a = band(r, 0xFF)
  elseif op == 3 then -- sbc
    local r = a - v - cy
    setf(cpu, band(r, 0xFF) == 0, true, band(a, 0xF) - band(v, 0xF) - cy < 0, r < 0)
    cpu.a = band(r, 0xFF)
  elseif op == 4 then -- and
    cpu.a = band(a, v); setf(cpu, cpu.a == 0, false, true, false)
  elseif op == 5 then -- xor
    cpu.a = bxor(a, v); setf(cpu, cpu.a == 0, false, false, false)
  elseif op == 6 then -- or
    cpu.a = bor(a, v); setf(cpu, cpu.a == 0, false, false, false)
  else -- cp
    local r = a - v
    setf(cpu, band(r, 0xFF) == 0, true, band(a, 0xF) < band(v, 0xF), r < 0)
  end
end

local function cbop(cpu)
  local op = fetch(cpu)
  local i = band(op, 7)
  local v = get8(cpu, i)
  local grp = rshift(op, 6)
  local y = band(rshift(op, 3), 7)
  if grp == 0 then
    local cy = band(cpu.f, 0x10) ~= 0 and 1 or 0
    local r, c
    if y == 0 then c = rshift(v, 7); r = band(lshift(v, 1), 0xFF) + c          -- rlc
    elseif y == 1 then c = band(v, 1); r = rshift(v, 1) + c * 128               -- rrc
    elseif y == 2 then c = rshift(v, 7); r = band(lshift(v, 1), 0xFF) + cy      -- rl
    elseif y == 3 then c = band(v, 1); r = rshift(v, 1) + cy * 128              -- rr
    elseif y == 4 then c = rshift(v, 7); r = band(lshift(v, 1), 0xFF)           -- sla
    elseif y == 5 then c = band(v, 1); r = rshift(v, 1) + band(v, 0x80)         -- sra
    elseif y == 6 then c = 0; r = band(lshift(v, 4), 0xF0) + rshift(v, 4)       -- swap
    else c = band(v, 1); r = rshift(v, 1) end                                    -- srl
    setf(cpu, r == 0, false, false, c == 1)
    set8(cpu, i, r)
  elseif grp == 1 then -- bit
    cpu.f = band(cpu.f, 0x10) + 0x20 + (band(v, lshift(1, y)) == 0 and 0x80 or 0)
  elseif grp == 2 then -- res
    set8(cpu, i, band(v, bxor(0xFF, lshift(1, y))))
  else -- set
    set8(cpu, i, bor(v, lshift(1, y)))
  end
end

local function s8(v) return v >= 128 and v - 256 or v end

-- Executa uma instrução.
function CPU:step()
  self.steps = self.steps + 1
  local op = fetch(self)
  if op >= 0x40 and op < 0x80 then -- ld r, r'
    if op == 0x76 then return "halt" end
    set8(self, band(rshift(op, 3), 7), get8(self, band(op, 7)))
    return
  end
  if op >= 0x80 and op < 0xC0 then
    alu(self, band(rshift(op, 3), 7), get8(self, band(op, 7)))
    return
  end
  local x, y, z = rshift(op, 6), band(rshift(op, 3), 7), band(op, 7)
  if x == 0 then
    if z == 0 then
      if y == 0 then return end -- nop
      if y == 1 then -- ld [nn], sp
        local a = fetch16(self)
        self.write(a, band(self.sp, 0xFF)); self.write(band(a + 1, 0xFFFF), rshift(self.sp, 8))
      elseif y == 2 then fetch(self) -- stop
      elseif y == 3 then local d = s8(fetch(self)); self.pc = band(self.pc + d, 0xFFFF)
      else local d = s8(fetch(self)); if cond(self, y - 4) then self.pc = band(self.pc + d, 0xFFFF) end end
    elseif z == 1 then
      local p, q = rshift(y, 1), band(y, 1)
      if q == 0 then setRR(self, p, fetch16(self))
      else -- add hl, rr
        local hl, v = getRR(self, 2), getRR(self, p)
        local r = hl + v
        self.f = band(self.f, 0x80) + (band(hl, 0xFFF) + band(v, 0xFFF) > 0xFFF and 0x20 or 0) + (r > 0xFFFF and 0x10 or 0)
        setRR(self, 2, r)
      end
    elseif z == 2 then
      local p, q = rshift(y, 1), band(y, 1)
      local addr
      if p == 0 then addr = getRR(self, 0) elseif p == 1 then addr = getRR(self, 1) else addr = getRR(self, 2) end
      if q == 0 then self.write(addr, self.a) else self.a = self.read(addr) end
      if p == 2 then setRR(self, 2, addr + 1) elseif p == 3 then setRR(self, 2, addr - 1) end
    elseif z == 3 then
      local p, q = rshift(y, 1), band(y, 1)
      setRR(self, p, getRR(self, p) + (q == 0 and 1 or -1))
    elseif z == 4 then -- inc r
      local v = get8(self, y)
      local r = band(v + 1, 0xFF)
      self.f = band(self.f, 0x10) + (r == 0 and 0x80 or 0) + (band(v, 0xF) == 0xF and 0x20 or 0)
      set8(self, y, r)
    elseif z == 5 then -- dec r
      local v = get8(self, y)
      local r = band(v - 1, 0xFF)
      self.f = band(self.f, 0x10) + 0x40 + (r == 0 and 0x80 or 0) + (band(v, 0xF) == 0 and 0x20 or 0)
      set8(self, y, r)
    elseif z == 6 then set8(self, y, fetch(self))
    else
      local a, cy = self.a, band(self.f, 0x10) ~= 0 and 1 or 0
      if y == 0 then local c = rshift(a, 7); self.a = band(lshift(a, 1), 0xFF) + c; setf(self, false, false, false, c == 1)
      elseif y == 1 then local c = band(a, 1); self.a = rshift(a, 1) + c * 128; setf(self, false, false, false, c == 1)
      elseif y == 2 then local c = rshift(a, 7); self.a = band(lshift(a, 1), 0xFF) + cy; setf(self, false, false, false, c == 1)
      elseif y == 3 then local c = band(a, 1); self.a = rshift(a, 1) + cy * 128; setf(self, false, false, false, c == 1)
      elseif y == 4 then -- daa
        local n, h = band(self.f, 0x40) ~= 0, band(self.f, 0x20) ~= 0
        local c = cy == 1
        if not n then
          if c or a > 0x99 then a = a + 0x60; c = true end
          if h or band(a, 0x0F) > 0x09 then a = a + 0x06 end
        else
          if c then a = a - 0x60 end
          if h then a = a - 0x06 end
        end
        a = band(a, 0xFF)
        self.a = a
        self.f = (a == 0 and 0x80 or 0) + (n and 0x40 or 0) + (c and 0x10 or 0)
      elseif y == 5 then self.a = bxor(a, 0xFF); self.f = bor(self.f, 0x60)
      elseif y == 6 then self.f = band(self.f, 0x80) + 0x10
      else self.f = band(self.f, 0x80) + (cy == 1 and 0 or 0x10) end
    end
    return
  end
  -- x == 3
  if z == 0 then
    if y < 4 then if cond(self, y) then self.pc = pop(self) end
    elseif y == 4 then self.write(0xFF00 + fetch(self), self.a)
    elseif y == 5 then -- add sp, d
      local d = s8(fetch(self)); local sp = self.sp
      setf(self, false, false, band(sp, 0xF) + band(d, 0xF) > 0xF, band(sp, 0xFF) + band(d, 0xFF) > 0xFF)
      self.sp = band(sp + d, 0xFFFF)
    elseif y == 6 then self.a = self.read(0xFF00 + fetch(self))
    else -- ld hl, sp+d
      local d = s8(fetch(self)); local sp = self.sp
      setf(self, false, false, band(sp, 0xF) + band(d, 0xF) > 0xF, band(sp, 0xFF) + band(d, 0xFF) > 0xFF)
      setRR(self, 2, sp + d)
    end
  elseif z == 1 then
    local p, q = rshift(y, 1), band(y, 1)
    if q == 0 then
      local v = pop(self)
      if p == 3 then self.a, self.f = rshift(v, 8), band(v, 0xF0) else setRR(self, p, v) end
    elseif p == 0 then self.pc = pop(self)
    elseif p == 1 then self.pc = pop(self); self.ime = true
    elseif p == 2 then self.pc = getRR(self, 2)
    else self.sp = getRR(self, 2) end
  elseif z == 2 then
    if y < 4 then local a = fetch16(self); if cond(self, y) then self.pc = a end
    elseif y == 4 then self.write(0xFF00 + self.c, self.a)
    elseif y == 5 then self.write(fetch16(self), self.a)
    elseif y == 6 then self.a = self.read(0xFF00 + self.c)
    else self.a = self.read(fetch16(self)) end
  elseif z == 3 then
    if y == 0 then self.pc = fetch16(self)
    elseif y == 1 then cbop(self)
    elseif y == 6 then self.ime = false
    elseif y == 7 then self.ime = true
    else error(("opcode inválido %02X em %04X"):format(op, band(self.pc - 1, 0xFFFF))) end
  elseif z == 4 then
    local a = fetch16(self)
    if y < 4 and cond(self, y) then push(self, self.pc); self.pc = a
    elseif y >= 4 then error(("opcode inválido %02X em %04X"):format(op, band(self.pc - 1, 0xFFFF))) end
  elseif z == 5 then
    local p, q = rshift(y, 1), band(y, 1)
    if q == 0 then
      if p == 3 then push(self, self.a * 256 + self.f) else push(self, getRR(self, p)) end
    elseif p == 0 then local a = fetch16(self); push(self, self.pc); self.pc = a
    else error(("opcode inválido %02X em %04X"):format(op, band(self.pc - 1, 0xFFFF))) end
  elseif z == 6 then alu(self, y, fetch(self))
  else push(self, self.pc); self.pc = y * 8 end -- rst
end

-- Chama a rotina em addr e roda até ela retornar (ou estourar o limite de instruções).
function CPU:call(addr, limit)
  local sentinel = 0xFFFE
  push(self, sentinel)
  self.pc = addr
  local n = 0
  limit = limit or 200000
  while self.pc ~= sentinel do
    if self:step() == "halt" then break end
    n = n + 1
    if n > limit then return false end
  end
  return true
end

CPU.push, CPU.pop = push, pop
return CPU
