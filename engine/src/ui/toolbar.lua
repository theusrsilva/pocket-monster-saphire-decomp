-- Barra de botões do PC (canto de cima): música, tela cheia, minimizar e configuração, com mouse
-- (e as teclas M, F11, F1). Desenhada por cima da tela do jogo.
local Options = require("src.game.options")
local I18n = require("src.game.i18n")

local Toolbar = { x = 0, y = 0, size = 26, gap = 4, hover = nil }

local function L(pt, en) return I18n.lang == "en" and en or pt end

Toolbar.items = {
  { id = "music", tip = function() return Options.get("music") and L("Música: ligada (M)", "Music: on (M)")
      or L("Música: desligada (M)", "Music: off (M)") end },
  { id = "fullscreen", tip = function() return L("Tela cheia (F11)", "Fullscreen (F11)") end },
  { id = "minimize", tip = function() return L("Minimizar", "Minimize") end },
  { id = "config", tip = function() return L("Configuração (F1)", "Settings (F1)") end },
}

function Toolbar.width()
  return #Toolbar.items * (Toolbar.size + Toolbar.gap) - Toolbar.gap
end

-- Botão sob (mx, my), ou nil.
function Toolbar.hit(mx, my)
  local s, g = Toolbar.size, Toolbar.gap
  if my < Toolbar.y or my > Toolbar.y + s then return nil end
  for i, it in ipairs(Toolbar.items) do
    local bx = Toolbar.x + (i - 1) * (s + g)
    if mx >= bx and mx <= bx + s then return it.id end
  end
end

local function icon(id, x, y, s, disabled)
  local c = disabled and 0.45 or 1
  love.graphics.setColor(c, c, c)
  love.graphics.setLineWidth(2)
  local cx, cy = x + s / 2, y + s / 2
  if id == "music" then                       -- nota musical (riscada quando desligada)
    love.graphics.circle("fill", cx - 4, cy + 5, 3.5)
    love.graphics.line(cx - 0.5, cy + 5, cx - 0.5, cy - 7, cx + 6, cy - 4)
    if not Options.get("music") then
      love.graphics.setColor(1, 0.35, 0.3)
      love.graphics.line(x + 5, y + s - 5, x + s - 5, y + 5)
    end
  elseif id == "fullscreen" then              -- cantos
    local a, b, k = x + 6, x + s - 6, 5
    love.graphics.line(a, y + 6 + k, a, y + 6, a + k, y + 6)
    love.graphics.line(b - k, y + 6, b, y + 6, b, y + 6 + k)
    love.graphics.line(a, y + s - 6 - k, a, y + s - 6, a + k, y + s - 6)
    love.graphics.line(b - k, y + s - 6, b, y + s - 6, b, y + s - 6 - k)
  elseif id == "minimize" then                -- traço embaixo
    love.graphics.line(x + 7, y + s - 8, x + s - 7, y + s - 8)
  elseif id == "config" then                  -- engrenagem
    for k = 0, 7 do
      local a = k * math.pi / 4
      love.graphics.line(cx + math.cos(a) * 5, cy + math.sin(a) * 5, cx + math.cos(a) * 8.5, cy + math.sin(a) * 8.5)
    end
    love.graphics.circle("line", cx, cy, 5)
  end
end

-- canConfig: a configuração só abre no mapa-múndi e na escolha do time.
function Toolbar.draw(x, y, canConfig, font)
  Toolbar.x, Toolbar.y = x, y
  local s, g = Toolbar.size, Toolbar.gap
  local mx, my = love.mouse.getPosition()
  Toolbar.hover = Toolbar.hit(mx, my)
  for i, it in ipairs(Toolbar.items) do
    local bx = x + (i - 1) * (s + g)
    local hov = Toolbar.hover == it.id
    love.graphics.setColor(0.05, 0.1, 0.35, hov and 0.95 or 0.75)
    love.graphics.rectangle("fill", bx, y, s, s, 5, 5)
    love.graphics.setColor(0.45, 0.75, 1, hov and 1 or 0.7)
    love.graphics.setLineWidth(hov and 2 or 1)
    love.graphics.rectangle("line", bx, y, s, s, 5, 5)
    icon(it.id, bx, y, s, it.id == "config" and not canConfig)
  end
  if Toolbar.hover then
    for _, it in ipairs(Toolbar.items) do
      if it.id == Toolbar.hover then
        local tip = it.tip()
        if it.id == "config" and not canConfig then tip = L("Configuração: no mapa", "Settings: on the map") end
        if font then love.graphics.setFont(font) end
        local f = love.graphics.getFont()
        local tw, th = f:getWidth(tip) + 12, f:getHeight() + 6
        local tx = math.min(x, love.graphics.getWidth() - tw - 4)
        local ty = y > love.graphics.getHeight() / 2 and y - th - 4 or y + s + 4
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.rectangle("fill", tx, ty, tw, th, 4, 4)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(tip, tx + 6, ty + 3)
      end
    end
  end
end

return Toolbar
