-- Modo de duas telas (3DS via LÖVE Potion, ou --dual no PC para conferir):
--   tela de cima (400x240): o mapa (View.drawBattle/drawWorld com mapOnly)
--   tela de baixo (320x240): painéis compactos (unidade, prévia de ataque, menus, falas, registro)
local I18n = require("src.game.i18n")
local T = I18n.T
local View = require("src.ui.view")
local Names = require("src.game.names")
local Combat = require("src.game.combat")

local Dual = {}
Dual.TOP_W, Dual.TOP_H = 400, 240
Dual.BOT_W, Dual.BOT_H = 320, 240

function Dual.init()
  Dual.font = love.graphics.newFont(12)
  Dual.tiny = love.graphics.newFont(10)
end

local function panel(x, y, w, h)
  love.graphics.setColor(0.05, 0.1, 0.35, 0.95)
  love.graphics.rectangle("fill", x, y, w, h, 4, 4)
  love.graphics.setColor(0.45, 0.75, 1, 1)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 4, 4)
end

local function bg()
  love.graphics.clear(0.03, 0.06, 0.2)
end

-- Caixa de diálogo na tela de baixo (o objeto tem .dialog e recebe .dialogLayout).
local function dialog(o)
  local d = o.dialog
  local page = d.pages[d.index]
  panel(4, 4, 312, 196)
  local tx = 12
  if page.speaker and View.speakerQuads[page.speaker] then
    love.graphics.setColor(1, 1, 1)
    View.drawIndexed("speakers", View.speakerQuads[page.speaker], View.portraitPal or View.GRAY, 12, 12, 1.5, 1.5)
    tx = 66
  end
  love.graphics.setFont(Dual.font)
  local _, lines = Dual.font:getWrap(page.text, 312 - (tx - 4) - 10)
  local shown = 10
  o.dialogLayout = { shown = shown, total = #lines }
  love.graphics.setColor(1, 1, 1)
  for i = 0, shown - 1 do
    local line = lines[d.line + i]
    if line then love.graphics.print(line, tx, 12 + i * 18) end
  end
  love.graphics.setColor(1, 1, 0.5)
  love.graphics.print((d.line + shown <= #lines or d.index < #d.pages) and T("A: continuar") or T("A: fechar"), 236, 182)
end

local function menu(m)
  local h = 10 + #m.items * 20 + (m.title and 20 or 0)
  local y0 = math.max(4, math.floor((200 - h) / 2))
  panel(4, y0, 312, h)
  love.graphics.setFont(Dual.font)
  local ty = y0 + 5
  if m.title then
    love.graphics.setColor(0.7, 0.85, 1)
    love.graphics.printf(m.title, 10, ty, 300)
    ty = ty + 20
  end
  for i, it in ipairs(m.items) do
    love.graphics.setColor(i == m.index and { 1, 1, 0.4 } or { 1, 1, 1 })
    love.graphics.printf((i == m.index and "> " or "  ") .. it.label, 10, ty + (i - 1) * 20, 300)
  end
end

local function log(lines, y)
  love.graphics.setFont(Dual.tiny)
  for i = 1, math.min(3, #lines) do
    love.graphics.setColor(1, 1, 1, 1 - (i - 1) * 0.25)
    love.graphics.print(lines[i], 6, y + (i - 1) * 12)
  end
end

local function help(text)
  love.graphics.setFont(Dual.tiny)
  love.graphics.setColor(1, 1, 1, 0.6)
  love.graphics.printf(text, 0, 228, 316, "right")
end

local function unitInfo(u, y)
  panel(4, y, 312, 96)
  if View.portraitQuads[u.species] then
    love.graphics.setColor(1, 1, 1)
    View.drawIndexed("portraits", View.portraitQuads[u.species], View.portraitPal or View.GRAY, 10, y + 6, 1.5, 1.5)
  end
  love.graphics.setFont(Dual.font)
  love.graphics.setColor(u.side == "ally" and { 0.5, 1, 0.6 } or { 1, 0.55, 0.5 })
  love.graphics.print((T("%s  Nv %d")):format(u.name or Names.species_name(u.species), u.level), 64, y + 6)
  love.graphics.setColor(0.85, 0.9, 1)
  love.graphics.print(Names.type_name(u.type), 230, y + 6)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print(("HP %d/%d  SP %d/%d"):format(u.hp, u.maxhp, u.sp, u.maxsp), 64, y + 24)
  love.graphics.print((T("ATK %d PRE %d ESQ %d MOV %d")):format(u.atk, u.acc, u.eva, u.move), 64, y + 42)
  love.graphics.setFont(Dual.tiny)
  love.graphics.setColor(0.8, 0.85, 1)
  love.graphics.print((T("forte: %s  fraco: %s  alcance %d-%d")):format(Names.type_name(u.strong), Names.type_name(u.weak),
    u.rmin, u.rmax), 10, y + 62)
  local sk = {}
  for _, id in ipairs(u.skills or {}) do sk[#sk + 1] = Names.skill_name(id) end
  if #sk > 0 then love.graphics.printf(T("golpes: ") .. table.concat(sk, ", "), 10, y + 76, 300) end
end

function Dual.drawBattleBottom(b)
  bg()
  if b.mode == "dialog" and b.dialog then dialog(b) return end
  if b.result then
    love.graphics.setFont(Dual.font)
    love.graphics.setColor(1, 1, 0.5)
    love.graphics.printf(b.result == "vitória" and T("VITÓRIA!") or T("DERROTA..."), 0, 90, 320, "center")
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(T("A: voltar ao mapa-múndi"), 0, 120, 320, "center")
    return
  end
  if b.menu and (b.mode == "menu" or b.mode == "bonus") then
    menu(b.menu)
  elseif b.mode == "target" and require("src.game.options").get("preview") then
    local a, t, sk = b.selected, b.targets[b.targetIndex], b.action
    panel(4, 4, 312, 96)
    love.graphics.setFont(Dual.font)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(("%s -> %s"):format(a.name, t.name), 12, 10)
    if sk and sk.heal then
      love.graphics.print((T("Cura %d")):format(math.min(sk.power, t.maxhp - t.hp)), 12, 30)
    else
      local dmg = Combat.damage(a, t, sk and sk.power)
      love.graphics.print((T("Dano %d (HP %d -> %d)  Acerto %d%%")):format(dmg, t.hp, math.max(0, t.hp - dmg),
        Combat.hitChance(a, t)), 12, 30)
      local c = t.hp - dmg > 0 and Combat.counterFor(a, t, sk)
      love.graphics.print(c and (T("Contra: %d  Acerto %d%%")):format(Combat.damage(t, a, c ~= "normal" and c.power or nil),
        Combat.hitChance(t, a)) or T("Sem contra-ataque"), 12, 50)
    end
  else
    local u = b:unitAt(b.cursor.x, b.cursor.y) or b.selected
    if u then unitInfo(u, 4) end
  end
  log(b.log, 190)
  help(T("A confirma  B volta  START fim do turno"))
end

function Dual.drawWorldBottom(wd, data, campaign)
  bg()
  if wd.mode == "dialog" and wd.dialog then dialog(wd) return end
  if wd.menu and wd.mode == "menu" then
    menu(wd.menu)
  else
    local World = require("src.game.world")
    local n = campaign.node
    panel(4, 4, 312, 110)
    love.graphics.setFont(Dual.font)
    love.graphics.setColor(1, 1, 0.6)
    love.graphics.print(Names.place_name(n), 12, 10)
    love.graphics.setColor(0.85, 0.9, 1)
    local kind = World.kind(n)
    local info
    if kind == "stage" then
      info = (T("Fase %d - %d inimigos - %s")):format(n, #data.stages[n].enemies, T(wd:stageStatus(n)))
      local k = World.KEY_FOR_STAGE[n]
      if k then info = info .. T("\nexige: ") .. Names.key_item_name(k) end
    elseif kind == "town" then info = T("Cidade: Ginásio, Prefeito e Morador")
    elseif kind == "institute" then info = T("Vantagens de tipo e dicas")
    else info = T("Evolução com as insígnias") end
    love.graphics.printf(info, 12, 30, 296)
    local cleared = 0
    for i = 1, 25 do if campaign.cleared[i] then cleared = cleared + 1 end end
    love.graphics.print((T("Fases vencidas: %d/25")):format(cleared), 12, 90)
    local team = {}
    for _, r in ipairs(campaign:recruited()) do team[#team + 1] = ("%s %d"):format(Names.species_name(r.species), r.level) end
    love.graphics.setFont(Dual.tiny)
    love.graphics.setColor(0.75, 0.85, 1)
    love.graphics.printf(T("Time: ") .. table.concat(team, ", "), 8, 120, 304)
  end
  log(wd.log, 190)
  help(T("Direcional anda  A entra  B volta"))
end

function Dual.drawTeamBottom(ts, data)
  bg()
  love.graphics.setFont(Dual.font)
  love.graphics.setColor(1, 1, 0.5)
  love.graphics.print((T("Podem lutar: %02d/%02d")):format(ts:count(), ts.max), 8, 4)
  local rowH, top, visible = 22, 24, 8
  local first = math.max(1, math.min(ts.cursor - 3, #ts.list - visible + 1))
  for i = first, math.min(#ts.list, first + visible - 1) do
    local u = ts.list[i]
    local y = top + (i - first) * rowH
    local sel = (i == ts.cursor and not ts.onButton)
    if sel then love.graphics.setColor(1, 1, 0.4, 0.25); love.graphics.rectangle("fill", 4, y, 312, rowH - 2, 3, 3) end
    love.graphics.setColor(ts.picked[i] and { 0.4, 1, 0.5 } or { 0.5, 0.55, 0.7 })
    love.graphics.print(ts.picked[i] and "[X]" or "[ ]", 8, y + 3)
    love.graphics.setColor(1, 1, 1)
    View.drawIndexed("units", View.quads[u.species % 256], data.stages[ts.stage].allyPal, 36, y + 2)
    love.graphics.setColor(sel and { 1, 1, 0.5 } or { 1, 1, 1 })
    love.graphics.print((T("%s  Nv %d  HP %d")):format(Names.species_name(u.species), u.level, u.maxhp), 58, y + 3)
  end
  panel(110, 204, 100, 20)
  love.graphics.setColor(ts.onButton and { 1, 1, 0.4 } or { 1, 1, 1 })
  love.graphics.printf((ts.onButton and "> " or "") .. T("Lutar!"), 110, 207, 100, "center")
  help(T("A marca  START Lutar  B volta"))
end

-- Tela de cima da escolha do time: o mapa da fase com as posições iniciais.
function Dual.drawTeamTop(ts, data)
  love.graphics.clear(0, 0, 0)
  local img = View.assets.stages[ts.stage]
  local st = data.stages[ts.stage]
  local sc = math.min(Dual.TOP_W / img:getWidth(), Dual.TOP_H / img:getHeight())
  local ox, oy = (Dual.TOP_W - img:getWidth() * sc) / 2, (Dual.TOP_H - img:getHeight() * sc) / 2
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(img, ox, oy, 0, sc, sc)
  for _, e in ipairs(st.enemies) do
    love.graphics.setColor(1, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", ox + (e.x * 16 + 4) * sc, oy + (e.y * 16 + 4) * sc, 8 * sc, 8 * sc)
  end
  for i, p in ipairs(st.starts) do
    love.graphics.setColor(0.2, 0.6, 1, i <= ts.max and 0.95 or 0.3)
    love.graphics.rectangle("line", ox + (p.x * 16 + 2) * sc, oy + (p.y * 16 + 2) * sc, 12 * sc, 12 * sc)
  end
end

return Dual
