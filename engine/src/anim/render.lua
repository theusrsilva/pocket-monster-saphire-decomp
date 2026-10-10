-- Desenho da cena de ataque (src/anim/attack.lua) a partir da VRAM/OAM/paletas que ela monta.
--   Render.pixels(scene, plot)  -> quadro inteiro pixel a pixel (testes e capturas)
--   Render.new(scene):draw(...) -> LÖVE: fundo numa imagem atualizada por célula e sprites de um
--                                  atlas por banco/paleta (leve o bastante para o 3DS)
-- Na tela da cena a janela (mapa $9C00, LCDC $E7) ou o fundo (mapa $9C00, LCDC $8F) cobre os
-- 160x144 a partir de (0, 0); sprites 8x16; o índice menor da OAM fica por cima.
local bit = require("src.util.bit")
local band = bit.band
local floor = math.floor

local Render = {}
Render.__index = Render

local function rgb(lo, hi)
  local v = lo + hi * 256
  return (v % 32) / 31, (floor(v / 32) % 32) / 31, (floor(v / 1024) % 32) / 31
end

local function pix(vr, base, px, py)
  local lo, hi = vr[base + py * 2], vr[base + py * 2 + 1]
  local b = 2 ^ (7 - px)
  return (floor(lo / b) % 2) + 2 * (floor(hi / b) % 2)
end

-- Tile do mapa $9C00 (endereçamento $8800 com sinal).
local function bgTile(s, tx, ty)
  local mi = 0x1C00 + ty * 32 + tx
  local idx, attr = s.V[0][mi], s.V[1][mi]
  local base = 0x1000 + (idx >= 128 and idx - 256 or idx) * 16
  return base, attr
end

-- Quadro inteiro (com o limite de 10 sprites por linha do hardware, como no executor; noLimit
-- tira o limite, como no desenho em LÖVE).
function Render.pixels(s, plot, noLimit)
  local bgc, obc = {}, {}
  for p = 0, 7 do
    for c = 0, 3 do
      bgc[p * 4 + c] = { rgb(s.bgpal[p * 8 + c * 2], s.bgpal[p * 8 + c * 2 + 1]) }
      obc[p * 4 + c] = { rgb(s.obpal[p * 8 + c * 2], s.obpal[p * 8 + c * 2 + 1]) }
    end
  end
  local line, prio = {}, {}
  for y = 0, 143 do
    for x = 0, 159 do
      local base, attr = bgTile(s, floor(x / 8), floor(y / 8))
      local px, py = x % 8, y % 8
      if band(attr, 0x40) ~= 0 then py = 7 - py end
      if band(attr, 0x20) ~= 0 then px = 7 - px end
      local c = pix(band(attr, 8) ~= 0 and s.V[1] or s.V[0], base, px, py)
      line[x] = bgc[band(attr, 7) * 4 + c]
      prio[x] = (c ~= 0) and ((band(attr, 0x80) ~= 0) and 2 or 1) or 0
    end
    local drawn = {}
    for i = 0, 39 do
      local sy = s.oam[i * 4] - 16
      if y >= sy and y < sy + 16 then
        drawn[#drawn + 1] = i
        if #drawn == 10 and not noLimit then break end
      end
    end
    for k = #drawn, 1, -1 do
      local i = drawn[k]
      local sy, sx = s.oam[i * 4] - 16, s.oam[i * 4 + 1] - 8
      local tile, attr = band(s.oam[i * 4 + 2], 0xFE), s.oam[i * 4 + 3]
      local row = y - sy
      if band(attr, 0x40) ~= 0 then row = 15 - row end
      local vr = band(attr, 8) ~= 0 and s.V[1] or s.V[0]
      for px = 0, 7 do
        local x = sx + px
        if x >= 0 and x < 160 then
          local c = pix(vr, tile * 16, band(attr, 0x20) ~= 0 and 7 - px or px, row)
          if c ~= 0 then
            local behind = prio[x] == 2 or (band(attr, 0x80) ~= 0 and prio[x] == 1)
            if not behind then line[x] = obc[band(attr, 7) * 4 + c] end
          end
        end
      end
    end
    for x = 0, 159 do local c = line[x]; plot(x, y, c[1], c[2], c[3]) end
  end
end

-- ---------------------------------------------------------------------------------------------
-- LÖVE

function Render.new(scene)
  local self = setmetatable({ s = scene, atlas = {}, bgData = love.image.newImageData(160, 144),
    cellsDirty = true }, Render)
  return self
end

-- Fundo: redesenha as células marcadas (mapa ou tiles alterados); paleta nova redesenha tudo.
function Render:updateBG()
  local s = self.s
  local all = s.dirtyMap or self.cellsDirty
  if not all and next(s.dirtyTiles) == nil and next(s.dirtyCells) == nil then return end
  local d = self.bgData
  local cols = {}
  for p = 0, 7 do
    for c = 0, 3 do cols[p * 4 + c] = { rgb(s.bgpal[p * 8 + c * 2], s.bgpal[p * 8 + c * 2 + 1]) } end
  end
  local changed = false
  for ty = 0, 17 do
    for tx = 0, 19 do
      local base, attr = bgTile(s, tx, ty)
      local bank = band(attr, 8) ~= 0 and 1 or 0
      local key = tx + ty * 20
      local mi = ty * 32 + tx
      if all or s.dirtyTiles[bank * 384 + floor(base / 16)] or s.dirtyCells[mi]
          or s.dirtyCells[mi + 0x400] then
        local vr = s.V[bank]
        for py = 0, 7 do
          for px = 0, 7 do
            local qx, qy = px, py
            if band(attr, 0x20) ~= 0 then qx = 7 - px end
            if band(attr, 0x40) ~= 0 then qy = 7 - py end
            local c = cols[band(attr, 7) * 4 + pix(vr, base, qx, qy)]
            d:setPixel(tx * 8 + px, ty * 8 + py, c[1], c[2], c[3], 1)
          end
        end
        changed = true
      end
    end
  end
  s.dirtyMap = false
  self.cellsDirty = false
  for k in pairs(s.dirtyCells) do s.dirtyCells[k] = nil end
  if changed then
    if self.bg and self.bg.replacePixels then
      self.bg:replacePixels(d)
    else
      self.bg = love.graphics.newImage(d)
      self.bg:setFilter("nearest", "nearest")
    end
  end
end

-- Sprites: um atlas 128x192 (os 384 tiles de um banco da VRAM) por banco e paleta, com os tiles
-- redesenhados só quando mudam (versão do tile e da paleta) e a textura atualizada uma vez por quadro.
-- Quads de linhas de um tile (r0..r1) no atlas, em cache.
local quads = {}
local function tileQuad(t, r0, r1)
  local k = (t * 8 + r0) * 8 + r1
  local q = quads[k]
  if not q then
    q = love.graphics.newQuad((t % 16) * 8, math.floor(t / 16) * 8 + r0, 8, r1 - r0 + 1, 128, 192)
    quads[k] = q
  end
  return q
end

function Render:atlasTile(bank, t, pal)
  local s = self.s
  local key = bank * 8 + pal
  local a = self.atlas[key]
  if not a then
    a = { data = love.image.newImageData(128, 192), ver = {}, pal = -1 }
    self.atlas[key] = a
  end
  local pv = s.obpalVer[pal] or 0
  if a.pal ~= pv then a.pal = pv; a.ver = {} end
  local tv = s.tileVer[bank * 384 + t] or 0
  if a.ver[t] ~= tv then
    a.ver[t] = tv
    local d, vr = a.data, s.V[bank]
    local cols = {}
    for c = 1, 3 do cols[c] = { rgb(s.obpal[pal * 8 + c * 2], s.obpal[pal * 8 + c * 2 + 1]) } end
    local ox, oy = (t % 16) * 8, math.floor(t / 16) * 8
    for py = 0, 7 do
      for px = 0, 7 do
        local c = pix(vr, t * 16, px, py)
        if c ~= 0 then d:setPixel(ox + px, oy + py, cols[c][1], cols[c][2], cols[c][3], 1)
        else d:setPixel(ox + px, oy + py, 0, 0, 0, 0) end
      end
    end
    a.changed = true
  end
  return a
end

-- Linhas visíveis de cada sprite: o hardware mostra só os 10 primeiros (ordem da OAM) por linha.
local function visibleRows(oam)
  local rows, count = {}, {}
  for i = 0, 39 do
    local sy = oam[i * 4] - 16
    if sy > -16 and sy < 144 then
      local r = {}
      for l = 0, 15 do
        local y = sy + l
        if y >= 0 and y < 144 then
          local c = (count[y] or 0) + 1
          count[y] = c
          if c <= 10 then r[l] = true end
        end
      end
      rows[i] = r
    end
  end
  return rows
end

function Render:draw(x, y, scale)
  local s = self.s
  self:updateBG()
  for k in pairs(s.dirtyTiles) do s.dirtyTiles[k] = nil end
  love.graphics.setColor(1, 1, 1)
  if self.bg then love.graphics.draw(self.bg, x, y, 0, scale, scale) end
  local oam = s.oam
  local rows = visibleRows(oam)
  local list = {}
  for i = 39, 0, -1 do
    local sy, sx = oam[i * 4] - 16, oam[i * 4 + 1] - 8
    if rows[i] and sx > -8 and sx < 160 then
      local tile, attr = band(oam[i * 4 + 2], 0xFE), oam[i * 4 + 3]
      local bank, pal = band(attr, 8) ~= 0 and 1 or 0, band(attr, 7)
      local a = self:atlasTile(bank, tile, pal)
      self:atlasTile(bank, tile + 1, pal)
      list[#list + 1] = { a, tile, attr, sx, sy, rows[i] }
    end
  end
  for _, a in pairs(self.atlas) do
    if a.changed then
      a.changed = false
      if a.img and a.img.replacePixels then
        a.img:replacePixels(a.data)
      else
        a.img = love.graphics.newImage(a.data)
        a.img:setFilter("nearest", "nearest")
      end
    end
  end
  for _, e in ipairs(list) do
    local a, tile, attr, sx, sy, vis = e[1], e[2], e[3], e[4], e[5], e[6]
    local fx, fy = band(attr, 0x20) ~= 0, band(attr, 0x40) ~= 0
    local kx, ky = fx and -scale or scale, fy and -scale or scale
    local px = x + (sx + (fx and 8 or 0)) * scale
    for h = 0, 1 do
      local t = tile + ((h == 1) ~= fy and 1 or 0)
      local l = 0
      while l <= 7 do
        if vis[h * 8 + l] then
          local l1 = l
          while l1 < 7 and vis[h * 8 + l1 + 1] do l1 = l1 + 1 end
          local base = sy + h * 8
          if fy then
            love.graphics.draw(a.img, tileQuad(t, 7 - l1, 7 - l), px, y + (base + l1 + 1) * scale, 0, kx, ky)
          else
            love.graphics.draw(a.img, tileQuad(t, l, l1), px, y + (base + l) * scale, 0, kx, ky)
          end
          l = l1 + 1
        else
          l = l + 1
        end
      end
    end
  end
end

return Render
