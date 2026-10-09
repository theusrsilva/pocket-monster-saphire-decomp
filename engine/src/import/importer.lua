-- Importador: lê a ROM do jogador e gera o cache em <save dir>/generated/.
-- Nada da ROM é distribuído com o motor; tudo sai daqui, na máquina do jogador.
-- Endereços e formatos documentados em docs/FINDINGS.md.
local Rom = require("src.util.rom")
local serialize = require("src.util.serialize")

local at = Rom.at
local Importer = {}

Importer.CACHE_VERSION = 4
local NSTAGES = 32
local NSPECIES_TABLE = 20     -- espécies recrutáveis ($09:$4000, 20 bytes)
local NCOST_ROWS = 76         -- linhas da tabela de custo ($09:$4190, 33 bytes)
local TYPES = { "Celerity", "Equilibrium", "Strength", "SuperPower", "Defense" }

local function bgr555(v)
  local r, g, b = v % 32, math.floor(v / 32) % 32, math.floor(v / 1024) % 32
  return { r / 31, g / 31, b / 31 }
end

local function palettes(rom, o, n)
  local out = {}
  for p = 0, n - 1 do
    local pal = {}
    for c = 0, 3 do pal[c + 1] = bgr555(rom:u16(o + p * 8 + c * 2)) end
    out[p + 1] = pal
  end
  return out
end

-- Cabeçalho da fase ($7D:$4000 + fase*64): entradas [banco, 00, ptr u16].
local function stageHeader(rom, s)
  local o = at(0x7D, 0x4000) + s * 64
  local e = {}
  for k = 0, 12 do
    e[k] = { bank = rom:u8(o + k * 4), addr = rom:u16(o + k * 4 + 2) }
  end
  return e, rom:u16(o + 0x38), rom:u8(o + 0x3A)
end

-- Monta a VRAM de tiles (banco 0) a partir dos blocos +08/+0C/+10.
local function stageVram(rom, e)
  local vram = {}
  for k = 2, 4 do
    local blk = e[k]
    if blk.addr ~= 0 then
      local o = at(blk.bank, blk.addr)
      local dest, size = rom:u16(o), rom:u16(o + 2)
      o = o + 4
      for i = 0, size - 1 do
        if dest >= 0x9800 then dest = 0x8800 end
        vram[dest - 0x8000] = rom:u8(o + i)
        dest = dest + 1
      end
    end
  end
  return vram
end

local function drawTile(img, vram, pal, ox, oy, t, attr)
  local p = pal[attr % 8 + 1]
  local xflip = math.floor(attr / 32) % 2 == 1
  local yflip = math.floor(attr / 64) % 2 == 1
  local idx = t < 128 and t or t - 256
  local base = 0x9000 - 0x8000 + idx * 16
  for y = 0, 7 do
    local yy = yflip and 7 - y or y
    local lo, hi = vram[base + yy * 2] or 0, vram[base + yy * 2 + 1] or 0
    for x = 0, 7 do
      local xx = xflip and 7 - x or x
      local bit = 7 - xx
      local c = (math.floor(lo / 2 ^ bit) % 2) + 2 * (math.floor(hi / 2 ^ bit) % 2)
      local col = p[c + 1]
      img:setPixel(ox + x, oy + y, col[1], col[2], col[3], 1)
    end
  end
end

local function importStage(rom, s)
  local e, rowbytes, rows = stageHeader(rom, s)
  local cols = rowbytes / 2
  local bgpal = palettes(rom, at(e[0].bank, e[0].addr), 8)
  local vram = stageVram(rom, e)
  local mapO = at(e[9].bank, e[9].addr)
  local mtO = at(e[10].bank, e[10].addr)
  local terO = at(e[11].bank, e[11].addr)
  local img = love.image.newImageData(cols * 16, rows * 16)
  local terrain = {}
  for cy = 0, rows - 1 do
    for cx = 0, cols - 1 do
      local mt = rom:u16(mapO + (cy * cols + cx) * 2)
      local mo = mtO + mt * 8
      for q = 0, 3 do
        drawTile(img, vram, bgpal, cx * 16 + (q % 2) * 8, cy * 16 + math.floor(q / 2) * 8,
          rom:u8(mo + q), rom:u8(mo + 4 + q))
      end
      terrain[cy * cols + cx + 1] = rom:u8(terO + mt * 4 + 2)
    end
  end

  -- Inimigos: $30:$40E6 -> ponteiro por fase; registros de 24 bytes até nível $FF.
  local enemies = {}
  local p = rom:u16(at(0x30, 0x40E6) + s * 2)
  if p ~= 0xFFFF then
    local o = at(0x30, p)
    while rom:u8(o) ~= 0xFF and #enemies < 20 do
      enemies[#enemies + 1] = {
        level = rom:u8(o), species = rom:u8(o + 1), type = rom:u8(o + 2),
        y = math.floor(rom:u16(o + 3) / 16), x = math.floor(rom:u16(o + 5) / 16),
        slot = rom:u8(o + 7), sp = rom:u16(o + 8), hp = rom:u16(o + 10),
        atk = rom:u8(o + 12), acc = rom:u8(o + 13), eva = rom:u8(o + 14), move = rom:u8(o + 15),
        strong = rom:u8(o + 16), weak = rom:u8(o + 17),
        rmin = rom:u8(o + 18), rmax = rom:u8(o + 19),
        skill = rom:u8(o + 20) ~= 0 and rom:u8(o + 20) or nil,
      }
      o = o + 24
    end
  end

  -- Posições iniciais dos aliados: $10:$450E -> registros [00 00, y u16, x u16] até $FFFF.
  local starts = {}
  local sp = rom:u16(at(0x10, 0x450E) + s * 2)
  local o = at(0x10, sp)
  while rom:u16(o) ~= 0xFFFF and #starts < 10 do
    starts[#starts + 1] = { y = math.floor(rom:u16(o + 2) / 16), x = math.floor(rom:u16(o + 4) / 16) }
    o = o + 6
  end

  return img, {
    cols = cols, rows = rows, terrain = terrain, enemies = enemies, starts = starts,
    allyPal = bgpal[8], enemyPal = bgpal[7],
  }
end

local function importSpecies(rom)
  local list = {}
  local base = at(0x09, 0x4000)
  for i = 0, NSPECIES_TABLE - 1 do
    local o = base + i * 20
    list[i + 1] = {
      level = rom:u8(o), species = rom:u8(o + 1), type = rom:u8(o + 2),
      sp = rom:u16(o + 3), hp = rom:u16(o + 5),
      atk = rom:u8(o + 7), acc = rom:u8(o + 8), eva = rom:u8(o + 9), move = rom:u8(o + 10),
      strong = rom:u8(o + 11), weak = rom:u8(o + 12), starter = rom:u8(o + 13) == 1,
      rmin = rom:u8(o + 14), rmax = rom:u8(o + 15),
      skills = { rom:u8(o + 16), rom:u8(o + 17) },
    }
  end
  return list
end

-- Custo de movimento: custo = T[espécie*33 + terreno] ($09:$4190); $63 = intransitável.
local function importCosts(rom)
  local rows = {}
  local base = at(0x09, 0x4190)
  for s = 0, NCOST_ROWS - 1 do
    local r = {}
    for t = 0, 32 do r[t] = rom:u8(base + s * 33 + t) end
    rows[s] = r
  end
  return rows
end

-- Progressão (nível, evolução) e golpes. Tabelas indexadas pelo id da espécie (0..$37).
local function importProgression(rom)
  local P = { maxLevel = {}, gains = {}, growth = {}, final = {}, evoBonus = {}, learn = {} }
  for s = 0, 0x37 do
    P.maxLevel[s] = rom:u8(at(0x1D, 0x5814) + s)                 -- nível máximo da forma
    local g = at(0x01, 0x6935) + s * 5                           -- [HP+, SP+, chance ATK/PRE/ESQ]
    P.gains[s] = { rom:u8(g), rom:u8(g + 1), rom:u8(g + 2), rom:u8(g + 3), rom:u8(g + 4) }
    P.growth[s] = rom:u8(at(0x01, 0x6A71) + s)                   -- estágio da evolução (1..3)
    P.final[s] = rom:u8(at(0x01, 0x56FF) + s) ~= 0               -- forma final (não evolui)
    local e = at(0x19, 0x5C14) + s * 6                           -- bônus ao evoluir para s
    P.evoBonus[s] = { sp = rom:u8(e), hp = rom:u8(e + 1), atk = rom:u8(e + 2), acc = rom:u8(e + 3),
      eva = rom:u8(e + 4), move = rom:u8(e + 5) }
    P.learn[s] = rom:u8(at(0x19, 0x5EDA) + s)                    -- golpe aprendido ao evoluir para s
  end
  -- ganho sorteado de ATK/PRE/ESQ por estágio: tabela[estágio][rand & 3]
  P.gainValues, P.bonusChoice = {}, {}
  for c = 0, 3 do
    P.gainValues[c] = {}
    for i = 0, 3 do P.gainValues[c][i + 1] = rom:u8(at(0x01, 0x6A4D) + c * 4 + i) end
    P.bonusChoice[c] = {}                                        -- bônus escolhido: HP, SP, ATK, PRE, ESQ
    for i = 0, 4 do P.bonusChoice[c][i + 1] = rom:u8(at(0x01, 0x6A5D) + c * 5 + i) end
  end
  -- golpes ($09:$4D5B, 6 bytes): [cura?, poder u16, custo SP, alcance mín, alcance máx]
  P.skills = {}
  for id = 1, 0x57 do
    local o = at(0x09, 0x4D5B) + id * 6
    P.skills[id] = { heal = rom:u8(o) == 1, power = rom:u16(o + 1), cost = rom:u8(o + 3),
      rmin = rom:u8(o + 4), rmax = rom:u8(o + 5) }
  end
  return P
end

-- Sprites 16x16 das unidades no mapa ($FD:$4000 + espécie*64), salvos como imagem indexada:
-- canal R = índice da cor (0..3)/3; a paleta é aplicada por shader na hora de desenhar.
local function importUnitSprites(rom)
  local img = love.image.newImageData(16 * 16, 16 * 16)
  local base = at(0xFD, 0x4000)
  for s = 0, 255 do
    local ox, oy = (s % 16) * 16, math.floor(s / 16) * 16
    for q = 0, 3 do
      for y = 0, 7 do
        local o = base + s * 64 + q * 16 + y * 2
        local lo, hi = rom:u8(o), rom:u8(o + 1)
        for x = 0, 7 do
          local bit = 7 - x
          local c = (math.floor(lo / 2 ^ bit) % 2) + 2 * (math.floor(hi / 2 ^ bit) % 2)
          img:setPixel(ox + (q % 2) * 8 + x, oy + math.floor(q / 2) * 8 + y, c / 3, 0, 0, c == 0 and 0 or 1)
        end
      end
    end
  end
  return img
end

-- Retratos 32x32 (4x4 tiles row-major). Tabela [banco, 00, ptr u16] por espécie em $F4:$4000
-- (mesmo esquema do carregador ROM0:$300B); ids $3E+ ficam no banco $F5. Imagem indexada.
local NPORTRAITS = 0x4C
local function importPortraits(rom)
  local img = love.image.newImageData(32 * 8, 32 * 10)
  for p = 0, NPORTRAITS - 1 do
    local e = at(0xF4, 0x4000) + p * 4
    local bank, addr = rom:u8(e), rom:u16(e + 2)
    if addr >= 0x4000 and addr < 0x8000 then
      local base = at(bank, addr)
      local ox, oy = (p % 8) * 32, math.floor(p / 8) * 32
      for t = 0, 15 do
        for y = 0, 7 do
          local o = base + t * 16 + y * 2
          local lo, hi = rom:u8(o), rom:u8(o + 1)
          for x = 0, 7 do
            local bit = 7 - x
            local c = (math.floor(lo / 2 ^ bit) % 2) + 2 * (math.floor(hi / 2 ^ bit) % 2)
            img:setPixel(ox + (t % 4) * 8 + x, oy + math.floor(t / 4) * 8 + y, c / 3, 0, 0, 1)
          end
        end
      end
    end
  end
  return img
end

-- Executa a importação. progress(msg) é chamado entre etapas. Retorna true ou nil, erro.
function Importer.run(bytes, progress)
  progress = progress or function() end
  local rom = Rom.new(bytes)
  if rom.size ~= 4194304 then
    return nil, ("tamanho inesperado (%d bytes)"):format(rom.size)
  end
  local sha = rom:sha1()
  if sha ~= Rom.SHA1 then
    return nil, "SHA-1 não confere: " .. sha
  end
  love.filesystem.createDirectory("generated")
  local data = { version = Importer.CACHE_VERSION, stages = {}, types = TYPES }
  progress("espécies")
  data.species = importSpecies(rom)
  data.costs = importCosts(rom)
  data.prog = importProgression(rom)
  progress("sprites")
  importUnitSprites(rom):encode("png", "generated/units.png")
  importPortraits(rom):encode("png", "generated/portraits.png")
  for s = 0, NSTAGES - 1 do
    progress(("fase %d/%d"):format(s, NSTAGES - 1))
    local img, st = importStage(rom, s)
    img:encode("png", ("generated/stage_%02d.png"):format(s))
    data.stages[s] = st
  end
  love.filesystem.write("generated/data.lua", serialize(data))
  return true
end

function Importer.load()
  if not love.filesystem.getInfo("generated/data.lua") then return nil end
  local ok, data = pcall(function() return love.filesystem.load("generated/data.lua")() end)
  if not ok or type(data) ~= "table" or data.version ~= Importer.CACHE_VERSION then return nil end
  return data
end

return Importer
