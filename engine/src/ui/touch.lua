-- Controle na tela (Android/iOS sem controle físico): direcional à esquerda, A e B à direita e
-- START em cima. Some quando um controle é usado e volta no próximo toque. Os toques fora dos
-- botões continuam valendo como cliques (menus, casas do mapa), como no PC.
local Pad = require("src.ui.pad")

local Touch = { enabled = false, touches = {} }

local function layout(w, h)
  local r = math.floor(math.min(w, h) * 0.10)
  return {
    r = r,
    dpad = { x = math.floor(r * 1.9), y = h - math.floor(r * 1.9), r = math.floor(r * 1.5) },
    { id = "a", key = "z", label = "A", x = w - math.floor(r * 1.2), y = h - math.floor(r * 2.3), r = math.floor(r * 0.8) },
    { id = "b", key = "x", label = "B", x = w - math.floor(r * 2.8), y = h - math.floor(r * 1.2), r = math.floor(r * 0.8) },
    { id = "start", key = "pause", label = "START", x = w - math.floor(r * 1.4), y = h - math.floor(r * 4.0),
      r = math.floor(r * 0.45), wide = true },
  }
end

function Touch.visible() return Touch.enabled and Pad.last ~= "pad" end

local function dirAt(L, x, y)
  local d = L.dpad
  local dx, dy = x - d.x, y - d.y
  if dx * dx + dy * dy > (d.r * 1.3) ^ 2 or dx * dx + dy * dy < (d.r * 0.18) ^ 2 then return nil end
  if math.abs(dx) > math.abs(dy) then return dx > 0 and "right" or "left" end
  return dy > 0 and "down" or "up"
end

local function buttonAt(L, x, y)
  for _, b in ipairs(L) do
    local rx, ry = b.wide and b.r * 2.2 or b.r * 1.25, b.r * 1.25
    if math.abs(x - b.x) <= rx and math.abs(y - b.y) <= ry then return b end
  end
end

-- O ponto cai num botão do controle na tela? (para não virar clique também)
function Touch.inside(x, y)
  if not Touch.visible() then return false end
  local w, h = love.graphics.getDimensions()
  local L = layout(w, h)
  return dirAt(L, x, y) ~= nil or buttonAt(L, x, y) ~= nil
end

local function setDir(id, dir)
  local t = Touch.touches[id]
  if t and t.dir == dir then return end
  Touch.touches[id] = dir and { dir = dir } or nil
  if Pad.hold and Pad.hold.src == "touch" .. tostring(id) then Pad.hold = nil end
  if dir then
    Pad.hold = { key = dir, src = "touch" .. tostring(id), t = -Pad.REPEAT_DELAY }
    love.keypressed(dir)
  end
end

-- Devolve true se o toque foi do controle na tela.
function Touch.pressed(id, x, y)
  if not Touch.enabled then return false end
  local was = Pad.last
  Pad.last = "touch"
  if was == "pad" then return false end          -- o primeiro toque só mostra o controle de novo
  local w, h = love.graphics.getDimensions()
  local L = layout(w, h)
  local dir = dirAt(L, x, y)
  if dir then setDir(id, dir) return true end
  local b = buttonAt(L, x, y)
  if b then
    Touch.touches[id] = { button = b.id }
    love.keypressed(b.key)
    return true
  end
  return false
end

function Touch.moved(id, x, y)
  local t = Touch.touches[id]
  if not t or not t.dir then return end
  local w, h = love.graphics.getDimensions()
  setDir(id, dirAt(layout(w, h), x, y))
end

function Touch.released(id)
  if Touch.touches[id] then setDir(id, nil) end
  Touch.touches[id] = nil
end

function Touch.draw(font)
  if not Touch.visible() then return end
  local w, h = love.graphics.getDimensions()
  local L = layout(w, h)
  local held = {}
  for _, t in pairs(Touch.touches) do held[t.dir or t.button] = true end
  local function base(on) love.graphics.setColor(0.02, 0.05, 0.2, on and 0.7 or 0.4) end
  local function edge() love.graphics.setColor(1, 1, 1, 0.55); love.graphics.setLineWidth(2) end
  -- direcional: cruz
  local d = L.dpad
  local a = math.floor(d.r * 0.36)
  base(false)
  love.graphics.rectangle("fill", d.x - a, d.y - d.r, a * 2, d.r * 2, 6, 6)
  love.graphics.rectangle("fill", d.x - d.r, d.y - a, d.r * 2, a * 2, 6, 6)
  edge()
  love.graphics.polygon("line", d.x - a, d.y - d.r, d.x + a, d.y - d.r, d.x + a, d.y - a, d.x + d.r, d.y - a,
    d.x + d.r, d.y + a, d.x + a, d.y + a, d.x + a, d.y + d.r, d.x - a, d.y + d.r, d.x - a, d.y + a,
    d.x - d.r, d.y + a, d.x - d.r, d.y - a, d.x - a, d.y - a)
  for _, v in ipairs({ { "up", 0, -1 }, { "down", 0, 1 }, { "left", -1, 0 }, { "right", 1, 0 } }) do
    local cx, cy = d.x + v[2] * d.r * 0.66, d.y + v[3] * d.r * 0.66
    local t = a * 0.6
    love.graphics.setColor(1, 1, 1, held[v[1]] and 1 or 0.7)
    love.graphics.polygon("fill", cx + v[2] * t, cy + v[3] * t,
      cx - v[2] * t * 0.5 + v[3] * t, cy - v[3] * t * 0.5 + v[2] * t,
      cx - v[2] * t * 0.5 - v[3] * t, cy - v[3] * t * 0.5 - v[2] * t)
  end
  -- botões
  love.graphics.setFont(font)
  for _, b in ipairs(L) do
    base(held[b.id])
    if b.wide then
      love.graphics.rectangle("fill", b.x - b.r * 2.2, b.y - b.r, b.r * 4.4, b.r * 2, b.r, b.r)
      edge()
      love.graphics.rectangle("line", b.x - b.r * 2.2, b.y - b.r, b.r * 4.4, b.r * 2, b.r, b.r)
    else
      love.graphics.circle("fill", b.x, b.y, b.r)
      edge()
      love.graphics.circle("line", b.x, b.y, b.r)
    end
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf(b.label, b.x - b.r * 2.2, b.y - font:getHeight() / 2, b.r * 4.4, "center")
  end
  love.graphics.setLineWidth(1)
end

return Touch
