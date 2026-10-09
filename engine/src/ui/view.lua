-- Desenho: mapa e unidades num canvas em baixa resolução (pixel art ampliado),
-- textos e painéis desenhados na resolução da janela para ficarem nítidos.
local Combat = require("src.game.combat")

local View = {}
View.W, View.H = 320, 180          -- resolução lógica do mapa (20 x 11 casas)
local CELL = 16

local PAL_SHADER = [[
extern vec3 c0; extern vec3 c1; extern vec3 c2; extern vec3 c3;
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
  vec4 p = Texel(tex, tc);
  if (p.a < 0.5) discard;
  float i = floor(p.r * 3.0 + 0.5);
  vec3 c = i < 0.5 ? c0 : (i < 1.5 ? c1 : (i < 2.5 ? c2 : c3));
  return vec4(c, 1.0) * color;
}
]]

local TYPE_COLORS = {
  { 1.0, 0.85, 0.2 }, { 0.3, 0.75, 1.0 }, { 1.0, 0.4, 0.3 }, { 0.75, 0.45, 1.0 }, { 0.6, 0.8, 0.4 },
}

function View.init(assets)
  View.assets = assets
  View.canvas = love.graphics.newCanvas(View.W, View.H)
  View.shader = love.graphics.newShader(PAL_SHADER)
  View.font = love.graphics.newFont(14)
  View.small = love.graphics.newFont(11)
  View.big = love.graphics.newFont(22)
  View.quads = {}
  for s = 0, 255 do
    View.quads[s] = love.graphics.newQuad((s % 16) * 16, math.floor(s / 16) * 16, 16, 16, 256, 256)
  end
end

-- Escala e deslocamento do canvas na janela.
function View.layout()
  local w, h = love.graphics.getDimensions()
  local s = math.max(1, math.floor(math.min(w / View.W, h / View.H)))
  return s, math.floor((w - View.W * s) / 2), math.floor((h - View.H * s) / 2)
end

function View.camera(b)
  local st = b.stage
  local mw, mh = st.cols * CELL, st.rows * CELL
  local cx = b.cursor.x * CELL + 8 - View.W / 2
  local cy = b.cursor.y * CELL + 8 - View.H / 2
  cx = math.max(0, math.min(math.max(0, mw - View.W), cx))
  cy = math.max(0, math.min(math.max(0, mh - View.H), cy))
  -- câmera suave
  b.cam = b.cam or { x = cx, y = cy }
  b.cam.x = b.cam.x + (cx - b.cam.x) * 0.25
  b.cam.y = b.cam.y + (cy - b.cam.y) * 0.25
  return math.floor(b.cam.x + 0.5), math.floor(b.cam.y + 0.5)
end

local function setPal(pal)
  View.shader:send("c0", pal[1]); View.shader:send("c1", pal[2])
  View.shader:send("c2", pal[3]); View.shader:send("c3", pal[4])
end

local function drawCells(reach, cols, r, g, bl, a)
  love.graphics.setColor(r, g, bl, a)
  for k in pairs(reach) do
    love.graphics.rectangle("fill", (k % cols) * CELL + 1, math.floor(k / cols) * CELL + 1, CELL - 2, CELL - 2)
  end
end

function View.drawBattle(b)
  local st, cols = b.stage, b.stage.cols
  local camx, camy = View.camera(b)
  love.graphics.setCanvas(View.canvas)
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.push()
  love.graphics.translate(-camx, -camy)
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(View.assets.stages[b.stageIndex], 0, 0)

  -- alcance de movimento (azul, como no original) e de ataque (vermelho)
  if b.reach then
    drawCells(b.stops or b.reach, cols, 0.25, 0.55, 1, 0.55)
    local atk = {}
    local u = b.selected
    for k in pairs(b.stops or {}) do
      local x, y = k % cols, math.floor(k / cols)
      for dy = -u.rmax, u.rmax do
        for dx = -u.rmax, u.rmax do
          local d = math.abs(dx) + math.abs(dy)
          local tx, ty = x + dx, y + dy
          if d >= u.rmin and d <= u.rmax and tx >= 0 and ty >= 0 and tx < cols and ty < st.rows then
            local tk = ty * cols + tx
            if not b.stops[tk] then atk[tk] = true end
          end
        end
      end
    end
    drawCells(atk, cols, 1, 0.25, 0.25, 0.35)
  end
  if b.previewReach then drawCells(b.previewReach, cols, 1, 0.5, 0.2, 0.35) end

  -- unidades
  love.graphics.setShader(View.shader)
  for _, u in ipairs(b.units) do
    if u.hp > 0 then
      setPal(u.side == "ally" and st.allyPal or st.enemyPal)
      local dim = (u.acted and b.phase == "player" and u.side == "ally") and 0.5 or 1
      love.graphics.setColor(dim, dim, dim)
      love.graphics.draw(View.assets.units, View.quads[u.species % 256], u.x * CELL, u.y * CELL)
    end
  end
  love.graphics.setShader()

  -- barras de HP em cima das unidades
  for _, u in ipairs(b.units) do
    if u.hp > 0 then
      local w = math.max(1, math.floor(14 * u.hp / u.maxhp))
      love.graphics.setColor(0, 0, 0, 0.6)
      love.graphics.rectangle("fill", u.x * CELL + 1, u.y * CELL + 14, 14, 2)
      if u.side == "ally" then love.graphics.setColor(0.3, 1, 0.4) else love.graphics.setColor(1, 0.35, 0.3) end
      love.graphics.rectangle("fill", u.x * CELL + 1, u.y * CELL + 14, w, 2)
    end
  end

  -- cursor
  local t = love.timer.getTime()
  local pulse = 0.6 + 0.4 * math.sin(t * 8)
  love.graphics.setColor(1, 1, 1, pulse)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", b.cursor.x * CELL + 0.5, b.cursor.y * CELL + 0.5, CELL - 1, CELL - 1)
  love.graphics.pop()
  love.graphics.setCanvas()

  local s, ox, oy = View.layout()
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(View.canvas, ox, oy, 0, s, s)

  -- números de dano flutuando (na resolução da janela)
  love.graphics.setFont(View.big)
  for _, p in ipairs(b.popups) do
    local px = ox + (p.x * CELL - camx + 8) * s
    local py = oy + (p.y * CELL - camy) * s - p.t * 30
    love.graphics.setColor(0, 0, 0, 1 - p.t)
    love.graphics.printf(p.text, px - 49, py + 1, 100, "center")
    if p.heal then love.graphics.setColor(0.4, 1, 0.5, 1 - p.t) else love.graphics.setColor(1, 1, 0.3, 1 - p.t) end
    love.graphics.printf(p.text, px - 50, py, 100, "center")
  end

  View.drawHud(b, s, ox, oy, camx, camy)
end

local function panel(x, y, w, h)
  love.graphics.setColor(0.05, 0.1, 0.35, 0.88)
  love.graphics.rectangle("fill", x, y, w, h, 6, 6)
  love.graphics.setColor(0.45, 0.75, 1, 1)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, w, h, 6, 6)
end

function View.drawHud(b, s, ox, oy, camx, camy)
  local w, h = love.graphics.getDimensions()
  local types = { "Celerity", "Equilibrium", "Strength", "SuperPower", "Defense" }
  love.graphics.setFont(View.font)

  -- turno / fase
  panel(10, 10, 360, 30)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print(("Fase %d   Turno %d   %s   Pedras %d/%d/%d/%d/%d"):format(b.stageIndex, b.turn,
    b.phase == "player" and "Sua vez" or "Inimigos", b.stones[1], b.stones[2], b.stones[3], b.stones[4],
    b.stones[5]), 20, 16)

  -- unidade sob o cursor
  local u = b:unitAt(b.cursor.x, b.cursor.y) or b.selected
  if u then
    local pw, ph = 300, 92
    local px, py = 10, h - ph - 10
    panel(px, py, pw, ph)
    local tc = TYPE_COLORS[u.type] or { 1, 1, 1 }
    love.graphics.setColor(u.side == "ally" and { 0.5, 1, 0.6 } or { 1, 0.55, 0.5 })
    love.graphics.print(("%s  Nv %d"):format(u.name, u.level), px + 12, py + 8)
    love.graphics.setColor(tc)
    love.graphics.print(types[u.type] or "?", px + 190, py + 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(("HP %d/%d   SP %d/%d   EXP %d"):format(u.hp, u.maxhp, u.sp, u.maxsp, u.exp or 0), px + 12, py + 30)
    love.graphics.print(("ATK %d  PRE %d  ESQ %d  MOV %d  Alc %d-%d"):format(
      u.atk, u.acc, u.eva, u.move, u.rmin, u.rmax), px + 12, py + 52)
    love.graphics.setFont(View.small)
    love.graphics.setColor(0.8, 0.85, 1)
    local sk = {}
    for _, id in ipairs(u.skills or {}) do sk[#sk + 1] = ("#%02X"):format(id) end
    love.graphics.print(("forte: %s  fraco: %s%s"):format(types[u.strong] or "?", types[u.weak] or "?",
      #sk > 0 and ("  golpes: " .. table.concat(sk, " ")) or ""), px + 12, py + 72)
    love.graphics.setFont(View.font)
  end

  -- previsão de ataque
  if b.mode == "target" then
    local a, t, sk = b.selected, b.targets[b.targetIndex], b.action
    local dmg = sk and sk.heal and -math.min(sk.power, t.maxhp - t.hp) or Combat.damage(a, t, sk and sk.power)
    local counter = not (sk and sk.heal) and (t.hp - dmg > 0 and Combat.inRange(t, a.x, a.y))
    panel(w - 300, h - 102, 290, 92)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(("%s -> %s"):format(a.name, t.name), w - 288, h - 94)
    if sk and sk.heal then
      love.graphics.print(("Cura %d (HP %d -> %d)"):format(-dmg, t.hp, t.hp - dmg), w - 288, h - 72)
    else
      love.graphics.print(("Dano %d (HP %d -> %d)  Acerto %d%%"):format(dmg, t.hp, math.max(0, t.hp - dmg),
        Combat.hitChance(a, t)), w - 288, h - 72)
    end
    love.graphics.print(counter and ("Contra: %d  Acerto %d%%"):format(Combat.damage(t, a), Combat.hitChance(t, a))
      or "Sem contra-ataque", w - 288, h - 50)
    love.graphics.setFont(View.small)
    love.graphics.setColor(0.8, 0.85, 1)
    love.graphics.print("fórmula do jogo original ($01:6526)", w - 288, h - 28)
    love.graphics.setFont(View.font)
  end

  -- menus (ação, golpes, bônus de nível)
  if b.menu and (b.mode == "menu" or b.mode == "bonus") then
    local m = b.menu
    local mw = m.wide and 330 or 140
    local mh = 12 + #m.items * 24 + (m.title and 26 or 0)
    local mx, my
    if m.center or not b.selected then
      mx, my = (w - mw) / 2, (h - mh) / 2
    else
      mx = ox + (b.selected.x * CELL - camx + 20) * s
      my = oy + (b.selected.y * CELL - camy) * s
    end
    mx, my = math.max(10, math.min(mx, w - mw - 10)), math.max(50, math.min(my, h - mh - 30))
    panel(mx, my, mw, mh)
    local ty = my + 6
    if m.title then
      love.graphics.setColor(0.7, 0.85, 1)
      love.graphics.print(m.title, mx + 10, ty)
      ty = ty + 26
    end
    for i, it in ipairs(m.items) do
      love.graphics.setColor(i == m.index and { 1, 1, 0.4 } or { 1, 1, 1 })
      love.graphics.print((i == m.index and "> " or "  ") .. it.label, mx + 10, ty + (i - 1) * 24)
    end
  end

  -- registro de eventos
  if #b.log > 0 then
    local lw = 380
    panel(w - lw - 10, 10, lw, 12 + #b.log * 18)
    love.graphics.setFont(View.small)
    for i, line in ipairs(b.log) do
      love.graphics.setColor(1, 1, 1, 1 - (i - 1) * 0.2)
      love.graphics.print(line, w - lw, 16 + (i - 1) * 18)
    end
    love.graphics.setFont(View.font)
  end

  -- ajuda de controles
  love.graphics.setFont(View.small)
  love.graphics.setColor(1, 1, 1, 0.75)
  local help = "Setas: mover   Z/Enter/clique: confirmar   X/botão direito: voltar   Esc: fim do turno"
  love.graphics.printf(help, 0, h - 16, w - 10, "right")
  love.graphics.setFont(View.font)

  if b.result then
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setFont(View.big)
    love.graphics.setColor(1, 1, 0.5)
    love.graphics.printf(b.result == "vitória" and "VITÓRIA!" or "DERROTA...", 0, h / 2 - 30, w, "center")
    love.graphics.setFont(View.font)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Enter: voltar à seleção de fases", 0, h / 2 + 10, w, "center")
  end
end

-- Converte posição do mouse em casa do mapa.
function View.cellAt(b, mx, my)
  local s, ox, oy = View.layout()
  local camx, camy = math.floor(b.cam.x + 0.5), math.floor(b.cam.y + 0.5)
  local x = math.floor(((mx - ox) / s + camx) / CELL)
  local y = math.floor(((my - oy) / s + camy) / CELL)
  return x, y
end

function View.drawStageSelect(sel, data)
  local w, h = love.graphics.getDimensions()
  love.graphics.clear(0.04, 0.06, 0.16)
  love.graphics.setFont(View.big)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("Pocket Monster Saphire  -  protótipo", 20, 14)
  love.graphics.setFont(View.font)
  local names = { [0] = "Mapa-múndi" }
  for i = 26, 31 do names[i] = "Palaestra " .. (i - 25) end
  local listY, lineH = 60, 22
  local first = math.max(1, math.min(sel - 8, 31 - 17))
  for i = first, math.min(31, first + 17) do
    local st = data.stages[i]
    love.graphics.setColor(i == sel and { 1, 1, 0.4 } or { 0.85, 0.9, 1 })
    love.graphics.print(("%s Fase %2d  %s  (%d inimigos)"):format(i == sel and ">" or " ", i,
      names[i] or "Campanha", #st.enemies), 20, listY + (i - first) * lineH)
  end
  local img = View.assets.stages[sel]
  local maxw, maxh = w - 480, h - 100
  local sc = math.min(maxw / img:getWidth(), maxh / img:getHeight(), 2)
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(img, 450, 60, 0, sc, sc)
  -- marca inimigos e posições iniciais no preview
  local st = data.stages[sel]
  for _, e in ipairs(st.enemies) do
    love.graphics.setColor(1, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", 450 + (e.x * 16 + 4) * sc, 60 + (e.y * 16 + 4) * sc, 8 * sc, 8 * sc)
  end
  for _, p in ipairs(st.starts) do
    love.graphics.setColor(0.2, 0.5, 1, 0.9)
    love.graphics.rectangle("line", 450 + (p.x * 16 + 2) * sc, 60 + (p.y * 16 + 2) * sc, 12 * sc, 12 * sc)
  end
  love.graphics.setColor(1, 1, 1, 0.75)
  love.graphics.setFont(View.small)
  love.graphics.print("Cima/baixo: escolher   Enter/Z: jogar", 20, h - 24)
  love.graphics.setFont(View.font)
end

return View
