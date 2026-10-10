-- Cena de ataque original no jogo: lógica em src/anim/attack.lua, desenho em src/anim/render.lua,
-- dados do recorte da ROM gravado pelo importador (generated/attack.bin, src/anim/slice.lua).
local Attack = require("src.anim.attack")
local Render = require("src.anim.render")
local Slice = require("src.anim.slice")

local Scene = {}
Scene.__index = Scene

Scene.FILE = "generated/attack.bin"
local reader

function Scene.available()
  return love.filesystem.getInfo(Scene.FILE) ~= nil
end

-- ev: ver Attack.new. onMusic(id): a cena troca a música (driver de som, $FFF7).
function Scene.new(ev, onMusic)
  reader = reader or Slice.load(love.filesystem.read(Scene.FILE))
  local a = Attack.new(reader, ev)
  a.onMusic = onMusic
  return setmetatable({ a = a, r = Render.new(a), acc = 0, done = false }, Scene)
end

-- Limite de segurança: algumas combinações de animação não terminam (o código original também
-- não, conferido no executor GBC); depois de 1 minuto a cena é encerrada.
Scene.MAX_FRAMES = 60 * 60

-- Um quadro do jogo original. Devolve false quando a cena acabou.
function Scene:step()
  if self.done then return false end
  if not self.a:step() or self.a.frames >= Scene.MAX_FRAMES then self.done = true end
  return not self.done
end

-- No ritmo do original (60 quadros por segundo).
function Scene:update(dt)
  self.acc = math.min(self.acc + dt, 4 / 60)
  while self.acc >= 1 / 60 do
    self.acc = self.acc - 1 / 60
    if not self:step() then return false end
  end
  return true
end

-- Sprite de luta da espécie (personagem $7C + espécie, animação 1, primeiro quadro), como na
-- tela de Estado do original. Devolve uma ImageData recortada (fundo transparente) ou nil.
local sprites = {}
function Scene.sprite(species)
  if sprites[species] ~= nil then return sprites[species] or nil end
  local ok, img = pcall(function()
    reader = reader or Slice.load(love.filesystem.read(Scene.FILE))
    local a = Attack.machine(reader)
    local M = a.M
    M[0xC905], M[0xC985] = species, species
    M[0xDB00], M[0xDB0F], M[0xDB10] = 1, 0x7C + species, 1
    M[0xDB01], M[0xDB03], M[0xDB2D], M[0xDB2E] = 0x50, 0x50, 0x20, 0x80
    a:updateObjects()
    a:vblank()
    M[0xC36A], M[0xC36C] = 1, 0
    a:buildOAM()
    a:vblank()
    local d = love.image.newImageData(160, 144)
    local minx, miny, maxx, maxy = 160, 144, -1, -1
    local Render = require("src.anim.render")
    for k = 0, 63, 2 do a.bgpal[k], a.bgpal[k + 1] = 0x1F, 0x7C end    -- fundo magenta = transparente
    Render.pixels(a, function(x, y, r, g, b)
      if not (r == 1 and g == 0 and b == 1) then
        d:setPixel(x, y, r, g, b, 1)
        minx, miny = math.min(minx, x), math.min(miny, y)
        maxx, maxy = math.max(maxx, x), math.max(maxy, y)
      else
        d:setPixel(x, y, 0, 0, 0, 0)
      end
    end, true)
    if maxx < 0 then return false end
    local out = love.image.newImageData(maxx - minx + 1, maxy - miny + 1)
    out:paste(d, 0, 0, minx, miny, maxx - minx + 1, maxy - miny + 1)
    return out
  end)
  sprites[species] = ok and img or false
  return sprites[species] or nil
end

function Scene:draw(x, y, scale)
  self.r:draw(x, y, scale)
end

return Scene
