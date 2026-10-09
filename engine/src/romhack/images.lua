-- Textos em imagem redesenhados em português com a fonte própria (src/romhack/pixelfont.lua).
-- Formato (ver docs/FINDINGS.md, "Texto em imagem"): tabela [banco, 00, ptr u16] por id; a imagem
-- tem W x H tiles 2bpp em ordem de linhas e é gravada no mesmo lugar (mesmo tamanho).
-- As cores (fundo e letra) são as que a imagem original usa.
local Buffer = require("src.romhack.buffer")
local PixelFont = require("src.romhack.pixelfont")
local Names = require("src.game.names")

local Images = {}
local at = Buffer.at

-- Nomes curtos quando o nome traduzido não cabe de jeito nenhum na imagem.
Images.SHORT = {
  ["Onda Eletromagnética"] = "Onda Eletromag.",
}

-- Categorias: banco/tabela, primeiro e último id, tamanho em tiles e o texto de cada id.
local function categories()
  local function ginasio(t) return "Ginásio " .. t end
  return {
    { name = "golpes", bank = 0x79, table = 0x4000, first = 0x01, last = 0x58, w = 7, h = 2,
      text = function(id) local n = Names.skills[id]; return n and n.pt end },
    { name = "espécies", bank = 0xF9, table = 0x4000, first = 0x01, last = 0x4B, w = 7, h = 2,
      text = function(id) local n = Names.species[id]; return n and (n.official or n.en) end },
    { name = "lugares", bank = 0x7C, table = 0x4000, first = 0x00, last = 0x20, w = 9, h = 2,
      text = function(id) local n = Names.places[id + 1]; return n and n.pt end },
    { name = "itens-chave", bank = 0x7C, table = 0x40A8, first = 0x01, last = 0x06, w = 7, h = 2,
      text = function(id) local n = Names.keyItems[id - 1]; return n and n.pt end },
    { name = "ginásios", bank = 0x7C, table = 0x40C4, first = 0x00, last = 0x05, w = 7, h = 2,
      text = function(id)
        return ginasio(({ "Ifleaf", "Selvagem", "Cipreste", "Nova", "Lótus Vermelho", "Cravo" })[id + 1])
      end },
    { name = "objetivo", bank = 0x7C, table = 0x40DC, first = 0x00, last = 0x02, w = 18, h = 2, keep = 2,
      text = function() return "Derrote todos os inimigos" end },
  }
end

-- Lê a imagem como matriz de cores [y][x].
local function readImage(rom, o, w, h)
  local px = {}
  for t = 0, w * h - 1 do
    local tx, ty = (t % w) * 8, math.floor(t / w) * 8
    for y = 0, 7 do
      local lo, hi = rom:u8(o + t * 16 + 2 * y), rom:u8(o + t * 16 + 2 * y + 1)
      px[ty + y] = px[ty + y] or {}
      for x = 0, 7 do
        local bit = 2 ^ (7 - x)
        px[ty + y][tx + x] = (math.floor(lo / bit) % 2) + 2 * (math.floor(hi / bit) % 2)
      end
    end
  end
  return px
end

local function writeImage(rom, o, w, h, px)
  for t = 0, w * h - 1 do
    local tx, ty = (t % w) * 8, math.floor(t / w) * 8
    for y = 0, 7 do
      local lo, hi = 0, 0
      for x = 0, 7 do
        local c = px[ty + y][tx + x]
        if c % 2 == 1 then lo = lo + 2 ^ (7 - x) end
        if c >= 2 then hi = hi + 2 ^ (7 - x) end
      end
      rom:set(o + t * 16 + 2 * y, lo)
      rom:set(o + t * 16 + 2 * y + 1, hi)
    end
  end
end

-- Divide em duas linhas pelo espaço que deixa a linha mais larga mais curta.
local function split2(font, s, gap)
  local best
  local pos = 1
  while true do
    local i = s:find(" ", pos, true)
    if not i then break end
    local a, b = s:sub(1, i - 1), s:sub(i + 1)
    local m = math.max(PixelFont.width(font, a, gap), PixelFont.width(font, b, gap))
    if not best or m < best.m then best = { a, b, m = m } end
    pos = i + 1
  end
  return best
end

-- Monta o texto numa área de pw x ph pixels. Devolve lista de {s, font, x, y, gap} ou nil.
function Images.layout(s, pw, ph)
  local function one(font, gap)
    local w = PixelFont.width(font, s, gap)
    if w <= pw - 2 then
      local top = font == "normal" and math.floor((ph - 16) / 2) + 3 or math.floor((ph - 8) / 2) - 1
      if ph < 16 then top = font == "normal" and -1 or -1 end
      return { { s = s, font = font, x = math.floor((pw - w) / 2), y = top, gap = gap } }
    end
  end
  local function two(gap)
    if ph < 16 then return end
    local sp = split2("small", s, gap)
    if sp and sp.m <= pw - 2 then
      local wa, wb = PixelFont.width("small", sp[1], gap), PixelFont.width("small", sp[2], gap)
      local y0 = math.floor((ph - 16) / 2)
      return { { s = sp[1], font = "small", x = math.floor((pw - wa) / 2), y = y0, gap = gap },
               { s = sp[2], font = "small", x = math.floor((pw - wb) / 2), y = y0 + 8, gap = gap } }
    end
  end
  return one("normal", 1) or two(1) or one("small", 1) or one("normal", 0) or two(0) or one("small", 0)
end

local function render(rom, o, cat, s)
  local w, h = cat.w, cat.h
  local px = readImage(rom, o, w, h)
  local keepW = (cat.keep or 0) * 8
  -- cores: fundo = a mais comum na área do texto, letra = a segunda mais comum
  local count = { [0] = 0, 0, 0, 0 }
  for y = 0, h * 8 - 1 do for x = keepW, w * 8 - 1 do count[px[y][x]] = count[px[y][x]] + 1 end end
  local bg, ink = 0, nil
  for c = 0, 3 do if count[c] > count[bg] then bg = c end end
  for c = 0, 3 do if c ~= bg and (not ink or count[c] > count[ink]) then ink = c end end
  if count[ink] == 0 then ink = (bg == 0) and 3 or 0 end
  local lines = Images.layout(Images.SHORT[s] or s, w * 8 - keepW, h * 8)
  if not lines then return false end
  for y = 0, h * 8 - 1 do for x = keepW, w * 8 - 1 do px[y][x] = bg end end
  for _, l in ipairs(lines) do
    PixelFont.draw(l.font, l.s, keepW + l.x, l.y, l.gap, function(x, y)
      if y >= 0 and y < h * 8 and x >= keepW and x < w * 8 then px[y][x] = ink end
    end)
  end
  writeImage(rom, o, w, h, px)
  return true
end

-- Redesenha todas as categorias. Devolve { [categoria] = n, falhas = {...} }.
function Images.apply(rom)
  local report = { falhas = {} }
  for _, cat in ipairs(categories()) do
    local done, n = {}, 0
    for id = cat.first, cat.last do
      local e = at(cat.bank, cat.table) + id * 4
      local bank, ptr = rom:u8(e), rom:u16(e + 2)
      local s = cat.text(id)
      if s and ptr >= 0x4000 and ptr < 0x8000 then
        local o = at(bank, ptr)
        if not done[o] then
          done[o] = true
          if render(rom, o, cat, s) then n = n + 1
          else report.falhas[#report.falhas + 1] = cat.name .. ": " .. s end
        end
      end
    end
    report[cat.name] = n
  end
  return report
end

return Images
