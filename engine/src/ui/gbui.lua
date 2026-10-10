-- Telas de interface do jogo ORIGINAL desenhadas no motor: cada tela é um script do banco $BC
-- (painel da unidade, menus, listas, caixas de fala, bônus de nível...) executado pelo mesmo
-- interpretador da cena de ataque (src/anim/attack.lua), com os valores da unidade escritos nos
-- endereços da WRAM que o script lê. Em português os dados vêm da ROM traduzida pelo conversor
-- (generated/ui_pt.bin), em inglês da ROM do jogador (generated/ui_en.bin).
-- Ver docs/FINDINGS.md, "Telas de interface".
local Attack = require("src.anim.attack")
local Render = require("src.anim.render")
local Slice = require("src.anim.slice")
local Dialogs = require("src.romhack.dialogs")

local GBUI = {}
GBUI.__index = GBUI

-- Telas ($BC:$4000[id]).
GBUI.PANEL, GBUI.ACTIONS, GBUI.GOODS, GBUI.SKILLS = 0x01, 0x02, 0x03, 0x04
GBUI.RECOVER, GBUI.SPECIAL, GBUI.STATE, GBUI.MAPMENU = 0x05, 0x06, 0x07, 0x09
GBUI.TYPES, GBUI.TEAMLIST, GBUI.TALK, GBUI.TALK_WIDE = 0x0A, 0x0B, 0x0D, 0x0E
GBUI.WIN, GBUI.ENEMY_TURN, GBUI.PLAYER_TURN, GBUI.END_TURN = 0x0F, 0x10, 0x11, 0x12
GBUI.TALK_PORTRAIT, GBUI.LEVELUP, GBUI.PLACE = 0x13, 0x15, 0x20

local readers = {}
local function reader(lang)
  if readers[lang] == nil then
    local f = "generated/ui_" .. lang .. ".bin"
    readers[lang] = love.filesystem.getInfo(f) and Slice.load(love.filesystem.read(f)) or false
  end
  return readers[lang] or (lang ~= "en" and reader("en")) or nil
end

function GBUI.available()
  return love.filesystem.getInfo("generated/ui_en.bin") ~= nil
end

-- bgpal: as 64 bytes de paleta de BG da fase (importer: stage.bgpalRaw).
function GBUI.new(lang, bgpal)
  local r = reader(lang)
  if not r then return nil end
  local m = Attack.machine(r)
  for i = 0, 63 do m.bgpal[i] = bgpal and bgpal[i + 1] or 0 end
  -- fonte das falas no banco 1 da VRAM em $8C00 ($39:$42A6, sempre carregada no campo)
  for i = 0, 64 * 16 - 1 do m.V[1][0x0C00 + i] = r:u8(0x39, 0x4365 + i) end
  return setmetatable({ m = m, lang = lang, rom = r }, GBUI)
end

-- Mostra a tela id com as variáveis { [endereço] = byte } (lidas pelo script).
function GBUI:show(id, vars)
  local m = self.m
  for a = 0x1800, 0x1FFF do m.V[0][a] = 0; m.V[1][a] = 0 end
  m.extent = nil
  for a, v in pairs(vars or {}) do m.M[a] = v % 256 end
  m:runScreen(m:R16(0xBC, 0x4000 + id * 2))
  self.id = id
  self.wx, self.wy = m.M[0xC242] - 7, m.M[0xC243]
  local e = m.extent or { cols = 20, rows = 18 }
  self.cols, self.rows = e.cols, e.rows
  self.dirty = true
end

-- Valor de 16 bits nas variáveis.
function GBUI.w16(vars, a, v)
  v = math.max(0, math.floor(v or 0)) % 65536
  vars[a] = v % 256
  vars[a + 1] = math.floor(v / 256)
end

-- Texto com a fonte das falas ($39:$4226: byte -> tile; atributo $0E = banco 1, paleta 6) na
-- célula (col, row) da janela. Em português: maiúsculas e acentos como na ROM traduzida.
function GBUI:text(col, row, s, width)
  local m = self.m
  local bytes
  if self.lang == "pt" then bytes = Dialogs.encode(s)
  else bytes = {} for i = 1, #s do bytes[i] = s:byte(i) end end
  local x = 0
  for _, b in ipairs(bytes) do
    if width and x >= width then break end
    local tile = m:R(0x39, 0x4226 + (b % 128))
    local off = 0x1C00 + (row * 32) + col + x
    m:vwrite(0, off, tile)
    m:vwrite(1, off, 0x0E)
    x = x + 1
  end
  self.dirty = true
  return x
end

-- Apaga um retângulo de células (com o tile de fundo da caixa de fala: espaço da fonte).
function GBUI:clear(col, row, w, h)
  local m = self.m
  local tile = m:R(0x39, 0x4226 + 32)
  for r = row, row + h - 1 do
    for c = col, col + w - 1 do
      m:vwrite(0, 0x1C00 + r * 32 + c, tile)
      m:vwrite(1, 0x1C00 + r * 32 + c, 0x0E)
    end
  end
  self.dirty = true
end

function GBUI:image()
  if self.dirty or not self.img then
    local d = Render.window(self.m, self.cols, self.rows)
    if self.img and self.img.replacePixels and self.img:getWidth() == d:getWidth()
        and self.img:getHeight() == d:getHeight() then
      self.img:replacePixels(d)
    else
      self.img = love.graphics.newImage(d)
      self.img:setFilter("nearest", "nearest")
    end
    self.dirty = false
  end
  return self.img
end

-- Desenha a janela com o canto em (x, y), na escala dada.
function GBUI:draw(x, y, scale)
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(self:image(), x, y, 0, scale, scale)
end

-- Cursor dos menus (a pokébola do original, desenhada: 8x8).
function GBUI.drawCursor(x, y, scale)
  local s = scale
  love.graphics.setColor(0.1, 0.1, 0.15)
  love.graphics.circle("fill", x + 4 * s, y + 4 * s, 3.7 * s)
  love.graphics.setColor(0.95, 0.2, 0.2)
  love.graphics.arc("fill", x + 4 * s, y + 4 * s, 3 * s, math.pi, 2 * math.pi)
  love.graphics.setColor(1, 1, 1)
  love.graphics.arc("fill", x + 4 * s, y + 4 * s, 3 * s, 0, math.pi)
  love.graphics.setColor(0.1, 0.1, 0.15)
  love.graphics.rectangle("fill", x + 1 * s, y + 3.6 * s, 6 * s, 0.8 * s)
  love.graphics.setColor(1, 1, 1)
  love.graphics.circle("fill", x + 4 * s, y + 4 * s, 1.1 * s)
end

return GBUI
