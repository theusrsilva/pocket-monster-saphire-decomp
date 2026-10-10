-- Tela de configuração (abre antes do jogo no PC, como o launcher do Gen1Recomp):
-- escolhe a ROM, liga/desliga as melhorias e começa o jogo ou gera a ROM traduzida.
local Options = require("src.game.options")
local I18n = require("src.game.i18n")

local Launcher = {}
Launcher.__index = Launcher

local function L(pt, en) return I18n.lang == "en" and en or pt end
local function onoff(v) return v and L("Ligada", "On") or L("Desligada", "Off") end

-- ctx: { hasData(), romInfo(), loadRom(path) -> ok, msg, play(), quit(), buildRom() (opcional) }
function Launcher.new(ctx)
  local self = setmetatable({ ctx = ctx, index = 1, editing = false, input = "", msg = nil }, Launcher)
  self.items = {
    { id = "rom", label = function() return "ROM" end,
      value = function()
        local p = Options.get("romPath")
        if p == "" and ctx.hasData() then return L("(já importada; Enter para trocar)", "(already imported; Enter to change)") end
        return (p ~= "" and p) or L("(não configurada: Enter para digitar o caminho ou arraste o .gbc)",
          "(not set: Enter to type the path or drop the .gbc)")
      end,
      enter = function() self.editing = true; self.input = Options.get("romPath") end },
    { id = "lang", label = function() return L("Idioma", "Language") end,
      value = function() return Options.get("lang") == "pt" and "Português" or "English" end,
      change = function() Options.set("lang", Options.get("lang") == "pt" and "en" or "pt") end },
    { id = "names", label = function() return L("Nomes dos Pokémon", "Pokémon names") end,
      value = function() return Options.get("names") == "oficial" and L("Oficiais", "Official") or L("Do jogo", "As in the game") end,
      change = function() Options.set("names", Options.get("names") == "oficial" and "original" or "oficial") end },
    { id = "preview", label = function() return L("Prévia de ataque (dano, acerto, contra)", "Attack preview (damage, hit, counter)") end,
      value = function() return onoff(Options.get("preview")) end,
      change = function() Options.set("preview", not Options.get("preview")) end },
    { id = "ai", label = function() return L("IA dos inimigos", "Enemy AI") end,
      value = function() return Options.get("ai") == "original" and L("Original", "Original") or L("Melhorada", "Improved") end,
      change = function() Options.set("ai", Options.get("ai") == "original" and "melhorada" or "original") end },
    { id = "fixHeal", label = function() return L("Corrigir autocura do inimigo (bug)", "Fix enemy self-heal (bug)") end,
      value = function() return onoff(Options.get("fixHeal")) end,
      change = function() Options.set("fixHeal", not Options.get("fixHeal")) end },
    { id = "anims", label = function() return L("Animações de batalha (do jogo original)", "Battle animations (original game)") end,
      value = function() return onoff(Options.get("anims")) end,
      change = function() Options.set("anims", not Options.get("anims")) end },
    { id = "undo", label = function() return L("Desfazer movimento", "Undo movement") end,
      value = function() return onoff(Options.get("undo")) end,
      change = function() Options.set("undo", not Options.get("undo")) end },
    { id = "speed", label = function() return L("Turno inimigo", "Enemy turn") end,
      value = function() return Options.get("enemySpeed") == "normal" and L("Normal", "Normal") or L("Rápido", "Fast") end,
      change = function() Options.set("enemySpeed", Options.get("enemySpeed") == "normal" and "rapida" or "normal") end },
    { id = "sound", label = function() return L("Som", "Sound") end,
      value = function() return Options.get("sound") and ("%d%%"):format(math.floor(Options.get("volume") * 100 + 0.5)) or L("Desligado", "Off") end,
      change = function(d)
        if not Options.get("sound") then Options.set("sound", true); return end
        local v = Options.get("volume") + 0.1 * (d or 1)
        if v <= 0.001 then Options.set("sound", false); v = 0.1 end
        Options.set("volume", math.min(1, v))
      end },
    { id = "fullscreen", label = function() return L("Tela cheia", "Fullscreen") end,
      value = function() return onoff(Options.get("fullscreen")) end,
      change = function()
        Options.set("fullscreen", not Options.get("fullscreen"))
        pcall(love.window.setFullscreen, Options.get("fullscreen"))
      end },
    { id = "launcher", label = function() return L("Mostrar esta tela ao abrir", "Show this screen at startup") end,
      value = function() return onoff(Options.get("launcher")) end,
      change = function() Options.set("launcher", not Options.get("launcher")) end },
    { id = "play", button = true, label = function() return L("Jogar", "Play") end,
      enter = function() self:play() end },
    { id = "build", button = true, label = function() return L("Gerar ROM traduzida (GBC/GBA)", "Build translated ROM (GBC/GBA)") end,
      enter = function()
        if not ctx.buildRom then self.msg = L("Ainda não disponível.", "Not available yet.") return end
        self.msg = ctx.buildRom()
      end },
    { id = "quit", button = true, label = function() return L("Sair", "Quit") end, enter = function() ctx.quit() end },
  }
  for i, it in ipairs(self.items) do if it.id == "play" then self.index = i end end
  return self
end

function Launcher:play()
  if not self.ctx.hasData() then
    self.msg = L("Configure a ROM primeiro.", "Set up the ROM first.")
    return
  end
  Options.save()
  self.ctx.play()
end

function Launcher:changed()
  Options.apply()
  Options.save()
end

function Launcher:submitPath()
  self.editing = false
  local path = self.input:gsub("^%s+", ""):gsub("%s+$", ""):gsub('^"(.*)"$', "%1")
  if path == "" then return end
  local ok, msg = self.ctx.loadRom(path)
  self.msg = msg
  if ok then Options.set("romPath", path); self:changed() end
end

function Launcher:keypressed(key)
  if self.editing then
    if key == "return" or key == "kpenter" then self:submitPath()
    elseif key == "escape" then self.editing = false
    elseif key == "backspace" then self.input = self.input:sub(1, -2)
    elseif key == "v" and love.keyboard.isDown("lctrl", "rctrl", "lgui", "rgui") then
      self.input = self.input .. (love.system.getClipboardText() or "")
    end
    return
  end
  local it = self.items[self.index]
  if key == "up" or key == "w" then self.index = (self.index - 2) % #self.items + 1
  elseif key == "down" or key == "s" then self.index = self.index % #self.items + 1
  elseif (key == "left" or key == "a") and it.change then it.change(-1); self:changed()
  elseif (key == "right" or key == "d") and it.change then it.change(1); self:changed()
  elseif key == "return" or key == "kpenter" or key == "space" or key == "z" then
    if it.enter then it.enter() elseif it.change then it.change(1); self:changed() end
  elseif key == "escape" then self.ctx.quit()
  end
end

function Launcher:textinput(t)
  if self.editing then self.input = self.input .. t end
end

function Launcher:filedropped(file)
  local path = file:getFilename()
  local ok, msg = self.ctx.loadRom(path, file)
  self.msg = msg
  if ok then Options.set("romPath", path); self:changed() end
end

function Launcher:draw(fonts)
  local w, h = love.graphics.getDimensions()
  love.graphics.clear(0.03, 0.06, 0.18)
  love.graphics.setFont(fonts.big)
  love.graphics.setColor(1, 1, 0.6)
  local okv, ver = pcall(require, "version")          -- version.lua é gerado no build de release
  love.graphics.print("Pocket Monster Saphire  -  recomp" .. (okv and type(ver) == "string" and ("  " .. ver) or ""), 30, 18)
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.7, 0.8, 1)
  love.graphics.print(self.ctx.romInfo(), 32, 50)
  love.graphics.setFont(fonts.font)
  local y = 82
  for i, it in ipairs(self.items) do
    local sel = i == self.index
    if it.button and not self.items[i - 1].button then y = y + 10 end
    if sel then
      love.graphics.setColor(1, 1, 0.4, 0.18)
      love.graphics.rectangle("fill", 24, y - 3, w - 48, 24, 4, 4)
    end
    love.graphics.setColor(sel and { 1, 1, 0.5 } or { 1, 1, 1 })
    if it.button then
      love.graphics.print((sel and "> " or "  ") .. it.label(), 34, y)
    else
      love.graphics.print((sel and "> " or "  ") .. it.label(), 34, y)
      local v = it.value()
      if it.id == "rom" and self.editing then v = self.input .. ((love.timer.getTime() % 1 < 0.5) and "_" or "") end
      love.graphics.setColor(sel and { 0.6, 1, 0.7 } or { 0.75, 0.85, 1 })
      love.graphics.printf(v, 400, y, w - 430, "left")
    end
    y = y + 26
  end
  if self.msg then
    love.graphics.setColor(1, 0.85, 0.5)
    love.graphics.printf(self.msg, 30, h - 64, w - 60)
  end
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(1, 1, 1, 0.6)
  love.graphics.printf(L("Cima/baixo: escolher   Esquerda/direita: mudar   Enter: confirmar   F1 no jogo: esta tela",
    "Up/down: choose   Left/right: change   Enter: confirm   F1 in game: this screen"), 0, h - 22, w - 16, "right")
end

return Launcher
