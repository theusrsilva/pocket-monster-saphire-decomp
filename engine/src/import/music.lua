-- Músicas e efeitos: executa o driver de som original (banco $2C) num interpretador SM83 e
-- sintetiza o que ele escreve no APU. Nada de áudio vem com o motor; tudo sai da ROM do jogador.
--   inicialização  $2C:$4000
--   atualização    $00:$2CE2 (troca para o banco $2C e chama $406C), uma vez por quadro (VBlank)
--   tocar música   [$FFF7] = número (< $20); comandos >= $20; efeito sonoro em [$FFF8]
local CPU = require("src.util.sm83")
local APU = require("src.audio.apu")

local Music = {}
Music.FPS = 4194304 / 70224          -- quadros por segundo do Game Boy (~59,73)

-- Máquina mínima: ROM com troca de banco (MBC5), RAM em tabela e APU.
function Music.machine(rom, rate)
  local mem = {}
  for a = 0x8000, 0xFFFF do mem[a] = 0 end
  local m = { bank = 1, mem = mem, apu = APU.new(rate), writes = 0 }
  local apu = m.apu
  local function read(a)
    if a < 0x4000 then return rom:u8(a) end
    if a < 0x8000 then return rom:u8(m.bank * 0x4000 + a - 0x4000) end
    return mem[a]
  end
  local function write(a, v)
    if a < 0x8000 then
      if a >= 0x2000 and a < 0x3000 then m.bank = v end
      return
    end
    mem[a] = v
    if a >= 0xFF10 and a <= 0xFF3F then
      apu:write(a, v)
      m.writes = m.writes + 1
    end
  end
  m.cpu = CPU.new(read, write)
  m.cpu.sp = 0xCFFF
  m.bank = 0x2C
  assert(m.cpu:call(0x4000), "driver de som: inicialização não retornou")
  return m
end

-- Um quadro: o VBlank chama $2CE2.
function Music.frame(m)
  m.cpu.sp = 0xCFFF
  return m.cpu:call(0x2CE2, 100000)
end

-- Grava WAV PCM 16 bits estéreo.
function Music.wav(L, R, rate)
  local n = #L
  local parts = {}
  local function u32(v) return string.char(v % 256, math.floor(v / 256) % 256, math.floor(v / 65536) % 256, math.floor(v / 16777216) % 256) end
  local function u16(v) return string.char(v % 256, math.floor(v / 256) % 256) end
  parts[1] = "RIFF" .. u32(36 + n * 4) .. "WAVEfmt " .. u32(16) .. u16(1) .. u16(2) .. u32(rate) .. u32(rate * 4) .. u16(4) .. u16(16)
    .. "data" .. u32(n * 4)
  local buf = {}
  for i = 1, n do
    local l = math.max(-32767, math.min(32767, math.floor(L[i] * 32767)))
    local r = math.max(-32767, math.min(32767, math.floor(R[i] * 32767)))
    if l < 0 then l = l + 65536 end
    if r < 0 then r = r + 65536 end
    buf[#buf + 1] = string.char(l % 256, math.floor(l / 256), r % 256, math.floor(r / 256))
    if #buf >= 4096 then parts[#parts + 1] = table.concat(buf); buf = {} end
  end
  parts[#parts + 1] = table.concat(buf)
  return table.concat(parts)
end

-- Estado do driver ($C380-$C3FF) depois de um quadro: quando ele se repete, a música deu a volta.
local function driverState(mem)
  local t = {}
  for a = 0xC380, 0xC3FF do t[#t + 1] = string.char(mem[a]) end
  return table.concat(t)
end

-- Renderiza a música (ou o efeito, sfx = true) id por até maxSec segundos.
-- Devolve L, R (amostras -1..1), info = { frames, writes, loopStart (amostra) ou nil }.
-- Para no primeiro estado repetido do driver: o trecho entre as duas ocorrências é o loop.
function Music.render(rom, id, maxSec, rate, sfx)
  rate = rate or 22050
  local m = Music.machine(rom, rate)
  if sfx then m.mem[0xFFF8] = id else m.mem[0xFFF7] = id end
  local L, R = {}, {}
  local frames = math.floor(maxSec * Music.FPS)
  local acc = 0
  local dcL, dcR = 0, 0
  local seen = {}
  local info = { frames = frames }
  for f = 1, frames do
    if not Music.frame(m) then return nil, "driver travou no quadro " .. f end
    local st = driverState(m.mem)
    if seen[st] and f > 2 then
      info.frames = f
      local silent = (f - seen[st].frame) <= 1
      if not silent then info.loopStart = seen[st].sample end
      break
    end
    seen[st] = { frame = f, sample = #L }
    acc = acc + rate / Music.FPS
    local n = math.floor(acc)
    acc = acc - n
    local l0 = #L
    m.apu:render(n, L, R)
    -- remove o nível DC (filtro passa-alta simples, como o capacitor de saída do Game Boy)
    for i = l0 + 1, #L do
      dcL = dcL + (L[i] - dcL) * 0.002; L[i] = L[i] - dcL
      dcR = dcR + (R[i] - dcR) * 0.002; R[i] = R[i] - dcR
    end
  end
  info.writes = m.writes
  return L, R, info
end

return Music
