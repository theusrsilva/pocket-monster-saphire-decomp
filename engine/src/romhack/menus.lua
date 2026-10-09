-- Palavras dos menus (desenhadas em tiles) em português.
--
-- Os menus são mapas de tela no banco $BD (ids de tile, depois os atributos) e usam dois grupos de
-- tiles: ids < $20 = moldura comum ($40:$4000 + id*16) e ids >= $20 = bloco do menu
-- (banco/base próprios: id -> base + id*16). Ver docs/FINDINGS.md, "Menus".
--
-- Para cada tela: acha as palavras originais na região (faixas de linhas com tinta e, dentro
-- delas, trechos separados por um vão largo), apaga a tinta, escreve o texto novo na mesma linha de
-- base (fonte própria, src/romhack/pixelfont.lua) e refaz os tiles da região: célula igual à
-- original mantém o id; célula vazia usa o tile vazio; célula igual a um tile da moldura usa a
-- moldura; o resto ganha ids que só aparecem dentro das regiões (dedupe), com os dados regravados.
local Buffer = require("src.romhack.buffer")
local PixelFont = require("src.romhack.pixelfont")

local Menus = {}
local at = Buffer.at
local FRAME_BANK, FRAME_ADDR = 0x40, 0x4000

-- texts: um por trecho de palavra achado, em ordem de leitura; false = deixa o trecho como está.
Menus.SCREENS = {
  { name = "menu de batalha", group = "b", map = { 0xBD, 0x40F0, 6, 12 }, chunk = { 0x40, 0x4340 },
    region = { 0, 1, 5, 10 }, align = "left",
    texts = { "Atacar", "Golpe", "Itens", "Status", "Esperar" } },
  { name = "menu do mapa", group = "s", map = { 0xBD, 0x4C18, 9, 12 }, chunk = { 0x40, 0x5E10 },
    region = { 0, 1, 8, 10 }, align = "center", gap = 9,
    texts = { "Ver time", "Salvar", "Carregar", "Objetivo", "Fim" } },
  { name = "escolha do time", group = "t", map = { 0xBD, 0x63E8, 20, 18 }, chunk = { 0x41, 0x5770 },
    region = { 1, 1, 11, 2 }, align = "left",
    texts = { "Podem lutar" } },
  { name = "escolha do time (rodapé)", group = "t", map = { 0xBD, 0x63E8, 20, 18 }, chunk = { 0x41, 0x5770 },
    region = { 0, 15, 15, 16 }, align = "left", gap = 4, splitAt = { 82, 104 },
    texts = { "Lutar", "Trocar", false, "Pág." } },
  { name = "Instituto", group = "c", map = { 0xBD, 0x5E48, 20, 9 }, chunk = { 0x41, 0x4AC0 },
    region = { 1, 1, 19, 2 }, align = "center",
    texts = { "Vantagens", "Dicas" } },
  { name = "Aliança Pokémon", group = "c", map = { 0xBD, 0x5FB0, 20, 9 }, chunk = { 0x41, 0x4AC0 },
    region = { 1, 1, 19, 2 }, align = "center",
    texts = { "Condições", "Evoluir" } },
  { name = "cidade", group = "c", map = { 0xBD, 0x5CE0, 20, 9 }, chunk = { 0x41, 0x4AC0 },
    region = { 8, 1, 19, 2 }, align = "center",
    texts = { "Prefeito", "Morador" } },
}

local function tileOffset(chunk, id)
  if id < 0x20 then return at(FRAME_BANK, FRAME_ADDR) + id * 16 end
  return at(chunk[1], chunk[2]) + id * 16
end

local function readTile(rom, o)
  local px = {}
  for y = 0, 7 do
    local lo, hi = rom:u8(o + 2 * y), rom:u8(o + 2 * y + 1)
    px[y] = {}
    for x = 0, 7 do
      local bit = 2 ^ (7 - x)
      px[y][x] = (math.floor(lo / bit) % 2) + 2 * (math.floor(hi / bit) % 2)
    end
  end
  return px
end

local function tileBytes(px)
  local t = {}
  for y = 0, 7 do
    local lo, hi = 0, 0
    for x = 0, 7 do
      local c = px[y][x]
      if c % 2 == 1 then lo = lo + 2 ^ (7 - x) end
      if c >= 2 then hi = hi + 2 ^ (7 - x) end
    end
    t[#t + 1] = lo; t[#t + 1] = hi
  end
  return t
end

local function key(t) return table.concat(t, ",") end

-- Trechos de tinta na região: faixas de linhas e, nelas, grupos separados por >= 6 px vazios.
local function findSegments(canvas, w, h, ink, gapMin)
  local segs = {}
  local y = 0
  while y < h do
    local any = false
    for x = 0, w - 1 do if canvas[y][x] == ink then any = true break end end
    if any then
      local y0 = y
      while y < h do
        local rowAny = false
        for x = 0, w - 1 do if canvas[y][x] == ink then rowAny = true break end end
        if not rowAny then break end
        y = y + 1
      end
      local y1 = y - 1
      local cols = {}
      for x = 0, w - 1 do
        for yy = y0, y1 do if canvas[yy][x] == ink then cols[x] = true break end end
      end
      local x = 0
      while x < w do
        if cols[x] then
          local x0, last = x, x
          while x < w do
            if cols[x] then last = x
            elseif x - last >= gapMin then break end
            x = x + 1
          end
          segs[#segs + 1] = { x0 = x0, x1 = last, y0 = y0, y1 = y1 }
          x = last + 1
        else
          x = x + 1
        end
      end
    else
      y = y + 1
    end
  end
  return segs
end

function Menus.applyScreen(rom, sc, groupMaps)
  local mapBank, mapAddr, mw, mh = sc.map[1], sc.map[2], sc.map[3], sc.map[4]
  local mo = at(mapBank, mapAddr)
  local cx0, cy0, cx1, cy1 = sc.region[1], sc.region[2], sc.region[3], sc.region[4]
  local W, H = (cx1 - cx0 + 1) * 8, (cy1 - cy0 + 1) * 8
  -- canvas da região
  -- atributos logo depois do mapa: bit 5 = espelho horizontal, bit 6 = vertical
  local ao = mo + mw * mh
  local canvas, orig, origKey = {}, {}, {}
  for y = 0, H - 1 do canvas[y] = {} end
  for cy = cy0, cy1 do
    for cx = cx0, cx1 do
      local id = rom:u8(mo + cy * mw + cx)
      orig[cy * mw + cx] = id
      local attr = rom:u8(ao + cy * mw + cx)
      local fx, fy = math.floor(attr / 32) % 2 == 1, math.floor(attr / 64) % 2 == 1
      local px = readTile(rom, tileOffset(sc.chunk, id))
      local shown = {}
      for y = 0, 7 do
        shown[y] = {}
        for x = 0, 7 do
          local v = px[fy and 7 - y or y][fx and 7 - x or x]
          shown[y][x] = v
          canvas[(cy - cy0) * 8 + y][(cx - cx0) * 8 + x] = v
        end
      end
      origKey[cy * mw + cx] = key(tileBytes(shown))
    end
  end
  -- cores: fundo = mais comum; tinta = cor 0 (texto dos menus), ou a segunda mais comum
  local count = { [0] = 0, 0, 0, 0 }
  for y = 0, H - 1 do for x = 0, W - 1 do count[canvas[y][x]] = count[canvas[y][x]] + 1 end end
  local bg = 0
  for c = 0, 3 do if count[c] > count[bg] then bg = c end end
  local ink = sc.ink or (bg ~= 0 and 0 or 3)
  local segs = findSegments(canvas, W, H, ink, sc.gap or 7)
  for _, cut in ipairs(sc.splitAt or {}) do
    for i = #segs, 1, -1 do
      local g = segs[i]
      if g.x0 < cut and g.x1 >= cut then
        table.remove(segs, i)
        table.insert(segs, i, { x0 = cut, x1 = g.x1, y0 = g.y0, y1 = g.y1 })
        table.insert(segs, i, { x0 = g.x0, x1 = cut - 1, y0 = g.y0, y1 = g.y1 })
      end
    end
  end
  for _, g in ipairs(segs) do                       -- limites do próprio trecho
    local y0, y1, x0, x1
    for y = g.y0, g.y1 do
      for x = g.x0, g.x1 do
        if canvas[y][x] == ink then
          y0 = y0 or y; y1 = y
          x0 = math.min(x0 or x, x); x1 = math.max(x1 or x, x)
        end
      end
    end
    g.y0, g.y1, g.x0, g.x1 = y0, y1, x0, x1
    -- linha de base = fundo mais comum entre as colunas (descendentes são minoria)
    local votes, best = {}, nil
    for x = x0, x1 do
      local b
      for y = y0, y1 do if canvas[y][x] == ink then b = y end end
      if b then
        votes[b] = (votes[b] or 0) + 1
        if not best or votes[b] > votes[best] or (votes[b] == votes[best] and b > best) then best = b end
      end
    end
    g.base = best
  end
  if Menus.debug then for _, g in ipairs(segs) do io.stderr:write(("  trecho x %d-%d y %d-%d base %d\n"):format(g.x0, g.x1, g.y0, g.y1, g.base)) end end
  if #segs ~= #sc.texts then
    error(("%s: %d trechos de texto achados, esperava %d"):format(sc.name, #segs, #sc.texts))
  end
  -- apaga e escreve
  local plan = {}
  for i, s in ipairs(segs) do
    local t = sc.texts[i]
    if t then
      for y = s.y0, s.y1 do for x = s.x0, s.x1 do if canvas[y][x] == ink then canvas[y][x] = bg end end end
      local prev, nxt = segs[i - 1], segs[i + 1]
      local xmin = (prev and prev.y0 == s.y0) and prev.x1 + 4 or 0
      local xmax = (nxt and nxt.y0 == s.y0) and nxt.x0 - 4 or W - 1
      local base = s.base
      plan[#plan + 1] = { t = t, s = s, xmin = math.max(xmin, sc.align == "left" and s.x0 or 0), xmax = xmax, base = base }
    end
  end
  for _, p in ipairs(plan) do
    -- limite da direita: o fim do trecho original ou até a moldura (primeira coluna não-fundo)
    local font, gap = "normal", 1
    local tw = PixelFont.width(font, p.t, gap)
    local room = p.xmax - p.xmin + 1
    if tw > room then gap = 0; tw = PixelFont.width(font, p.t, gap) end
    if tw > room then font, gap = "small", 1; tw = PixelFont.width(font, p.t, gap) end
    if tw > room then error(("%s: \"%s\" não cabe (%d > %d px)"):format(sc.name, p.t, tw, room)) end
    local x
    if sc.align == "left" then x = p.s.x0
    else x = math.floor((p.s.x0 + p.s.x1) / 2 - tw / 2 + 0.5) end
    x = math.max(p.xmin, math.min(x, p.xmax - tw + 1))
    -- normal: corpo nas linhas 2-8 da célula (base na 8); small: 2-6
    local top = p.base - (font == "normal" and 8 or 6)
    PixelFont.draw(font, p.t, x, top, gap, function(px, py)
      if py >= 0 and py < H and px >= 0 and px < W then canvas[py][px] = ink end
    end)
  end
  -- refaz os tiles: ids exclusivos das regiões do grupo
  local inRegion, total = {}, {}
  for _, gm in ipairs(groupMaps) do
    local o = at(gm.map[1], gm.map[2])
    for i = 0, gm.map[3] * gm.map[4] - 1 do
      local id = rom:u8(o + i)
      total[id] = (total[id] or 0) + 1
      local cx, cy = i % gm.map[3], math.floor(i / gm.map[3])
      if gm.region and cx >= gm.region[1] and cx <= gm.region[3] and cy >= gm.region[2] and cy <= gm.region[4] then
        inRegion[id] = (inRegion[id] or 0) + 1
      end
    end
  end
  local function data(id) return readTile(rom, tileOffset(sc.chunk, id)) end
  local function isBlank(px)
    for y = 0, 7 do for x = 0, 7 do if px[y][x] ~= bg then return false end end end
    return true
  end
  local known, pool = {}, {}
  for id = 0x1F, 0, -1 do known[key(tileBytes(data(id)))] = id end   -- moldura comum
  local seen, ids = {}, {}
  for _, id in pairs(orig) do if not seen[id] then seen[id] = true; ids[#ids + 1] = id end end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local px = data(id)
    if id >= 0x20 then
      if isBlank(px) then
        known[key(tileBytes(px))] = known[key(tileBytes(px))] or id
      elseif inRegion[id] == total[id] then
        pool[#pool + 1] = id
      end
    end
  end
  local newData = {}
  local used = 0
  for cy = cy0, cy1 do
    for cx = cx0, cx1 do
      local px = {}
      for y = 0, 7 do px[y] = {} for x = 0, 7 do px[y][x] = canvas[(cy - cy0) * 8 + y][(cx - cx0) * 8 + x] end end
      local bytes = tileBytes(px)
      local k = key(bytes)
      local id0 = orig[cy * mw + cx]
      local id
      local exclusive = id0 >= 0x20 and inRegion[id0] == total[id0]
      if k == origKey[cy * mw + cx] and not exclusive then
        id = id0
      elseif known[k] then
        id = known[k]
      elseif newData[k] then
        id = newData[k].id
      else
        used = used + 1
        id = pool[used]
        if not id then error(sc.name .. ": faltam tiles livres para o texto novo") end
        newData[k] = { id = id, bytes = bytes }
      end
      if id ~= id0 or k ~= origKey[cy * mw + cx] then
        local attr = rom:u8(ao + cy * mw + cx)
        rom:set(ao + cy * mw + cx, attr - (math.floor(attr / 32) % 4) * 32)   -- sem espelho
      end
      rom:set(mo + cy * mw + cx, id)
    end
  end
  for _, d in pairs(newData) do rom:write(tileOffset(sc.chunk, d.id), d.bytes) end
  return used, #pool
end

-- Aplica todas as telas. Telas do mesmo grupo dividem o bloco de tiles: as que dividem também o
-- mapa (mesmo endereço) são feitas juntas, e os ids exclusivos consideram todas as regiões.
function Menus.apply(rom)
  local report = {}
  local groups = {}
  for _, sc in ipairs(Menus.SCREENS) do
    groups[sc.group] = groups[sc.group] or {}
    table.insert(groups[sc.group], sc)
  end
  -- os ids livres são reservados por grupo: cada tela só usa os seus (regiões não se cruzam)
  for _, sc in ipairs(Menus.SCREENS) do
    local gm = {}
    local seenMap = {}
    for _, other in ipairs(groups[sc.group]) do
      local mk = other.map[2]
      if not seenMap[mk] then
        seenMap[mk] = true
        -- região efetiva do mapa = a desta tela se for o mesmo mapa; senão nenhuma
        gm[#gm + 1] = { map = other.map, region = (mk == sc.map[2]) and sc.region or nil }
      end
    end
    if Menus.debug then io.stderr:write("tela " .. sc.name .. "\n") end
    local used, pool = Menus.applyScreen(rom, sc, gm)
    report[#report + 1] = ("%s: %d/%d tiles"):format(sc.name, used, pool)
  end
  return report
end

return Menus
