-- Importador: lê a ROM do jogador e gera o cache em <save dir>/generated/.
-- Nada da ROM é distribuído com o motor; tudo sai daqui, na máquina do jogador.
-- Endereços e formatos documentados em docs/FINDINGS.md.
local Rom = require("src.util.rom")
local serialize = require("src.util.serialize")

local at = Rom.at
local Importer = {}

Importer.CACHE_VERSION = 17
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
    portraitPal = bgpal[5],          -- paleta 4 de BG: retratos da luta e dos diálogos (igual em todas)
    bgpalRaw = (function()           -- as 8 paletas de BG em RGB555 (telas de interface, src/ui/gbui)
      local t, o = {}, at(e[0].bank, e[0].addr)
      for i = 0, 63 do t[i + 1] = rom:u8(o + i) end
      return t
    end)(),
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

-- Retratos dos falantes dos diálogos ($7C:$4108, tabela [banco,00,ptr], 4x4 tiles), indexados.
local NSPEAKERS = 0x30
local function importSpeakers(rom)
  local img = love.image.newImageData(32 * 8, 32 * 6)
  for p = 0, NSPEAKERS - 1 do
    local e = at(0x7C, 0x4108) + p * 4
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

-- Script de falas: índice $5D:$4000 (u16 por script) -> entradas [lo, hi, banco, 00] por mensagem.
-- Bytes < $E0 são texto; >= $E0 são comandos com tamanho na tabela ROM0:$3427.
--   E2 a16 v16 pIgual pDif  desvio: se byte[a16] == v16 (byte baixo) segue em pIgual, senão em pDif
--                           (handler ROM0:$355C; os ponteiros são do mesmo banco)
--   EA xx       muda o falante (retrato xx de $7C:$4108)
--   EE 01 a16   soma 1 no byte a16  (itens: $C4E0 + id)
--   EE 02 a16   liga o byte a16     (recrutamento: $AA00 + vaga*64 + $1D)
--   EE 03 a16 v16  grava v16 em a16 (itens-chave: $C4F1+)
-- Uma mensagem vira { pages, effects } ou, com E2, também { cond = {addr, value}, eq, ne }.
local function decodeMessage(rom, bank, addr, cmdLen, speaker, depth)
  local o = at(bank, addr)
  local pages, cur = {}, { text = {}, speaker = speaker }
  local effects = {}
  local out = { pages = pages, effects = effects, key = ("%02X:%04X"):format(bank, addr) }
  local function flush()
    local t = table.concat(cur.text):gsub("^%s+", ""):gsub("%s+$", "")
    if t ~= "" then pages[#pages + 1] = { speaker = cur.speaker, text = t } end
    cur.text = {}
  end
  local guard = 0
  while guard < 3000 do
    guard = guard + 1
    local c = rom:u8(o)
    if c == 0xFF then break end
    if c < 0xE0 then
      if c >= 32 and c < 127 then
        local ch = string.char(c)
        cur.text[#cur.text + 1] = ch == "`" and "'" or ch
      elseif c == 0xA1 then
        cur.text[#cur.text + 1] = "~"
      end
      o = o + 1
    else
      local n = math.max(cmdLen[c] or 1, 1)
      if c == 0xE2 then
        flush()
        if (depth or 0) < 4 then
          out.cond = { addr = rom:u16(o + 1), value = rom:u8(o + 3) }
          out.eq = decodeMessage(rom, bank, rom:u16(o + 5), cmdLen, cur.speaker, (depth or 0) + 1)
          out.ne = decodeMessage(rom, bank, rom:u16(o + 7), cmdLen, cur.speaker, (depth or 0) + 1)
        end
        return out
      elseif c == 0xEA then
        flush()
        cur.speaker = rom:u8(o + 1)
      elseif c == 0xEE then
        local kind, a16 = rom:u8(o + 1), rom:u16(o + 2)
        if kind == 1 and a16 >= 0xC4E0 and a16 <= 0xC4F0 then
          effects[#effects + 1] = { item = a16 - 0xC4E0, page = #pages + 1 }
        elseif kind == 2 and a16 >= 0xAA00 and a16 < 0xB200 and (a16 - 0xAA1D) % 64 == 0 then
          effects[#effects + 1] = { recruit = (a16 - 0xAA1D) / 64, page = #pages + 1 }
        elseif kind == 3 then
          effects[#effects + 1] = { key = a16 - 0xC4F1, value = rom:u16(o + 4), page = #pages + 1 }
          n = 6
        end
      end
      o = o + n
    end
  end
  flush()
  return out
end

-- Mensagens por nó do mapa-múndi: script = nó + $20 (fases 1-25, cidades 26-31 = $3A-$3F,
-- Instituto 32 = $40, BabyAlliance 33 = $41). O "nó 0" é o script $20: a introdução da história.
local function importMessages(rom)
  local cmdLen = {}
  for i = 0, 31 do cmdLen[0xE0 + i] = rom:u8(0x3427 + i * 4 + 2) end
  local out = {}
  for node = 0, 33 do
    local script = node + 0x20
    local p = rom:u16(at(0x5D, 0x4000) + script * 2)
    local msgs = {}
    for idx = 0, (node >= 1 and node <= 25) and 40 or 12 do
      local e = at(0x5D, p) + idx * 4
      local lo, hi, bank = rom:u8(e), rom:u8(e + 1), rom:u8(e + 2)
      local addr = lo + hi * 256
      if addr >= 0x4000 and addr < 0x8000 and (bank == 0x5D or bank == 0x70) then
        local m = decodeMessage(rom, bank, addr, cmdLen)
        if #m.pages > 0 or #m.effects > 0 or m.cond then msgs[idx] = m end
      end
    end
    out[node] = msgs
  end
  return out
end

-- Mapa-múndi ($09:$69D8): grafo em $09:$6B7D, 24 bytes por nó (índice = [$C529]):
--   +0 id u16, +2 x px u16, +4 y px u16, +6/+8/+10/+12 vizinho para cima/baixo/esquerda/direita,
--   +14/+16/+18/+20 endereço da flag exigida para andar nessa direção (0 = livre; todas são
--   flags de fase vencida $C4F7 + fase - 1), +22 ?
-- O nó n corresponde ao terreno $20 + n do mapa da fase 0.
-- Retratos do prefeito e do morador de cada cidade: $01:$52C8 + cidade*2.
local function importWorld(rom)
  local W = { nodes = {}, townSpeakers = {} }
  for n = 1, 33 do
    local o = at(0x09, 0x6B7D) + n * 24
    local node = { x = math.floor(rom:u16(o + 2) / 16), y = math.floor(rom:u16(o + 4) / 16), nb = {}, gate = {} }
    for d = 1, 4 do
      node.nb[d] = rom:u16(o + 6 + (d - 1) * 2)
      local g = rom:u16(o + 14 + (d - 1) * 2)
      node.gate[d] = g ~= 0 and (g - 0xC4F7 + 1) or 0   -- fase que precisa estar vencida
    end
    W.nodes[n] = node
  end
  for t = 0, 5 do
    W.townSpeakers[26 + t] = { rom:u8(at(0x01, 0x52C8) + t * 2), rom:u8(at(0x01, 0x52C8) + t * 2 + 1) }
  end
  return W
end

-- IA inimiga: listas de casas em volta de um ponto, uma por raio ($09:$5088 -> ponteiros u16 no
-- banco $09; registros de 6 bytes [dx px s16, dy px s16, distância, 0]; $EE = fim do raio >= 2
-- (só continua se o alcance mínimo for 1), $FF = fim). A ordem é do anel mais distante para o
-- mais próximo e, em cada anel, a ordem fixa da tabela. Cura do inimigo: $18:$697B (u16 por golpe).
local function importAI(rom)
  local function s16(v) return v >= 0x8000 and v - 0x10000 or v end
  local A = { rings = {}, heal = {} }
  for r = 0, 8 do
    local o = at(0x09, rom:u16(at(0x09, 0x5088) + r * 2))
    local list = {}
    for _ = 1, 400 do
      local b = rom:u8(o)
      if b == 0xFF then break end
      if b == 0xEE then
        list[#list + 1] = { stop = true }
      else
        list[#list + 1] = { dx = s16(rom:u16(o)) / 16, dy = s16(rom:u16(o + 2)) / 16 }
      end
      o = o + 6
    end
    A.rings[r] = list
  end
  for id = 0, 0x0B do A.heal[id] = rom:u16(at(0x18, 0x697B) + id * 2) end
  return A
end

-- Tela de tiles (abertura e título): blocos copiados para a VRAM, mapa e atributos 20 colunas,
-- paleta de BG de 64 bytes. vram = { { banco VRAM, destino ($8000..), offset na ROM, tamanho } }.
local function renderTiles(rom, vram, mapO, attrO, rows, palO)
  local v = { [0] = {}, [1] = {} }
  for _, blk in ipairs(vram) do
    for i = 0, blk[4] - 1 do v[blk[1]][blk[2] - 0x8000 + i] = rom:u8(blk[3] + i) end
  end
  local pal = palettes(rom, palO, 8)
  local img = love.image.newImageData(160, rows * 8)
  for r = 0, rows - 1 do
    for c = 0, 19 do
      local t, a = rom:u8(mapO + r * 20 + c), rom:u8(attrO + r * 20 + c)
      local base = 0x1000 + (t >= 128 and t - 256 or t) * 16
      local vr = (math.floor(a / 8) % 2 == 1) and v[1] or v[0]
      local p = pal[a % 8 + 1]
      for y = 0, 7 do
        local yy = (math.floor(a / 64) % 2 == 1) and 7 - y or y
        local lo, hi = vr[base + yy * 2] or 0, vr[base + yy * 2 + 1] or 0
        for x = 0, 7 do
          local xx = (math.floor(a / 32) % 2 == 1) and 7 - x or x
          local b = 2 ^ (7 - xx)
          local cc = (math.floor(lo / b) % 2) + 2 * (math.floor(hi / b) % 2)
          img:setPixel(c * 8 + x, r * 8 + y, p[cc + 1][1], p[cc + 1][2], p[cc + 1][3], 1)
        end
      end
    end
  end
  return img
end

-- Abertura (rotina $11:$4000): cena n = tiles $11:$40AC[n] ([tamanho, ptr] -> $9000 e segue em
-- $8800), mapa $11:$40C4[n], atributos $11:$40D0[n] (20x12), paleta $19:$40F7 + (n-1)*64.
-- Título: tiles $38:$490F/$510F/$590F, mapa $38:$45FF, atributos $38:$4767 (20x18), paleta $38:$48CF;
-- botões NEW GAME/RECORDS = 10 sprites 8x16 em $8C:$5310/$5460, paletas de OBJ $38:$5B9F
-- (0 = escolhido, 1 = não).
local function importOpening(rom, ptRom)
  for n = 1, 5 do
    local t = at(0x11, 0x40AC) + n * 4
    local len, src = rom:u16(t), rom:u16(t + 2)
    local first = math.min(len, 0x800)
    local vram = { { 0, 0x9000, at(0x11, src), first } }
    if len > 0x800 then vram[2] = { 0, 0x8800, at(0x11, src) + 0x800, len - 0x800 } end
    local img = renderTiles(rom, vram, at(0x11, rom:u16(at(0x11, 0x40C4) + n * 2)),
      at(0x11, rom:u16(at(0x11, 0x40D0) + n * 2)), 12, at(0x19, 0x40F7) + (n - 1) * 64)
    img:encode("png", ("generated/intro_%d.png"):format(n))
  end
  local title = renderTiles(rom, {
    { 0, 0x9000, at(0x38, 0x490F), 0x800 }, { 0, 0x8800, at(0x38, 0x510F), 0x800 },
    { 1, 0x9000, at(0x38, 0x590F), 0x290 },
  }, at(0x38, 0x45FF), at(0x38, 0x4767), 18, at(0x38, 0x48CF))
  title:encode("png", "generated/title.png")
  for _, lang in ipairs({ "en", "pt" }) do
    local r = lang == "pt" and ptRom or rom
    if r then
      local obp = palettes(rom, at(0x38, 0x5B9F), 2)
      local img = love.image.newImageData(80, 64)
      for b, addr in ipairs({ 0x5310, 0x5460 }) do
        for sel = 0, 1 do
          local p = obp[sel + 1]
          local oy = (b - 1) * 32 + sel * 16
          for k = 0, 9 do
            for hlf = 0, 1 do
              local o = at(0x8C, addr) + k * 32 + hlf * 16
              for y = 0, 7 do
                local lo, hi = r:u8(o + 2 * y), r:u8(o + 2 * y + 1)
                for x = 0, 7 do
                  local bb = 2 ^ (7 - x)
                  local cc = (math.floor(lo / bb) % 2) + 2 * (math.floor(hi / bb) % 2)
                  if cc == 0 then img:setPixel(k * 8 + x, oy + hlf * 8 + y, 0, 0, 0, 0)
                  else img:setPixel(k * 8 + x, oy + hlf * 8 + y, p[cc + 1][1], p[cc + 1][2], p[cc + 1][3], 1) end
                end
              end
            end
          end
        end
      end
      img:encode("png", ("generated/title_buttons_%s.png"):format(lang))
    end
  end
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
  progress("falas")
  data.messages = importMessages(rom)
  data.world = importWorld(rom)
  data.ai = importAI(rom)
  -- Som: o driver ($2C) roda ao vivo no motor; o cache guarda os bancos $00 e $2C.
  -- Música de cada fase: $00:$2C85 + fase ($00:$034B).
  local banks = {}
  for o = 0, 0x3FFF do banks[#banks + 1] = string.char(rom:u8(o)) end
  for o = 0, 0x3FFF do banks[#banks + 1] = string.char(rom:u8(0x2C * 0x4000 + o)) end
  love.filesystem.write("generated/sound.bin", table.concat(banks))
  -- Animação de batalha (src/anim): só os bytes que a cena lê (scripts, quadros, tiles, cenários).
  love.filesystem.write("generated/attack.bin", (require("src.anim.slice").build(rom.data)))
  if love.filesystem.getInfo("generated/rom.bin") then love.filesystem.remove("generated/rom.bin") end
  -- Telas de interface do original (scripts $BC, mapas $BD, tiles $40/$41, fonte $39, nomes e
  -- retratos em imagem): em inglês da ROM do jogador e em português da ROM traduzida pelo conversor.
  progress("telas")
  local Slice = require("src.anim.slice")
  love.filesystem.write("generated/ui_en.bin", Slice.fromBanks(rom.data, Slice.UI_BANKS))
  local okPt, pt = pcall(function() return require("src.romhack.patcher").build(rom.data, {}) end)
  if okPt then love.filesystem.write("generated/ui_pt.bin", Slice.fromBanks(pt, Slice.UI_BANKS))
  else print("telas em português: " .. tostring(pt)) end
  progress("abertura")
  importOpening(rom, okPt and Rom.new(pt) or nil)
  data.introPal = {}                                  -- paletas das cenas ($19:$40F7 + (n-1)*64)
  for n = 1, 5 do
    local t, o = {}, at(0x19, 0x40F7) + (n - 1) * 64
    for i = 0, 63 do t[i + 1] = rom:u8(o + i) end
    data.introPal[n] = t
  end
  data.music = { stage = {} }
  for st = 0, NSTAGES - 1 do data.music.stage[st] = rom:u8(0x2C85 + st) end
  importSpeakers(rom):encode("png", "generated/speakers.png")
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
