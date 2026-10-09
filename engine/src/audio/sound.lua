-- Som em tempo real: o driver de som original (banco $2C) roda no interpretador SM83 e o APU é
-- sintetizado em Lua, alimentando uma QueueableSource do LÖVE. O cache guarda só os bancos que o
-- driver usa (generated/sound.bin = banco $00 + banco $2C), gerados da ROM do jogador.
--   música: [$FFF7] = número (< $20), $21 = parar     efeito: [$FFF8] = número
local Music = require("src.import.music")

local Sound = { enabled = true, volume = 0.5, RATE = 22050, BUF = 1024 }
Sound.CURSOR = 0x1B          -- efeito do cursor dos menus ($01:$59E3)
Sound.STOP = 0x21
Sound.TEAM, Sound.VICTORY, Sound.INTRO, Sound.ENDING = 0x0D, 0x14, 0x0B, 0x15

-- "ROM" com só os dois bancos do cache.
function Sound.shim(bin)
  local b = {}
  for i = 1, #bin, 4096 do
    local chunk = { string.byte(bin, i, math.min(#bin, i + 4095)) }
    for j = 1, #chunk do b[i + j - 1] = chunk[j] end
  end
  return {
    u8 = function(_, o)
      if o < 0x4000 then return b[o + 1] or 0xFF end
      local bank = math.floor(o / 0x4000)
      if bank == 0x2C then return b[0x4000 + (o % 0x4000) + 1] or 0xFF end
      return 0xFF
    end,
  }
end

function Sound.init(stageMusic)
  Sound.stageMusic = stageMusic or {}
  if not (love.audio and love.sound) then return false end
  local ok, err = pcall(function()
    local bin = assert(love.filesystem.read("generated/sound.bin"))
    Sound.m = Music.machine(Sound.shim(bin), Sound.RATE)
    Sound.src = love.audio.newQueueableSource(Sound.RATE, 16, 2, 4)
    Sound.data = love.sound.newSoundData(Sound.BUF, Sound.RATE, 16, 2)
    Sound.L, Sound.R, Sound.acc = {}, {}, 0
  end)
  if not ok then Sound.m = nil; print("som desligado: " .. tostring(err)) end
  return ok
end

function Sound.music(id)
  if not Sound.m or Sound.current == id then return end
  Sound.current = id
  Sound.m.mem[0xFFF7] = id
end

function Sound.stageMusic_(stage)
  local id = Sound.stageMusic and Sound.stageMusic[stage]
  if id then Sound.music(id) end
end

function Sound.stop()
  if not Sound.m then return end
  Sound.current = nil
  Sound.m.mem[0xFFF7] = Sound.STOP
end

function Sound.sfx(id)
  if Sound.m and Sound.enabled then Sound.m.mem[0xFFF8] = id end
end

function Sound.toggle()
  Sound.enabled = not Sound.enabled
  if Sound.src then Sound.src:setVolume(Sound.enabled and Sound.volume or 0) end
  return Sound.enabled
end

-- Gera quadros do driver até encher um buffer e o entrega à fila de áudio.
local function fill()
  local m, L, R = Sound.m, Sound.L, Sound.R
  while #L < Sound.BUF do
    Music.frame(m)
    Sound.acc = Sound.acc + Sound.RATE / Music.FPS
    local n = math.floor(Sound.acc)
    Sound.acc = Sound.acc - n
    m.apu:render(n, L, R)
  end
  local d = Sound.data
  local dcL, dcR = Sound.dcL or 0, Sound.dcR or 0
  for i = 1, Sound.BUF do
    -- passa-alta (como o capacitor de saída do Game Boy) e ganho
    dcL = dcL + (L[i] - dcL) * 0.002
    dcR = dcR + (R[i] - dcR) * 0.002
    d:setSample(i - 1, 1, math.max(-1, math.min(1, (L[i] - dcL) * 2)))
    d:setSample(i - 1, 2, math.max(-1, math.min(1, (R[i] - dcR) * 2)))
  end
  Sound.dcL, Sound.dcR = dcL, dcR
  -- sobra para o próximo buffer
  local nL, nR = {}, {}
  for i = Sound.BUF + 1, #L do nL[#nL + 1] = L[i]; nR[#nR + 1] = R[i] end
  Sound.L, Sound.R = nL, nR
  Sound.src:queue(d)
end

function Sound.update()
  if not Sound.m then return end
  local ok, err = pcall(function()
    while Sound.src:getFreeBufferCount() > 0 do fill() end
    if not Sound.src:isPlaying() then
      Sound.src:setVolume(Sound.enabled and Sound.volume or 0)
      Sound.src:play()
    end
  end)
  if not ok then print("som desligado: " .. tostring(err)); Sound.m = nil end
end

return Sound
