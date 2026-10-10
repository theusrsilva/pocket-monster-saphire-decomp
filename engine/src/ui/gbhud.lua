-- HUD da batalha com as telas do jogo original (src/ui/gbui.lua): painel da unidade ($BD:$4000),
-- menu de ação ($BD:$40F0), golpes ($BD:$41C8), itens ($BD:$4180, $43A8, $4678), Estado
-- ($BD:$4948), bônus de nível ($BD:$5920), avisos de turno ($BD:$55B0/$5600) e falas
-- ($BD:$5740 com retrato, $BD:$5380 sem). As telas ficam numa "tela de Game Boy" virtual de
-- 160x144 na escala do mapa, alinhada embaixo e no centro, nas mesmas posições do original.
-- O cursor é a pokébola, nas posições que o próprio script grava em $C0B2 (pares y, x da OAM).
local GBUI = require("src.ui.gbui")
local I18n = require("src.game.i18n")

local utf8 = require("utf8")

local GBHud = { screens = {} }

local function press(k) love.keypressed(k) end
local function clickable(...) return require("src.ui.view").clickable(...) end

function GBHud.available() return GBUI.available() end

-- Registro de unidade no formato da SRAM em base ($C900): o que os scripts leem.
function GBHud.unitVars(u, base, v)
  v = v or {}
  v[base] = 1
  v[base + 2] = u.level or 1
  v[base + 3] = u.exp or 0
  v[base + 5] = u.species
  v[base + 6] = u.type or 1
  GBUI.w16(v, base + 12, u.sp); GBUI.w16(v, base + 14, u.hp)
  GBUI.w16(v, base + 16, u.maxsp); GBUI.w16(v, base + 18, u.maxhp)
  GBUI.w16(v, base + 20, u.atk); GBUI.w16(v, base + 22, u.acc); GBUI.w16(v, base + 24, u.eva)
  v[base + 26] = u.move or 0
  for i = 1, 4 do v[base + 0x24 + (i - 1) * 5] = (u.skills and u.skills[i]) or 0 end
  return v
end

local function signature(id, vars)
  local keys = {}
  for k in pairs(vars) do keys[#keys + 1] = k end
  table.sort(keys)
  local t = { id }
  for _, k in ipairs(keys) do t[#t + 1] = k .. "=" .. vars[k] end
  return table.concat(t, ",")
end

-- Uma tela por papel (cada uma com a própria VRAM), refeita só quando a entrada muda.
function GBHud.screen(b, role, id, vars)
  local lang = I18n.lang == "en" and "en" or "pt"
  local key = role .. "|" .. lang .. "|" .. tostring(b.stageIndex)
  local g = GBHud.screens[key]
  if not g then
    g = GBUI.new(lang, b.stage.bgpalRaw)
    if not g then return nil end
    GBHud.screens[key] = g
  end
  local sig = signature(id, vars or {})
  if g.sig ~= sig then
    g:show(id, vars)
    g.sig, g.textKey = sig, nil
  end
  return g
end

-- Origem e escala da tela de Game Boy virtual.
function GBHud.origin(w, h, s)
  return math.floor((w - 160 * s) / 2), h - 144 * s
end

local function drawScreen(g, vx, vy, s)
  g:draw(vx + g.wx * s, vy + g.wy * s, s)
end

-- Cursor e itens do menu: posições que o script grava ($C0B2 + 2i = y, $C0B3 + 2i = x + 8; a
-- pokébola de 16x16 fica em (x, y), conferido na OAM do PyBoy). A linha do texto é a linha de
-- tiles no meio da pokébola.
local function drawMenu(g, menu, vx, vy, s, rowW)
  local M = g.m.M
  for i, it in ipairs(menu.items) do
    local y, x = M[0xC0B2 + (i - 1) * 2], M[0xC0B3 + (i - 1) * 2] - 8
    local rowY = g.wy + 8 * math.floor((y + 8 - g.wy) / 8)
    local rx, ry = vx + (x + 13) * s, vy + rowY * s
    local rw = ((rowW or 40) - 5) * s
    if it.disabled then
      love.graphics.setColor(0.02, 0.05, 0.25, 0.55)
      love.graphics.rectangle("fill", rx, ry, rw, 8 * s)
    end
    clickable(vx + x * s, vy + y * s, rw + 16 * s, 16 * s,
      function() menu.index = i; press("z") end, function() menu.index = i end)
    if i == menu.index then GBUI.drawCursor(vx + x * s, vy + y * s, s * 2) end
  end
end

-- Sprite de luta da espécie centrado em (cx, cy) (tela de Estado: no original é um objeto).
local spriteImgs = {}
function GBHud.drawSprite(species, cx, cy, s)
  local img = spriteImgs[species]
  if img == nil then
    local d = require("src.anim.scene").sprite(species)
    img = d and love.graphics.newImage(d) or false
    if img then img:setFilter("nearest", "nearest") end
    spriteImgs[species] = img
  end
  if not img then return end
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(img, math.floor(cx - img:getWidth() * s / 2), math.floor(cy - img:getHeight() * s / 2), 0, s, s)
end

-- Desenha painel/menus/avisos. Devolve true se desenhou o HUD (sem o do motor).
function GBHud.draw(b, w, h, s)
  if not b.stage.bgpalRaw or not GBUI.available() then return false end
  local vx, vy = GBHud.origin(w, h, s)
  local menu = (b.mode == "menu" or b.mode == "bonus") and b.menu or nil
  if menu and menu.kind == "actions" then
    local g = GBHud.screen(b, "menu", GBUI.ACTIONS, {})
    drawScreen(g, vx, vy, s)
    drawMenu(g, menu, vx, vy, s, 40)
  elseif menu and menu.kind == "skills" then
    local g = GBHud.screen(b, "menu", GBUI.SKILLS, GBHud.unitVars(menu.unit, 0xC900))
    -- caixa de baixo: dados do golpe sob o cursor (fonte das falas)
    local it = menu.items[menu.index]
    if g.textKey ~= menu.index then
      g:clear(1, 7, 18, 4)
      local sk = it and it.skill
      if sk then
        local Names = require("src.game.names")
        local T = I18n.T
        g:text(1, 7, Names.skill_name(sk.id), 18)
        if sk.heal then
          g:text(1, 8, (T("Cura %d  SP %d")):format(sk.power, sk.cost), 18)
        else
          g:text(1, 8, (T("Poder +%d  SP %d")):format(sk.power, sk.cost), 18)
          g:text(1, 9, (T("Alcance %d-%d")):format(sk.rmin, sk.rmax), 18)
        end
        if it.disabled then
          g:text(1, 10, menu.unit.sp < sk.cost and T("SP insuficiente") or T("Sem alvo"), 18)
        end
      end
      g.textKey = menu.index
    end
    drawScreen(g, vx, vy, s)
    drawMenu(g, menu, vx, vy, s, 64)
  elseif menu and menu.kind == "endturn" then
    local g = GBHud.screen(b, "menu", GBUI.END_TURN, {})
    drawScreen(g, vx, vy, s)
    drawMenu(g, menu, vx, vy, s, 24)
  elseif menu and menu.kind == "goods" then
    local g = GBHud.screen(b, "menu", GBUI.GOODS, {})
    drawScreen(g, vx, vy, s)
    drawMenu(g, menu, vx, vy, s, 40)
  elseif menu and menu.kind == "goodslist" then
    local v = {}
    for id = 0, 11 do v[0xC4E0 + id] = b.inventory[id] or 0 end
    local g = GBHud.screen(b, "full", menu.first == 0 and GBUI.RECOVER or GBUI.SPECIAL, v)
    drawScreen(g, vx, vy, s)
    drawMenu(g, menu, vx, vy, s, 64)
  elseif menu and menu.kind == "state" then
    local g = GBHud.screen(b, "full", GBUI.STATE, GBHud.unitVars(menu.unit, 0xC900))
    drawScreen(g, vx, vy, s)
    GBHud.drawSprite(menu.unit.species, vx + 124 * s, vy + 32 * s, s)
    clickable(vx, vy, 160 * s, 144 * s, function() press("z") end)
  elseif menu and menu.kind == "bonus" then
    local v = GBHud.unitVars(menu.unit, 0xC900)
    for i, it in ipairs(menu.items) do v[0xCD0A + i - 1] = it.amount or 0 end
    v[0xCD14] = 1
    local g = GBHud.screen(b, "full", GBUI.LEVELUP, v)
    drawScreen(g, vx, vy, s)
    GBHud.drawSprite(menu.unit.species, vx + 120 * s, vy + 36 * s, s)
    drawMenu(g, menu, vx, vy, s, 64)
  else
    -- painel da unidade sob o cursor (ou da escolhida)
    local u = not b.banner and (b:unitAt(b.cursor.x, b.cursor.y) or b.selected)
    if u then
      local v = GBHud.unitVars(u, 0xC900)
      v[0xC274] = u.side == "ally" and 0 or 1
      local g = GBHud.screen(b, "panel", GBUI.PANEL, v)
      drawScreen(g, vx, vy, s)
    end
  end
  -- aviso de turno ("Ação do jogador" / "Ação inimiga")
  if b.banner then
    local g = GBHud.screen(b, "banner", b.banner.kind == "enemy" and GBUI.ENEMY_TURN or GBUI.PLAYER_TURN, {})
    drawScreen(g, vx, vy, s)
  end
  return true
end

-- Quebra o texto em linhas de `width` colunas (palavras inteiras).
local function wrap(text, width)
  local lines, cur = {}, ""
  for word in text:gmatch("%S+") do
    local n = utf8.len(cur) or #cur
    local wn = utf8.len(word) or #word
    if n == 0 then cur = word
    elseif n + 1 + wn <= width then cur = cur .. " " .. word
    else lines[#lines + 1] = cur; cur = word end
  end
  if #cur > 0 then lines[#lines + 1] = cur end
  return lines
end

-- Caixa de fala do original: com retrato ($BD:$5740, 12 colunas a partir da 6ª) ou sem
-- ($BD:$5380, 16 colunas a partir da 2ª); 4 linhas por vez (configuração $39:$40ED).
function GBHud.drawDialog(b, d, w, h, s, speakerOk)
  local page = d.pages[d.index]
  local withPortrait = page.speaker ~= nil and speakerOk
  local id = withPortrait and GBUI.TALK_PORTRAIT or GBUI.TALK_WIDE
  local v = {}
  if withPortrait then v[0xC270] = page.speaker end
  local g = GBHud.screen(b, "talk", id, v)
  if not g then return false end
  local col, width = withPortrait and 6 or 2, withPortrait and 12 or 16
  local lines = wrap(page.text, width)
  if b.set then b:set("dialogLayout", { shown = 4, total = #lines }) else b.dialogLayout = { shown = 4, total = #lines } end
  local key = d.index .. ":" .. d.line .. ":" .. tostring(page)
  if g.textKey ~= key then
    g:clear(col, 1, width, 4)
    for i = 0, 3 do
      local line = lines[d.line + i]
      if line then g:text(col, 1 + i, line, width) end
    end
    g.textKey = key
  end
  local vx, vy = GBHud.origin(w, h, s)
  drawScreen(g, vx, vy, s)
  clickable(vx, vy + g.wy * s, 160 * s, 48 * s, function() press("z") end)
  -- seta de "tem mais"
  local more = (d.line + 4 <= #lines) or d.index < #d.pages
  love.graphics.setColor(1, 1, 1, 0.6 + 0.4 * math.sin(love.timer.getTime() * 6))
  local ix, iy = vx + (col + width - 1) * s * 8, vy + g.wy * s + 5 * 8 * s
  if more then love.graphics.polygon("fill", ix, iy, ix + 6 * s, iy, ix + 3 * s, iy + 4 * s) end
  return true
end

return GBHud
