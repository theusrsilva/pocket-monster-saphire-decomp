-- Palavras dos menus (desenhadas em tiles) em português.
--
-- Os menus são mapas de tela no banco $BD (ids de tile w*h, seguidos dos atributos w*h) e usam
-- dois grupos de tiles: ids < $20 = moldura comum ($40:$4000 + id*16) e ids >= $20 = bloco do
-- menu (id -> base + id*16). Atributo: bit 5/6 = espelho (o original deduplica espelhando).
-- Ver docs/FINDINGS.md, "Menus".
--
-- Para cada região: acha as palavras originais (faixas de linhas com tinta e, dentro delas,
-- trechos separados por um vão largo), apaga a tinta, escreve o texto novo na mesma linha de base
-- (fonte própria, src/romhack/pixelfont.lua). Depois refaz os tiles de todas as regiões do mapa:
-- célula igual à original mantém o id; célula vazia usa o tile vazio; célula igual a um tile da
-- moldura usa a moldura; o resto ganha ids que só aparecem dentro das regiões (com dedupe) e os
-- dados desses ids são regravados.
local Buffer = require("src.romhack.buffer")
local PixelFont = require("src.romhack.pixelfont")

local Menus = {}
local at = Buffer.at
local FRAME_BANK, FRAME_ADDR = 0x40, 0x4000

-- Uma entrada por mapa. Telas que dividem o bloco de tiles ficam no mesmo grupo (os ids
-- exclusivos consideram todos os mapas do grupo). Em cada região: texts = um por trecho achado,
-- em ordem de leitura (false = deixa o trecho como está); gap = vão mínimo entre trechos (px);
-- splitAt = cortes forçados (x em px da região).
Menus.SCREENS = {
  { name = "menu da unidade", group = "b", map = { 0xBD, 0x40F0, 6, 12 }, chunk = { 0x40, 0x4340 },
    regions = { { 0, 1, 5, 10, align = "left", texts = { "Atacar", "Golpe", "Itens", "Status", "Esperar" } } } },
  { name = "submenu de itens", group = "b", map = { 0xBD, 0x4180, 6, 6 }, chunk = { 0x40, 0x4340 },
    regions = { { 0, 1, 5, 4, align = "left", texts = { "Cura", "Especial" } } } },
  { name = "itens de cura", group = "ic", map = { 0xBD, 0x43A8, 20, 18 }, chunk = { 0x40, 0x49B0 },
    regions = {
      { 1, 1, 18, 2, align = "center", gap = 9, texts = { "Itens de cura" } },
      { 1, 4, 16, 5, align = "left", gap = 6, outline = 3, texts = { "Doce", "Suco" } },
      { 1, 7, 16, 8, align = "left", gap = 6, outline = 3, texts = { "Pão", "Leite" } },
      { 1, 10, 16, 11, align = "left", gap = 6, outline = 3, texts = { "Bolo", "Mel" } },
    } },
  { name = "pedras", group = "ie", map = { 0xBD, 0x4678, 20, 18 }, chunk = { 0x40, 0x5160 },
    regions = {
      { 1, 1, 18, 2, align = "center", gap = 9, texts = { "Pedras especiais" } },
      { 1, 4, 16, 5, align = "left", gap = 6, outline = 3, texts = { "Vida", "Espírito" } },
      { 1, 7, 16, 8, align = "left", gap = 6, outline = 3, texts = { "Chamas", "Olho" } },
      { 1, 10, 16, 11, align = "left", gap = 6, outline = 3, texts = { "Fênix", "Voo" } },
    } },
  { name = "aviso do turno inimigo", group = "a", map = { 0xBD, 0x55B0, 10, 4 }, chunk = { 0x48, 0x4000 },
    regions = { { 1, 1, 8, 2, align = "center", gap = 9, texts = { "Vez do inimigo" } } } },
  { name = "aviso do turno do jogador", group = "a", map = { 0xBD, 0x5600, 10, 4 }, chunk = { 0x48, 0x4000 },
    regions = { { 1, 1, 8, 2, align = "center", gap = 9, texts = { "Sua vez" } } } },
  { name = "menu do mapa", group = "s", map = { 0xBD, 0x4C18, 9, 12 }, chunk = { 0x40, 0x5E10 },
    regions = { { 0, 1, 8, 10, align = "center", gap = 9,
      texts = { "Ver time", "Salvar", "Carregar", "Objetivo", "Fim" } } } },
  { name = "tipos (Team show)", group = "v", map = { 0xBD, 0x4CF0, 20, 18 }, chunk = { 0x40, 0x6440 },
    regions = {
      { 1, 1, 18, 2, align = "center", gap = 9, texts = { "Time do jogador" } },
      { 6, 6, 13, 7, align = "center", texts = { "Agilidade" } },
      { 1, 9, 18, 10, align = "center", texts = { "Defesa", "Equilíbrio" } },
      { 1, 14, 18, 15, align = "center", gap = 8, texts = { "Superpoder", "Força" } },
    } },
  { name = "objetivo da fase", group = "w", map = { 0xBD, 0x5470, 20, 8 }, chunk = { 0x40, 0x7AD0 },
    regions = { { 1, 1, 18, 2, align = "left", gap = 9, texts = { "Objetivo" } } } },
  { name = "escolha do time", group = "t", map = { 0xBD, 0x63E8, 20, 18 }, chunk = { 0x41, 0x5770 },
    regions = {
      { 1, 1, 11, 2, align = "left", texts = { "Podem lutar" } },
      { 0, 15, 15, 16, align = "left", gap = 4, splitAt = { 82, 104 }, texts = { "Lutar", "Trocar", false, "Pág." } },
    } },
  { name = "Instituto", group = "c", map = { 0xBD, 0x5E48, 20, 9 }, chunk = { 0x41, 0x4AC0 },
    regions = { { 1, 1, 19, 2, align = "center", texts = { "Vantagens", "Dicas" } } } },
  { name = "BabyAlliance", group = "c", map = { 0xBD, 0x5FB0, 20, 9 }, chunk = { 0x41, 0x4AC0 },
    regions = { { 1, 1, 19, 2, align = "center", texts = { "Condições", "Evoluir" } } } },
  { name = "cidade", group = "c", map = { 0xBD, 0x5CE0, 20, 9 }, chunk = { 0x41, 0x4AC0 },
    regions = { { 8, 1, 19, 2, align = "center", texts = { "Prefeito", "Morador" } } } },
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

-- Trechos de tinta: faixas de linhas e, nelas, grupos separados por >= gapMin px vazios; cada
-- trecho é recortado pela própria tinta e ganha a linha de base (o fundo mais comum entre as
-- colunas: descendentes são minoria).
local function inkMask(canvas, w, h, ink, outline)
  local m = {}
  for y = 0, h - 1 do
    m[y] = {}
    for x = 0, w - 1 do
      local v = canvas[y][x] == ink
      if v and outline then
        for dy = -1, 1 do
          for dx = -1, 1 do
            local r = canvas[y + dy]
            if r and r[x + dx] == outline then v = false end
          end
        end
      end
      m[y][x] = v
    end
  end
  return m
end

local function findSegments(mask, w, h, gapMin, cuts)
  local canvas, ink = mask, true
  local segs = {}
  local function rowHasInk(y)
    for x = 0, w - 1 do if canvas[y][x] == ink then return true end end
    return false
  end
  local y = 0
  while y < h do
    if rowHasInk(y) then
      local y0 = y
      while y < h and rowHasInk(y) do y = y + 1 end
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
  for _, cut in ipairs(cuts or {}) do
    for i = #segs, 1, -1 do
      local g = segs[i]
      if g.x0 < cut and g.x1 >= cut then
        table.remove(segs, i)
        table.insert(segs, i, { x0 = cut, x1 = g.x1, y0 = g.y0, y1 = g.y1 })
        table.insert(segs, i, { x0 = g.x0, x1 = cut - 1, y0 = g.y0, y1 = g.y1 })
      end
    end
  end
  for _, g in ipairs(segs) do
    local y0, y1, x0, x1
    for yy = g.y0, g.y1 do
      for x = g.x0, g.x1 do
        if canvas[yy][x] == ink then
          y0 = y0 or yy; y1 = yy
          x0 = math.min(x0 or x, x); x1 = math.max(x1 or x, x)
        end
      end
    end
    g.y0, g.y1, g.x0, g.x1 = y0, y1, x0, x1
    local votes, best = {}, nil
    for x = x0, x1 do
      local b
      for yy = y0, y1 do if canvas[yy][x] == ink then b = yy end end
      if b then
        votes[b] = (votes[b] or 0) + 1
        if not best or votes[b] > votes[best] or (votes[b] == votes[best] and b > best) then best = b end
      end
    end
    g.base = best
  end
  return segs
end

-- Apaga as palavras originais da região e escreve os textos novos no canvas.
local function relabel(sc, rg, canvas, W, H, bg, ink)
  local mask = inkMask(canvas, W, H, ink, rg.outline)
  local segs = findSegments(mask, W, H, rg.gap or 7, rg.splitAt)
  if Menus.debug then
    for _, g in ipairs(segs) do
      io.stderr:write(("  trecho x %d-%d y %d-%d base %d\n"):format(g.x0, g.x1, g.y0, g.y1, g.base))
    end
  end
  if #segs ~= #rg.texts then
    error(("%s: %d trechos de texto achados, esperava %d"):format(sc.name, #segs, #rg.texts))
  end
  local plan = {}
  for i, s in ipairs(segs) do
    local t = rg.texts[i]
    if t then
      for y = s.y0, s.y1 do for x = s.x0, s.x1 do if mask[y][x] then canvas[y][x] = bg end end end
      local prev, nxt = segs[i - 1], segs[i + 1]
      local xmin = (prev and prev.y0 <= s.y1 and prev.y1 >= s.y0) and prev.x1 + 4 or 0
      local xmax = (nxt and nxt.y0 <= s.y1 and nxt.y1 >= s.y0) and nxt.x0 - 4 or W - 1
      plan[#plan + 1] = { t = t, s = s, xmin = xmin, xmax = xmax }
    end
  end
  for _, p in ipairs(plan) do
    local font, gap = "normal", 1
    local room = p.xmax - p.xmin + 1
    local tw = PixelFont.width(font, p.t, gap)
    if tw > room then gap = 0; tw = PixelFont.width(font, p.t, gap) end
    if tw > room then font, gap = "small", 1; tw = PixelFont.width(font, p.t, gap) end
    if tw > room then error(("%s: \"%s\" não cabe (%d > %d px)"):format(sc.name, p.t, tw, room)) end
    local x
    if rg.align == "left" then x = p.s.x0
    else x = math.floor((p.s.x0 + p.s.x1) / 2 - tw / 2 + 0.5) end
    x = math.max(p.xmin, math.min(x, p.xmax - tw + 1))
    -- normal: corpo nas linhas 2-8 da célula (base na 8); small: 2-6 (base na 6)
    local top = p.s.base - (font == "normal" and 8 or 6)
    PixelFont.draw(font, p.t, x, top, gap, function(px, py)
      if py >= 0 and py < H and px >= 0 and px < W then canvas[py][px] = ink end
    end)
  end
end

-- otherMaps: os outros mapas do mesmo grupo (os usos neles contam como fora das regiões).
function Menus.applyScreen(rom, sc, otherMaps)
  local mapBank, mapAddr, mw, mh = sc.map[1], sc.map[2], sc.map[3], sc.map[4]
  local mo = at(mapBank, mapAddr)
  local ao = mo + mw * mh                      -- atributos logo depois do mapa
  local function data(id) return readTile(rom, tileOffset(sc.chunk, id)) end
  -- 1) cada região: canvas com o que aparece na tela (espelhos aplicados), apaga e escreve
  local cellPx, origKey = {}, {}
  local bg
  for _, rg in ipairs(sc.regions) do
    local cx0, cy0, cx1, cy1 = rg[1], rg[2], rg[3], rg[4]
    local W, H = (cx1 - cx0 + 1) * 8, (cy1 - cy0 + 1) * 8
    local canvas = {}
    for y = 0, H - 1 do canvas[y] = {} end
    for cy = cy0, cy1 do
      for cx = cx0, cx1 do
        local i = cy * mw + cx
        local attr = rom:u8(ao + i)
        local fx, fy = math.floor(attr / 32) % 2 == 1, math.floor(attr / 64) % 2 == 1
        local px = data(rom:u8(mo + i))
        local shown = {}
        for y = 0, 7 do
          shown[y] = {}
          for x = 0, 7 do
            local v = px[fy and 7 - y or y][fx and 7 - x or x]
            shown[y][x] = v
            canvas[(cy - cy0) * 8 + y][(cx - cx0) * 8 + x] = v
          end
        end
        origKey[i] = key(tileBytes(shown))
      end
    end
    local count = { [0] = 0, 0, 0, 0 }
    for y = 0, H - 1 do for x = 0, W - 1 do count[canvas[y][x]] = count[canvas[y][x]] + 1 end end
    bg = 0
    for c = 0, 3 do if count[c] > count[bg] then bg = c end end
    relabel(sc, rg, canvas, W, H, bg, rg.ink or (bg ~= 0 and 0 or 3))
    for cy = cy0, cy1 do
      for cx = cx0, cx1 do
        local px = {}
        for y = 0, 7 do
          px[y] = {}
          for x = 0, 7 do px[y][x] = canvas[(cy - cy0) * 8 + y][(cx - cx0) * 8 + x] end
        end
        cellPx[cy * mw + cx] = px
      end
    end
  end
  -- 2) ids exclusivos: todos os usos (neste mapa e nos outros do grupo) estão dentro das regiões
  local inRegion, total = {}, {}
  for i = 0, mw * mh - 1 do
    local id = rom:u8(mo + i)
    total[id] = (total[id] or 0) + 1
    if cellPx[i] then inRegion[id] = (inRegion[id] or 0) + 1 end
  end
  for _, m in ipairs(otherMaps) do
    local o = at(m[1], m[2])
    for i = 0, m[3] * m[4] - 1 do
      local id = rom:u8(o + i)
      total[id] = (total[id] or 0) + 1
    end
  end
  local known, pool, seen, ids = {}, {}, {}, {}
  for id = 0x1F, 0, -1 do known[key(tileBytes(data(id)))] = id end      -- moldura comum
  for i in pairs(cellPx) do
    local id = rom:u8(mo + i)
    if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
  end
  table.sort(ids)
  for _, id in ipairs(ids) do
    if id >= 0x20 then
      local px, blank = data(id), true
      for y = 0, 7 do for x = 0, 7 do if px[y][x] ~= bg then blank = false end end end
      local k = key(tileBytes(px))
      if blank then known[k] = known[k] or id
      elseif inRegion[id] == total[id] then pool[#pool + 1] = id end
    end
  end
  -- 3) atribui ids e grava
  local newData, used, cells = {}, 0, {}
  for i in pairs(cellPx) do cells[#cells + 1] = i end
  table.sort(cells)
  for _, i in ipairs(cells) do
    local bytes = tileBytes(cellPx[i])
    local k = key(bytes)
    local id0 = rom:u8(mo + i)
    local exclusive = id0 >= 0x20 and inRegion[id0] == total[id0]
    local id
    if k == origKey[i] and not exclusive then
      id = id0
    elseif known[k] then
      id = known[k]
    elseif newData[k] then
      id = newData[k].id
    else
      used = used + 1
      id = pool[used]
      if not id then error(("%s: faltam tiles livres (%d disponíveis)"):format(sc.name, #pool)) end
      newData[k] = { id = id, bytes = bytes }
    end
    if id ~= id0 or k ~= origKey[i] then
      local attr = rom:u8(ao + i)
      rom:set(ao + i, attr - (math.floor(attr / 32) % 4) * 32)        -- sem espelho
    end
    rom:set(mo + i, id)
  end
  for _, d in pairs(newData) do rom:write(tileOffset(sc.chunk, d.id), d.bytes) end
  return used, #pool
end

function Menus.apply(rom)
  local report = {}
  for _, sc in ipairs(Menus.SCREENS) do
    local others = {}
    for _, o in ipairs(Menus.SCREENS) do
      if o ~= sc and o.group == sc.group then others[#others + 1] = o.map end
    end
    if Menus.debug then io.stderr:write("tela " .. sc.name .. "\n") end
    local used, pool = Menus.applyScreen(rom, sc, others)
    report[#report + 1] = ("%s: %d/%d tiles"):format(sc.name, used, pool)
  end
  return report
end

return Menus
