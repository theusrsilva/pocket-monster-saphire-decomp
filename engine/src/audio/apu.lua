-- Síntese do áudio do Game Boy (APU) a partir das escritas nos registradores $FF10-$FF3F.
-- Usado pelo importador: o driver de som original roda no interpretador SM83 e cada quadro de
-- escritas vira amostras PCM aqui. Implementa os 4 canais (2 pulsos com envelope e sweep, onda,
-- ruído), o sequenciador de quadros (comprimento 256 Hz, sweep 128 Hz, envelope 64 Hz) e NR50/NR51.
local bit = require("bit")
local band, bor, rshift, lshift, bxor = bit.band, bit.bor, bit.rshift, bit.lshift, bit.bxor

local APU = {}
APU.__index = APU

local CLOCK = 4194304
local DUTY = {
  [0] = { 0, 0, 0, 0, 0, 0, 0, 1 },
  [1] = { 1, 0, 0, 0, 0, 0, 0, 1 },
  [2] = { 1, 0, 0, 0, 0, 1, 1, 1 },
  [3] = { 0, 1, 1, 1, 1, 1, 1, 0 },
}
local NOISE_DIV = { [0] = 8, 16, 32, 48, 64, 80, 96, 112 }

function APU.new(rate)
  local self = setmetatable({ rate = rate or 22050, reg = {}, wave = {}, seqClock = 0, seqStep = 0 }, APU)
  for a = 0xFF10, 0xFF3F do self.reg[a] = 0 end
  for i = 0, 31 do self.wave[i] = 0 end
  self.ch = {}
  for i = 1, 4 do
    self.ch[i] = { on = false, phase = 0, vol = 0, envDir = 0, envPer = 0, envTimer = 0, len = 0, lenOn = false,
      freq = 0, duty = 2, lfsr = 0x7FFF, dac = false }
  end
  self.ch[1].sweepTimer, self.ch[1].sweepOn, self.ch[1].shadow = 0, false, 0
  self.power = true
  return self
end

local function freqOf(self, n)
  local lo = self.reg[0xFF13 + (n - 1) * 5]
  local hi = self.reg[0xFF14 + (n - 1) * 5]
  return lo + band(hi, 7) * 256
end

local function trigger(self, n)
  local c = self.ch[n]
  local base = 0xFF10 + (n - 1) * 5
  c.on = true
  c.lenOn = band(self.reg[base + 4], 0x40) ~= 0
  if n == 3 then
    if c.len == 0 then c.len = 256 end
    c.phase = 0
    c.dac = band(self.reg[0xFF1A], 0x80) ~= 0
  else
    if c.len == 0 then c.len = 64 end
    local env = self.reg[base + 2]
    c.vol = rshift(env, 4)
    c.envDir = band(env, 8) ~= 0 and 1 or -1
    c.envPer = band(env, 7)
    c.envTimer = c.envPer
    c.dac = band(env, 0xF8) ~= 0
    if n == 4 then c.lfsr = 0x7FFF end
  end
  if n == 1 then
    local sw = self.reg[0xFF10]
    c.shadow = freqOf(self, 1)
    c.sweepPer = band(rshift(sw, 4), 7)
    c.sweepTimer = c.sweepPer > 0 and c.sweepPer or 8
    c.sweepOn = c.sweepPer > 0 or band(sw, 7) > 0
  end
  if not c.dac then c.on = false end
end

-- Escrita num registrador de áudio.
function APU:write(addr, v)
  if addr >= 0xFF30 and addr <= 0xFF3F then
    local i = (addr - 0xFF30) * 2
    self.wave[i], self.wave[i + 1] = rshift(v, 4), band(v, 15)
    return
  end
  self.reg[addr] = v
  if addr == 0xFF26 then
    self.power = band(v, 0x80) ~= 0
    if not self.power then for i = 1, 4 do self.ch[i].on = false end end
    return
  end
  local n
  if addr >= 0xFF10 and addr <= 0xFF14 then n = 1
  elseif addr >= 0xFF16 and addr <= 0xFF19 then n = 2
  elseif addr >= 0xFF1A and addr <= 0xFF1E then n = 3
  elseif addr >= 0xFF20 and addr <= 0xFF23 then n = 4 end
  if not n then return end
  local base = 0xFF10 + (n - 1) * 5
  local r = addr - base
  local c = self.ch[n]
  if n == 3 and r == 0 then
    c.dac = band(v, 0x80) ~= 0
    if not c.dac then c.on = false end
  elseif r == 1 then
    if n == 3 then c.len = 256 - v else c.len = 64 - band(v, 63); c.duty = rshift(v, 6) end
  elseif r == 2 and n ~= 3 then
    c.dac = band(v, 0xF8) ~= 0
    if not c.dac then c.on = false end
  elseif r == 4 then
    c.lenOn = band(v, 0x40) ~= 0
    if band(v, 0x80) ~= 0 then trigger(self, n) end
  end
end

-- Passo do sequenciador de quadros (512 Hz).
local function sequencer(self)
  local step = self.seqStep
  self.seqStep = (step + 1) % 8
  if step % 2 == 0 then -- comprimento
    for i = 1, 4 do
      local c = self.ch[i]
      if c.lenOn and c.len > 0 then
        c.len = c.len - 1
        if c.len == 0 then c.on = false end
      end
    end
  end
  if step == 2 or step == 6 then -- sweep
    local c = self.ch[1]
    if c.sweepOn then
      c.sweepTimer = c.sweepTimer - 1
      if c.sweepTimer <= 0 then
        local sw = self.reg[0xFF10]
        local per = band(rshift(sw, 4), 7)
        c.sweepTimer = per > 0 and per or 8
        if per > 0 then
          local shift = band(sw, 7)
          local delta = rshift(c.shadow, shift)
          local nf = band(sw, 8) ~= 0 and c.shadow - delta or c.shadow + delta
          if nf > 2047 then c.on = false
          elseif shift > 0 then
            c.shadow = nf
            self.reg[0xFF13] = band(nf, 0xFF)
            self.reg[0xFF14] = band(self.reg[0xFF14], 0xF8) + rshift(nf, 8)
          end
        end
      end
    end
  end
  if step == 7 then -- envelope
    for _, i in ipairs({ 1, 2, 4 }) do
      local c = self.ch[i]
      if c.envPer > 0 then
        c.envTimer = c.envTimer - 1
        if c.envTimer <= 0 then
          c.envTimer = c.envPer
          local nv = c.vol + c.envDir
          if nv >= 0 and nv <= 15 then c.vol = nv end
        end
      end
    end
  end
end

-- Gera n amostras estéreo (valores -1..1) e as acrescenta em outL/outR (a partir de outL.n ou #outL).
function APU:render(n, outL, outR)
  local rate = self.rate
  local seqPer = CLOCK / 512
  local cyclesPerSample = CLOCK / rate
  local ch1, ch2, ch3, ch4 = self.ch[1], self.ch[2], self.ch[3], self.ch[4]
  local reg, wave = self.reg, self.wave
  local k = #outL
  for _ = 1, n do
    self.seqClock = self.seqClock + cyclesPerSample
    while self.seqClock >= seqPer do
      self.seqClock = self.seqClock - seqPer
      sequencer(self)
    end
    local s1, s2, s3, s4 = 0, 0, 0, 0
    if self.power then
      -- pulsos: período = (2048 - f) * 4 ciclos por passo de 1/8
      if ch1.on then
        local f = ch1.sweepOn and ch1.shadow or (reg[0xFF13] + band(reg[0xFF14], 7) * 256)
        ch1.phase = (ch1.phase + CLOCK / ((2048 - f) * 32) / rate) % 1
        if DUTY[ch1.duty][math.floor(ch1.phase * 8) + 1] == 1 then s1 = ch1.vol / 15 end
      end
      if ch2.on then
        local f = reg[0xFF18] + band(reg[0xFF19], 7) * 256
        ch2.phase = (ch2.phase + CLOCK / ((2048 - f) * 32) / rate) % 1
        if DUTY[ch2.duty][math.floor(ch2.phase * 8) + 1] == 1 then s2 = ch2.vol / 15 end
      end
      if ch3.on and ch3.dac then
        local f = reg[0xFF1D] + band(reg[0xFF1E], 7) * 256
        ch3.phase = (ch3.phase + CLOCK / ((2048 - f) * 64) / rate) % 1
        local smp = wave[math.floor(ch3.phase * 32)]
        local code = band(rshift(reg[0xFF1C], 5), 3)
        if code == 0 then smp = 0 elseif code == 2 then smp = rshift(smp, 1) elseif code == 3 then smp = rshift(smp, 2) end
        s3 = smp / 15
      end
      if ch4.on then
        local nr43 = reg[0xFF22]
        local shift = rshift(nr43, 4)
        if shift < 14 then
          ch4.phase = ch4.phase + CLOCK / (NOISE_DIV[band(nr43, 7)] * lshift(1, shift)) / rate
          while ch4.phase >= 1 do
            ch4.phase = ch4.phase - 1
            local x = bxor(band(ch4.lfsr, 1), band(rshift(ch4.lfsr, 1), 1))
            ch4.lfsr = bor(rshift(ch4.lfsr, 1), lshift(x, 14))
            if band(nr43, 8) ~= 0 then ch4.lfsr = bor(band(ch4.lfsr, 0x7FBF), lshift(x, 6)) end
          end
          if band(ch4.lfsr, 1) == 0 then s4 = ch4.vol / 15 end
        end
      end
    end
    local nr50, nr51 = reg[0xFF24], reg[0xFF25]
    local l = (band(nr51, 0x10) ~= 0 and s1 or 0) + (band(nr51, 0x20) ~= 0 and s2 or 0)
      + (band(nr51, 0x40) ~= 0 and s3 or 0) + (band(nr51, 0x80) ~= 0 and s4 or 0)
    local r = (band(nr51, 0x01) ~= 0 and s1 or 0) + (band(nr51, 0x02) ~= 0 and s2 or 0)
      + (band(nr51, 0x04) ~= 0 and s3 or 0) + (band(nr51, 0x08) ~= 0 and s4 or 0)
    k = k + 1
    outL[k] = l * (band(rshift(nr50, 4), 7) + 1) / 32
    outR[k] = r * (band(nr50, 7) + 1) / 32
  end
end

return APU
