-- Controles (DualSense, DualShock, Xbox, Switch Pro... qualquer um que o SDL reconheça como
-- gamepad) no PC e no Android, e os botões do 3DS no LÖVE Potion. Os botões viram as teclas
-- equivalentes (love.keypressed); direcional e analógico esquerdo repetem enquanto seguros, como
-- uma tecla segurada.
--
--   Cruz/A = A   Bola/B = B   OPTIONS/START = START   Create/Back = configuração (F1)
--   Triângulo/Y = música   Quadrado/X = idioma
local Pad = {}

Pad.REPEAT_DELAY = 0.30      -- s até começar a repetir
Pad.REPEAT_RATE = 0.09       -- s entre repetições
Pad.DEADZONE = 0.5           -- analógico: aperta acima disso...
Pad.RELEASE = 0.3            -- ... e solta abaixo disso

-- botão do gamepad -> tecla
Pad.BUTTONS = { a = "z", b = "x", start = "pause", back = "f1", y = "m", x = "n" }
Pad.DIRS = { dpup = "up", dpdown = "down", dpleft = "left", dpright = "right" }

Pad.hold = nil               -- { key, src, t } direção segurada
Pad.stick = nil              -- direção atual do analógico
Pad.last = "keys"            -- último tipo de entrada: "keys", "pad", "touch"
Pad.toast = nil              -- { text, t } aviso de controle conectado

-- press(key): o que fazer com a tecla (padrão: love.keypressed).
local function press(key) (Pad.press or love.keypressed)(key) end

function Pad.pressed(button)
  Pad.last = "pad"
  local dir = Pad.DIRS[button]
  if dir then
    Pad.hold = { key = dir, src = button, t = -Pad.REPEAT_DELAY }
    press(dir)
    return dir
  end
  local k = Pad.BUTTONS[button]
  if k then press(k) end
  return k
end

function Pad.released(button)
  if Pad.hold and Pad.hold.src == button then Pad.hold = nil end
end

-- Direção do analógico (x, y em -1..1), com histerese.
function Pad.stickDir(x, y, cur)
  local ax, ay = math.abs(x), math.abs(y)
  local lim = cur and Pad.RELEASE or Pad.DEADZONE
  if math.max(ax, ay) < lim then return nil end
  if cur and math.max(ax, ay) < Pad.DEADZONE then return cur end
  if ax > ay then return x > 0 and "right" or "left" end
  return y > 0 and "down" or "up"
end

local function readStick()
  if not (love.joystick and love.joystick.getJoysticks) then return 0, 0 end
  local ok, list = pcall(love.joystick.getJoysticks)
  if not ok then return 0, 0 end
  for _, j in ipairs(list) do
    local ok2, gp = pcall(j.isGamepad, j)
    if ok2 and gp then
      local okx, x = pcall(j.getGamepadAxis, j, "leftx")
      local oky, y = pcall(j.getGamepadAxis, j, "lefty")
      if okx and oky and (math.abs(x) > Pad.RELEASE or math.abs(y) > Pad.RELEASE) then return x, y end
    end
  end
  return 0, 0
end

-- O botão está apertado em algum controle? (true se não der para saber)
function Pad.isDown(button)
  if not (love.joystick and love.joystick.getJoysticks) then return true end
  local ok, list = pcall(love.joystick.getJoysticks)
  if not ok or #list == 0 then return true end
  local known = false
  for _, j in ipairs(list) do
    local ok2, down = pcall(j.isGamepadDown, j, button)
    if ok2 then
      known = true
      if down then return true end
    end
  end
  return not known
end

-- dt; x, y opcionais (testes: posição do analógico).
function Pad.update(dt, x, y)
  if x == nil then x, y = readStick() end
  local dir = Pad.stickDir(x, y, Pad.stick)
  if dir ~= Pad.stick then
    Pad.stick = dir
    if dir then
      Pad.last = "pad"
      Pad.hold = { key = dir, src = "stick", t = -Pad.REPEAT_DELAY }
      press(dir)
    elseif Pad.hold and Pad.hold.src == "stick" then
      Pad.hold = nil
    end
  end
  local h = Pad.hold
  if h and Pad.DIRS[h.src] and not Pad.isDown(h.src) then   -- soltou sem chegar o evento
    Pad.hold, h = nil, nil
  end
  if h then
    h.t = h.t + dt
    while h.t >= Pad.REPEAT_RATE and Pad.hold == h do
      h.t = h.t - Pad.REPEAT_RATE
      press(h.key)
    end
  end
  if Pad.toast then
    Pad.toast.t = Pad.toast.t - dt
    if Pad.toast.t <= 0 then Pad.toast = nil end
  end
end

function Pad.connected()
  if not (love.joystick and love.joystick.getJoysticks) then return false end
  local ok, list = pcall(love.joystick.getJoysticks)
  return ok and #list > 0
end

function Pad.notify(text) Pad.toast = { text = text, t = 3 } end

function Pad.drawToast(font)
  if not Pad.toast then return end
  love.graphics.setFont(font)
  local w = font:getWidth(Pad.toast.text) + 24
  love.graphics.setColor(0, 0, 0, 0.75)
  love.graphics.rectangle("fill", 10, 10, w, font:getHeight() + 12, 6, 6)
  love.graphics.setColor(1, 1, 0.7, math.min(1, Pad.toast.t * 2))
  love.graphics.print(Pad.toast.text, 22, 16)
end

return Pad
