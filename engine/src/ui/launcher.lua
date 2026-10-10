-- Tela de configuração (abre antes do jogo no PC e no Android, como o launcher do Gen1Recomp):
-- escolhe a ROM, liga/desliga as melhorias e começa o jogo ou gera a ROM traduzida. Funciona com
-- teclado (setas, Enter), controle (direcional/analógico, A, OPTIONS/START joga), mouse (clique nos
-- interruptores, opções e botões; arrastar o .gbc para a janela) e toque (Android: seletor de arquivo).
local Options = require("src.game.options")
local I18n = require("src.game.i18n")

local Launcher = {}
Launcher.__index = Launcher

local function L(pt, en) return I18n.lang == "en" and en or pt end

-- Cores
local BG = { 0.03, 0.06, 0.18 }
local CARD = { 0.06, 0.11, 0.30 }
local EDGE = { 0.30, 0.55, 0.95 }
local ON = { 0.25, 0.80, 0.45 }
local OFF = { 0.35, 0.38, 0.50 }
local ACCENT = { 1, 0.85, 0.35 }

-- ctx: { hasData(), romInfo(), loadRom(path) -> ok, msg, play(), quit(), buildRom() (opcional),
--        pickRom() (opcional: seletor de arquivo do Android), mobile }
function Launcher.new(ctx)
  local self = setmetatable({ ctx = ctx, index = 1, editing = false, input = "", msg = nil, hits = {} },
    Launcher)
  local function toggle(key) return { kind = "toggle", get = function() return Options.get(key) end,
    set = function(v) Options.set(key, v) end } end
  local function choice(key, opts) return { kind = "choice", options = opts,
    get = function() return Options.get(key) end, set = function(v) Options.set(key, v) end } end
  local function item(t, extra) for k, v in pairs(extra) do t[k] = v end return t end
  self.items = {
    { id = "rom", kind = "rom", label = function() return "ROM" end,
      enter = function()
        if ctx.pickRom then
          self.msg = ctx.pickRom() and L("Escolha o arquivo .gbc...", "Choose the .gbc file...")
            or L("Não consegui abrir o seletor de arquivos.", "Could not open the file picker.")
          return
        end
        self.editing = true; self.input = Options.get("romPath")
      end },
    item(choice("lang", { { "pt", "Português" }, { "en", "English" } }),
      { id = "lang", section = 1, label = function() return L("Idioma", "Language") end }),
    item(choice("names", { { "oficial", function() return L("Oficiais", "Official") end },
      { "original", function() return L("Do jogo", "As in game") end } }),
      { id = "names", section = 1, label = function() return L("Nomes dos Pokémon", "Pokémon names") end }),
    item(toggle("music"), { id = "music", section = 3, label = function() return L("Música", "Music") end }),
    { id = "sound", kind = "slider", section = 3, label = function() return L("Volume", "Volume") end },
    item(toggle("fullscreen"), { id = "fullscreen", section = 3, label = function() return L("Tela cheia", "Fullscreen") end,
      after = function() pcall(love.window.setFullscreen, Options.get("fullscreen")) end }),
    item(toggle("launcher"), { id = "launcher", section = 3,
      label = function() return L("Mostrar esta tela ao abrir", "Show this screen at startup") end }),
    item(toggle("anims"), { id = "anims", section = 2,
      label = function() return L("Animações de batalha", "Battle animations") end,
      hint = function() return L("as originais do jogo; A/B/START pulam", "the game's own; A/B/START skip") end }),
    item(toggle("preview"), { id = "preview", section = 2,
      label = function() return L("Prévia de ataque", "Attack preview") end,
      hint = function() return L("dano, acerto e contra antes de confirmar", "damage, hit and counter before confirming") end }),
    item(toggle("log"), { id = "log", section = 2,
      label = function() return L("Histórico da partida", "Match log") end,
      hint = function() return L("lista do que aconteceu; desligado mostra só o último aviso", "what happened; off shows only the latest notice") end }),
    item(toggle("undo"), { id = "undo", section = 2,
      label = function() return L("Desfazer movimento", "Undo movement") end }),
    item(choice("ai", { { "original", function() return L("Original", "Original") end },
      { "melhorada", function() return L("Melhorada", "Improved") end } }),
      { id = "ai", section = 2, label = function() return L("IA dos inimigos", "Enemy AI") end }),
    item(choice("enemySpeed", { { "normal", function() return L("Normal", "Normal") end },
      { "rapida", function() return L("Rápido", "Fast") end } }),
      { id = "speed", section = 2, label = function() return L("Turno inimigo", "Enemy turn") end }),
    item(toggle("fixHeal"), { id = "fixHeal", section = 2,
      label = function() return L("Corrigir autocura do inimigo", "Fix enemy self-heal") end,
      hint = function() return L("no original passa do HP máximo", "in the original it exceeds max HP") end }),
    { id = "play", kind = "button", primary = true, label = function() return L("Jogar", "Play") end,
      enter = function() self:play() end },
    { id = "build", kind = "button", label = function() return L("Gerar ROM traduzida (GBC/GBA)", "Build translated ROM (GBC/GBA)") end,
      enter = function()
        if not ctx.buildRom then self.msg = L("Ainda não disponível.", "Not available yet.") return end
        self.msg = ctx.buildRom()
      end },
    { id = "quit", kind = "button", label = function() return L("Sair", "Quit") end, enter = function() ctx.quit() end },
  }
  if ctx.mobile then                      -- celular: sem tela cheia/janela e sem gravar a ROM fora do app
    for i = #self.items, 1, -1 do
      local id = self.items[i].id
      if id == "fullscreen" or id == "build" then table.remove(self.items, i) end
    end
  end
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

-- Muda o valor do item (d = +1/-1; v = valor exato, do clique).
function Launcher:change(it, d, v)
  if it.kind == "toggle" then
    it.set(v == nil and not it.get() or v)
  elseif it.kind == "choice" then
    if v == nil then
      local cur = 1
      for i, o in ipairs(it.options) do if o[1] == it.get() then cur = i end end
      v = it.options[(cur - 1 + (d or 1)) % #it.options + 1][1]
    end
    it.set(v)
  elseif it.kind == "slider" then
    local vol = v or (Options.get("sound") and Options.get("volume") or 0) + 0.1 * (d or 1)
    vol = math.max(0, math.min(1, vol))
    Options.set("sound", vol > 0.001)
    if vol > 0.001 then Options.set("volume", vol) end
  else
    return
  end
  if it.after then it.after() end
  self:changed()
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
  elseif key == "down" or key == "s" or key == "tab" then self.index = self.index % #self.items + 1
  elseif key == "left" or key == "a" then self:change(it, -1)
  elseif key == "right" or key == "d" then self:change(it, 1)
  elseif key == "return" or key == "kpenter" or key == "space" or key == "z" then
    if it.enter then it.enter() else self:change(it, 1) end
  elseif key == "pause" then self:play()             -- START/OPTIONS do controle
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

-- Mouse: regiões registradas no desenho ({ x, y, w, h, i, fn(mx) }).
local function hitAt(hits, mx, my)
  for k = #hits, 1, -1 do
    local r = hits[k]
    if mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h then return r end
  end
end

function Launcher:mousepressed(mx, my, button)
  local r = hitAt(self.hits, mx, my)
  if not r then
    if self.editing then self.editing = false end
    return
  end
  if r.i then self.index = r.i end
  local it = self.items[self.index]
  if button == 2 and it then self:change(it, -1) return end
  if r.fn then r.fn(mx) end
end

function Launcher:mousemoved(mx, my)
  local r = hitAt(self.hits, mx, my)
  if r and r.i and not self.editing then self.index = r.i end
  self.hover = r
end

function Launcher:wheelmoved(dy)
  local it = self.items[self.index]
  if it and it.kind == "slider" then self:change(it, dy > 0 and 1 or -1) end
end

---------------------------------------------------------------- desenho

local function hit(self, x, y, w, h, i, fn)
  self.hits[#self.hits + 1] = { x = x, y = y, w = w, h = h, i = i, fn = fn }
end

local function card(x, y, w, h, title, font)
  love.graphics.setColor(CARD)
  love.graphics.rectangle("fill", x, y, w, h, 8, 8)
  love.graphics.setColor(EDGE[1], EDGE[2], EDGE[3], 0.6)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 8, 8)
  love.graphics.setFont(font)
  love.graphics.setColor(ACCENT)
  love.graphics.print(title, x + 14, y + 8)
end

local function pill(x, y, on, hov)
  local w, h = 46, 22
  love.graphics.setColor(on and ON or OFF)
  love.graphics.rectangle("fill", x, y, w, h, 11, 11)
  if hov then
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", x - 1, y - 1, w + 2, h + 2, 12, 12)
  end
  love.graphics.setColor(1, 1, 1)
  love.graphics.circle("fill", on and x + w - 11 or x + 11, y + h / 2, 8)
  return w, h
end

function Launcher:drawItem(i, it, x, y, w, fonts)
  local sel = i == self.index
  local rowH = it.hint and 40 or 30
  if sel then
    love.graphics.setColor(1, 1, 0.5, 0.12)
    love.graphics.rectangle("fill", x - 6, y - 4, w + 12, rowH, 5, 5)
  end
  love.graphics.setFont(fonts.font)
  love.graphics.setColor(sel and { 1, 1, 0.6 } or { 1, 1, 1 })
  love.graphics.print(it.label(), x, y)
  if it.hint then
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.65, 0.72, 0.9)
    love.graphics.print(it.hint(), x, y + 19)
  end
  hit(self, x - 6, y - 4, w + 12, rowH, i, function() self:change(it, 1) end)
  local cx = x + w
  if it.kind == "toggle" then
    local pw = 46
    pill(cx - pw, y - 1, it.get(), sel)
    hit(self, cx - pw, y - 1, pw, 22, i, function() self:change(it, 1) end)
  elseif it.kind == "choice" then
    love.graphics.setFont(fonts.small)
    local f = love.graphics.getFont()
    local segs, total = {}, 0
    for _, o in ipairs(it.options) do
      local lbl = type(o[2]) == "function" and o[2]() or o[2]
      local sw = f:getWidth(lbl) + 18
      segs[#segs + 1] = { o[1], lbl, sw }
      total = total + sw
    end
    local sx = cx - total
    for _, sg in ipairs(segs) do
      local on = it.get() == sg[1]
      love.graphics.setColor(on and ON or OFF)
      love.graphics.rectangle("fill", sx, y - 1, sg[3] - 2, 22, 5, 5)
      love.graphics.setColor(1, 1, 1, on and 1 or 0.75)
      love.graphics.print(sg[2], sx + 8, y + 3)
      local v = sg[1]
      hit(self, sx, y - 1, sg[3] - 2, 22, i, function() self:change(it, nil, v) end)
      sx = sx + sg[3]
    end
  elseif it.kind == "slider" then
    local sw = 150
    local sx = cx - sw
    local vol = Options.get("sound") and Options.get("volume") or 0
    love.graphics.setColor(OFF)
    love.graphics.rectangle("fill", sx, y + 8, sw, 6, 3, 3)
    love.graphics.setColor(ON)
    love.graphics.rectangle("fill", sx, y + 8, sw * vol, 6, 3, 3)
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", sx + sw * vol, y + 11, 8)
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.8, 0.85, 1)
    love.graphics.printf(vol > 0 and ("%d%%"):format(math.floor(vol * 100 + 0.5)) or L("mudo", "mute"),
      sx - 60, y + 3, 50, "right")
    hit(self, sx - 8, y - 2, sw + 16, 26, i, function(mx)
      local v = (mx - sx) / sw
      if v < 0.03 then v = 0 end
      self:change(it, nil, math.floor(v * 20 + 0.5) / 20)
    end)
  end
  return rowH
end

function Launcher:draw(fonts)
  self.hits = {}
  local w, h = love.graphics.getDimensions()
  love.graphics.clear(BG)
  -- cabeçalho
  love.graphics.setFont(fonts.big)
  love.graphics.setColor(1, 1, 0.6)
  local okv, ver = pcall(require, "version")          -- version.lua é gerado no build de release
  love.graphics.print("Pocket Monster Saphire", 24, 14)
  love.graphics.setFont(fonts.font)
  love.graphics.setColor(0.7, 0.8, 1)
  love.graphics.print("recomp" .. (okv and type(ver) == "string" and ("  " .. ver) or ""), 24 + fonts.big:getWidth("Pocket Monster Saphire") + 12, 22)

  local pad, gap = 20, 16
  local colW = math.floor((w - pad * 2 - gap) / 2)
  local leftX, rightX = pad, pad + colW + gap
  local top = 56

  -- ROM
  local hasData = self.ctx.hasData()
  local romH = 92
  card(leftX, top, colW, romH, "ROM", fonts.font)
  love.graphics.setColor(hasData and ON or { 1, 0.45, 0.35 })
  love.graphics.circle("fill", leftX + colW - 20, top + 18, 6)
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.8, 0.85, 1)
  love.graphics.printf(self.ctx.romInfo(), leftX + 14, top + 30, colW - 28)
  local romIdx
  for i, it in ipairs(self.items) do if it.id == "rom" then romIdx = i end end
  local bx, by, bw, bh = leftX + 14, top + romH - 32, colW - 28, 24
  local sel = self.index == romIdx
  love.graphics.setColor(sel and { 0.2, 0.35, 0.7 } or { 0.12, 0.2, 0.45 })
  love.graphics.rectangle("fill", bx, by, bw, bh, 5, 5)
  love.graphics.setColor(1, 1, 1)
  local p = Options.get("romPath")
  local txt
  if self.editing then
    txt = self.input .. ((love.timer.getTime() % 1 < 0.5) and "_" or "")
  elseif p ~= "" then
    txt = p
  else
    txt = hasData and L("já importada  -  clique para trocar", "already imported  -  click to change")
      or L("clique e digite o caminho, ou arraste o .gbc para esta janela", "click and type the path, or drop the .gbc here")
  end
  if self.ctx.pickRom and not self.editing then
    txt = hasData and L("já importada  -  toque para escolher outra", "already imported  -  tap to choose another")
      or L("toque para escolher o arquivo .gbc", "tap to choose the .gbc file")
  end
  love.graphics.printf(txt, bx + 8, by + 5, bw - 16, "left")
  hit(self, bx, by, bw, bh, romIdx, function() self.items[romIdx].enter() end)

  -- colunas de opções
  local function column(x, y, title, section)
    local rows = {}
    for i, it in ipairs(self.items) do if it.section == section then rows[#rows + 1] = i end end
    local hgt = 34
    for _, i in ipairs(rows) do hgt = hgt + (self.items[i].hint and 44 or 34) end
    card(x, y, colW, hgt, title, fonts.font)
    local yy = y + 36
    for _, i in ipairs(rows) do
      yy = yy + self:drawItem(i, self.items[i], x + 14, yy, colW - 28, fonts) + 4
    end
    return y + hgt
  end
  local y1 = column(leftX, top + romH + gap, L("Idioma", "Language"), 1)
  column(leftX, y1 + gap, L("Som e tela", "Sound and display"), 3)
  column(rightX, top, L("Jogo", "Game"), 2)

  -- botões
  local btnY = h - 76
  local x = w - pad
  for i = #self.items, 1, -1 do
    local it = self.items[i]
    if it.kind == "button" then
      love.graphics.setFont(it.primary and fonts.big or fonts.font)
      local f = love.graphics.getFont()
      local bw2 = f:getWidth(it.label()) + 40
      local bh2 = 44
      x = x - bw2
      local s2 = i == self.index
      love.graphics.setColor(it.primary and (s2 and { 0.3, 0.85, 0.5 } or ON) or (s2 and { 0.25, 0.4, 0.8 } or { 0.12, 0.2, 0.45 }))
      love.graphics.rectangle("fill", x, btnY, bw2, bh2, 8, 8)
      if s2 then
        love.graphics.setColor(1, 1, 0.6)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, btnY, bw2, bh2, 8, 8)
      end
      love.graphics.setColor(1, 1, 1)
      love.graphics.printf(it.label(), x, btnY + (bh2 - f:getHeight()) / 2, bw2, "center")
      hit(self, x, btnY, bw2, bh2, i, function() it.enter() end)
      x = x - 12
    end
  end
  if self.msg then
    love.graphics.setFont(fonts.font)
    love.graphics.setColor(1, 0.85, 0.5)
    love.graphics.printf(self.msg, pad, btnY + 2, x - pad - 10)
  end
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(1, 1, 1, 0.55)
  local Pad = require("src.ui.pad")
  local help
  if Pad.last == "pad" then
    help = L("Controle: direcional muda a opção, Cruz/A confirma, OPTIONS/START joga  -  no jogo: Create/Back volta aqui",
      "Controller: d-pad changes options, Cross/A confirms, OPTIONS/START plays  -  in game: Create/Back returns here")
  elseif self.ctx.mobile then
    help = L("Toque nas opções  -  um controle Bluetooth também funciona", "Tap the options  -  a Bluetooth controller works too")
  else
    help = L("Mouse, teclado (setas, Enter) ou controle  -  no jogo: F1 volta aqui, M música, F11 tela cheia",
      "Mouse, keyboard (arrows, Enter) or controller  -  in game: F1 back here, M music, F11 fullscreen")
  end
  love.graphics.printf(help, 0, h - 22, w - 16, "right")
end

return Launcher
