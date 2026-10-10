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

function Scene:draw(x, y, scale)
  self.r:draw(x, y, scale)
end

return Scene
