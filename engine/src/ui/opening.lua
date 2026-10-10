-- Abertura e tela de título, como no original: as 5 cenas da história ($11:$4000; imagens do
-- cache, generated/intro_N.png) com o texto do script $20 escrito letra a letra na caixa de baixo
-- (tela $BD:$5380 do original, src/ui/gbui.lua), e depois o título com NOVO JOGO / RECORDES.
-- A/Enter adianta o texto, START/Esc pula a abertura. Ver docs/FINDINGS.md, "Abertura e título".
local GBUI = require("src.ui.gbui")
local I18n = require("src.game.i18n")
local Messages = require("src.game.messages")
local Sound = require("src.audio.sound")
local utf8 = require("utf8")

local Opening = {}
Opening.__index = Opening

Opening.CHARS_PER_SEC = 16       -- ritmo medido no PyBoy (~16 letras/s)
Opening.HOLD = 1.5               -- pausa no fim de cada cena

local function T(s) return I18n.T(s) end

-- onDone(choice): "new" ou "continue".
function Opening.new(data, hasSave, onDone, skipIntro)
  local self = setmetatable({ data = data, hasSave = hasSave, onDone = onDone, scene = 1, t = 0,
    phase = skipIntro and "title" or "intro", index = hasSave and 2 or 1, imgs = {} }, Opening)
  for n = 1, 5 do
    local f = ("generated/intro_%d.png"):format(n)
    if love.filesystem.getInfo(f) then
      self.imgs[n] = love.graphics.newImage(f)
      self.imgs[n]:setFilter("nearest", "nearest")
    end
  end
  if love.filesystem.getInfo("generated/title.png") then
    self.title = love.graphics.newImage("generated/title.png")
    self.title:setFilter("nearest", "nearest")
  end
  if not self.imgs[1] or not self.title then self.phase = "title" end
  self:loadScene()
  Sound.music(Sound.INTRO)
  return self
end

function Opening:buttons()
  local lang = I18n.lang == "en" and "en" or "pt"
  if not self.btn or self.btnLang ~= lang then
    local f = ("generated/title_buttons_%s.png"):format(lang)
    if love.filesystem.getInfo(f) then
      self.btn = love.graphics.newImage(f)
      self.btn:setFilter("nearest", "nearest")
      self.btnQuads = {}
      for k = 0, 3 do self.btnQuads[k] = love.graphics.newQuad(0, k * 16, 80, 16, 80, 64) end
    end
    self.btnLang = lang
  end
  return self.btn
end

-- Texto da cena n = trecho n do script $20 (o trecho 0 é vazio).
function Opening:loadScene()
  if self.phase ~= "intro" then return end
  local list = self.data.messages[0] or {}
  local msg = list[self.scene] and Messages.resolve(list[self.scene], { peek = function() return 0 end })
    or { pages = {} }
  local parts = {}
  for _, p in ipairs(msg.pages) do parts[#parts + 1] = p.text end
  self.text = table.concat(parts, " ")
  self.shown, self.t, self.done = 0, 0, false
  local lang = I18n.lang == "en" and "en" or "pt"
  self.box = GBUI.new(lang, self.data.introPal and self.data.introPal[self.scene] or self.data.stages[0].bgpalRaw)
  if self.box then self.box:show(GBUI.TALK_WIDE, {}) end
end

-- Linhas de 18 colunas (palavras inteiras).
local function wrap(text, width)
  local lines, cur = {}, ""
  for word in text:gmatch("%S+") do
    local n, wn = utf8.len(cur) or #cur, utf8.len(word) or #word
    if n == 0 then cur = word
    elseif n + 1 + wn <= width then cur = cur .. " " .. word
    else lines[#lines + 1] = cur; cur = word end
  end
  if #cur > 0 then lines[#lines + 1] = cur end
  return lines
end

function Opening:nextScene()
  self.scene = self.scene + 1
  if self.scene > 5 then self.phase = "title"; self.t = 0 return end
  self:loadScene()
end

function Opening:update(dt)
  self.t = self.t + dt
  if self.phase == "intro" then
    local total = utf8.len(self.text) or #self.text
    if self.shown < total then
      self.shown = math.min(total, self.shown + dt * Opening.CHARS_PER_SEC)
      self.holdT = 0
    else
      self.holdT = (self.holdT or 0) + dt
      if self.holdT >= Opening.HOLD then self:nextScene() end
    end
  end
end

function Opening:confirm()
  if self.phase == "intro" then
    local total = utf8.len(self.text) or #self.text
    if self.shown < total then self.shown = total else self:nextScene() end
    return
  end
  if self.index == 2 and not self.hasSave then return end
  if self.index == 1 and self.hasSave and not self.confirmNew then
    self.confirmNew = true                     -- jogo novo apaga o progresso: pede de novo
    return
  end
  self.onDone(self.index == 1 and "new" or "continue")
end

function Opening:keypressed(k)
  if self.phase == "intro" then
    if k == "start" then self.phase = "title"; self.t = 0
    elseif k == "a" or k == "b" then self:confirm() end
    return
  end
  if k == "up" or k == "down" then
    self.index = 3 - self.index
    self.confirmNew = false
    Sound.sfx(Sound.CURSOR)
  elseif k == "a" or k == "start" then self:confirm()
  elseif k == "b" then self.confirmNew = false
  end
end

function Opening:draw(w, h)
  love.graphics.clear(0, 0, 0)
  local s = math.max(1, math.floor(math.min(w / 160, h / 144)))
  local ox, oy = math.floor((w - 160 * s) / 2), math.floor((h - 144 * s) / 2)
  local View = require("src.ui.view")
  love.graphics.setColor(1, 1, 1)
  if self.phase == "intro" then
    local img = self.imgs[self.scene]
    if img then love.graphics.draw(img, ox, oy, 0, s, s) end
    if self.box then
      local lines = wrap(self.text, 18)
      local left = math.floor(self.shown)
      local visible = {}
      for _, line in ipairs(lines) do
        if left <= 0 then break end
        local n = utf8.len(line) or #line
        local take = math.min(n, left)
        visible[#visible + 1] = take < n and line:sub(1, (utf8.offset(line, take + 1) or (#line + 1)) - 1) or line
        left = left - n - 1
      end
      local first = math.max(1, #visible - 3)          -- rola: mostra as 4 últimas linhas
      local key = first .. ":" .. #visible .. ":" .. (visible[#visible] or "")
      if self.boxKey ~= key then
        self.box:clear(1, 1, 18, 4)
        for i = first, #visible do self.box:text(1, 1 + i - first, visible[i], 18) end
        self.boxKey = key
      end
      self.box:draw(ox, oy + 96 * s, s)
    end
    View.clickable(0, 0, w, h, function() love.keypressed("z") end)
    love.graphics.setFont(View.small)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.printf(T("START/Esc: pular"), 0, h - 18, w - 10, "right")
    return
  end
  if self.title then love.graphics.draw(self.title, ox, oy, 0, s, s) end
  local btn = self:buttons()
  if btn then
    for i = 1, 2 do
      local sel = self.index == i
      local q = self.btnQuads[(i - 1) * 2 + (sel and 0 or 1)]
      local bx, by = ox + (sel and 8 or 0) * s, oy + (i == 1 and 72 or 88) * s
      if i == 2 and not self.hasSave then love.graphics.setColor(1, 1, 1, 0.45) else love.graphics.setColor(1, 1, 1) end
      love.graphics.draw(btn, q, bx, by, 0, s, s)
      View.clickable(bx, by, 80 * s, 16 * s, function() self.index = i; love.keypressed("z") end,
        function() if self.index ~= i then self.index = i; self.confirmNew = false end end)
    end
  end
  if self.confirmNew then
    love.graphics.setFont(View.font)
    local msg = T("Começar do zero? O jogo salvo será apagado. Confirme de novo.")
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, h - 40, w, 30)
    love.graphics.setColor(1, 1, 0.6)
    love.graphics.printf(msg, 0, h - 34, w, "center")
  end
end

return Opening
