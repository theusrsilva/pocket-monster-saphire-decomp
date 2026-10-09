-- Opções da tela de título ("LOAD" / "EXIT"), que aparece depois de uma derrota. São sprites 8x16:
-- 7 sprites lado a lado = 56x16 px por palavra, 14 tiles seguidos (cima, baixo, cima, baixo...) no
-- banco $85. Cada palavra tem dois quadros da animação. Estilo: preenchimento cor 1, contorno cor 2,
-- sombra cor 3 (embaixo e à direita), fundo cor 0 (transparente). Ver docs/FINDINGS.md, "Título".
local Buffer = require("src.romhack.buffer")
local PixelFont = require("src.romhack.pixelfont")

local Title = {}
local at = Buffer.at

Title.WORDS = {
  { "CARREGAR", { 0x5510, 0x55F0 } },   -- LOAD (dois quadros)
  { "SAIR", { 0x56C0, 0x57A0 } },       -- EXIT
}

local ROWS = { 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6 }   -- maiúscula de 7 linhas -> 12

-- Máscara das letras: fonte normal em maiúsculas, esticada na vertical e com traço de 2 px.
local function mask(text, gap)
  local glyphs, w = {}, 0
  for _, ch in ipairs(PixelFont.chars(text:upper())) do
    local g = PixelFont.glyph("normal", ch)
    if g then
      glyphs[#glyphs + 1] = { g = g, x = w }
      w = w + g.w + 1 + gap
    end
  end
  w = w - gap
  local m = {}
  for _, it in ipairs(glyphs) do
    for ny, src in ipairs(ROWS) do
      local row = it.g.px[src + 2]
      if row then
        for cx in pairs(row) do
          m[ny - 1] = m[ny - 1] or {}
          m[ny - 1][it.x + cx] = true
          m[ny - 1][it.x + cx + 1] = true
        end
      end
    end
  end
  return m, w
end

function Title.render(text)
  local m, w = mask(text, 1)
  if w + 2 > 56 then m, w = mask(text, 0) end
  if w + 2 > 56 then error("título: \"" .. text .. "\" não cabe") end
  local img = {}
  for y = 0, 15 do img[y] = {} for x = 0, 55 do img[y][x] = 0 end end
  local ox, oy = math.floor((56 - w) / 2), 2
  local function isM(x, y) return m[y - oy] and m[y - oy][x - ox] end
  for y = 0, 15 do
    for x = 0, 55 do
      if isM(x, y) then img[y][x] = 1 end
    end
  end
  for y = 0, 15 do                                   -- contorno
    for x = 0, 55 do
      if img[y][x] == 0 then
        for dy = -1, 1 do for dx = -1, 1 do if isM(x + dx, y + dy) then img[y][x] = 2 end end end
      end
    end
  end
  for y = 15, 1, -1 do                               -- sombra
    for x = 55, 1, -1 do
      if img[y][x] == 0 and img[y - 1][x - 1] ~= 0 and img[y - 1][x - 1] ~= 3 then img[y][x] = 3 end
    end
  end
  return img
end

-- Botões do título ("NEW GAME" / "RECORDS"): 10 sprites 8x16 = 80x16 px em $8C:$5310 e $8C:$5460,
-- letras cor 3 (6 linhas, traço de 2 px) sobre a pílula cor 1, nas linhas 5-10, x 13-76.
Title.BUTTONS = { { "NOVO JOGO", 0x5310 }, { "RECORDES", 0x5460 } }
local BROWS = { 0, 1, 3, 4, 5, 6 }                   -- 7 linhas -> 6 (sem a 3ª)

local function buttonMask(text, gap)
  local glyphs, w = {}, 0
  for _, ch in ipairs(PixelFont.chars(text:upper())) do
    local g = PixelFont.glyph("normal", ch)
    if g then glyphs[#glyphs + 1] = { g = g, x = w }; w = w + g.w + 1 + gap end
  end
  local m = {}
  for _, it in ipairs(glyphs) do
    for ny, src in ipairs(BROWS) do
      local row = it.g.px[src + 2]
      if row then
        for cx in pairs(row) do
          m[ny - 1] = m[ny - 1] or {}
          m[ny - 1][it.x + cx] = true
          m[ny - 1][it.x + cx + 1] = true
        end
      end
    end
  end
  return m, w - gap
end

local function readSprites(rom, base, n)
  local img = {}
  for y = 0, 15 do img[y] = {} end
  for k = 0, n - 1 do
    for h = 0, 1 do
      local o = at(0x8C, base) + k * 32 + h * 16
      for y = 0, 7 do
        local lo, hi = rom:u8(o + 2 * y), rom:u8(o + 2 * y + 1)
        for x = 0, 7 do
          local bit = 2 ^ (7 - x)
          img[h * 8 + y][k * 8 + x] = (math.floor(lo / bit) % 2) + 2 * (math.floor(hi / bit) % 2)
        end
      end
    end
  end
  return img
end

function Title.buttons(rom)
  for _, b in ipairs(Title.BUTTONS) do
    local img = readSprites(rom, b[2], 10)
    for y = 5, 10 do for x = 13, 76 do if img[y][x] == 3 then img[y][x] = 1 end end end
    local m, w = buttonMask(b[1], 2)
    if w > 63 then m, w = buttonMask(b[1], 1) end
    if w > 63 then error("título: \"" .. b[1] .. "\" não cabe") end
    local ox = 13 + math.floor((64 - w) / 2)
    for y, row in pairs(m) do for x in pairs(row) do img[5 + y][ox + x] = 3 end end
    for k = 0, 9 do
      for h = 0, 1 do
        local o = at(0x8C, b[2]) + k * 32 + h * 16
        for y = 0, 7 do
          local lo, hi = 0, 0
          for x = 0, 7 do
            local c = img[h * 8 + y][k * 8 + x]
            if c % 2 == 1 then lo = lo + 2 ^ (7 - x) end
            if c >= 2 then hi = hi + 2 ^ (7 - x) end
          end
          rom:set(o + 2 * y, lo)
          rom:set(o + 2 * y + 1, hi)
        end
      end
    end
  end
end

function Title.apply(rom)
  Title.buttons(rom)
  for _, wd in ipairs(Title.WORDS) do
    local img = Title.render(wd[1])
    for _, base in ipairs(wd[2]) do
      for k = 0, 6 do
        for h = 0, 1 do
          local o = at(0x85, base) + (k * 2 + h) * 16
          for y = 0, 7 do
            local lo, hi = 0, 0
            for x = 0, 7 do
              local c = img[h * 8 + y][k * 8 + x]
              if c % 2 == 1 then lo = lo + 2 ^ (7 - x) end
              if c >= 2 then hi = hi + 2 ^ (7 - x) end
            end
            rom:set(o + 2 * y, lo)
            rom:set(o + 2 * y + 1, hi)
          end
        end
      end
    end
  end
  return #Title.WORDS + #Title.BUTTONS
end

return Title
