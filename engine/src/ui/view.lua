-- Desenho: mapa e unidades num canvas em baixa resolução (pixel art ampliado),
-- textos e painéis desenhados na resolução da janela para ficarem nítidos.
local Combat = require("src.game.combat")
local Names = require("src.game.names")

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
  View.GRAY = { { 0.97, 0.97, 0.92 }, { 0.68, 0.7, 0.75 }, { 0.38, 0.4, 0.48 }, { 0.08, 0.08, 0.12 } }
  View.portraitQuads = {}
  if assets.portraits then
    for p = 1, 0x4B do
      View.portraitQuads[p] = love.graphics.newQuad((p % 8) * 32, math.floor(p / 8) * 32, 32, 32, 256, 320)
    end
  end
  View.speakerQuads = {}
  if assets.speakers then
    for p = 0, 0x2F do
      View.speakerQuads[p] = love.graphics.newQuad((p % 8) * 32, math.floor(p / 8) * 32, 32, 32, 256, 192)
    end
  end
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
  local types = setmetatable({}, { __index = function(_, t) return Names.type_name(t) end })
  love.graphics.setFont(View.font)

  -- turno / fase
  panel(10, 10, 250, 30)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print(("Fase %d   Turno %d   %s"):format(b.stageIndex, b.turn,
    b.phase == "player" and "Sua vez" or "Inimigos"), 20, 16)

  if b.mode == "dialog" and b.dialog then
    View.drawDialog(b, w, h)
    return
  end

  -- unidade sob o cursor
  local u = b:unitAt(b.cursor.x, b.cursor.y) or b.selected
  if u then
    local pw, ph = 380, 92
    local px, py = 10, h - ph - 10
    panel(px, py, pw, ph)
    local pi = u.species                           -- retrato da espécie (bancos $F4/$F5)
    if View.assets.portraits and View.portraitQuads[pi] then
      love.graphics.setShader(View.shader)
      setPal(View.GRAY)
      love.graphics.setColor(1, 1, 1)
      love.graphics.draw(View.assets.portraits, View.portraitQuads[pi], px + 8, py + 10, 0, 2.25, 2.25)
      love.graphics.setShader()
    end
    px = px + 80
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
    for _, id in ipairs(u.skills or {}) do sk[#sk + 1] = Names.skill_name(id) end
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
    local mw = m.extraWide and 440 or (m.wide and 330 or 140)
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
  local help = ("Setas: mover   Z/Enter/clique: confirmar   X/botão direito: voltar   Esc: fim do turno   N: nomes e falas (%s)"):format(Names.mode == "oficial" and "PT" or "original")
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
    love.graphics.printf("Enter: voltar ao mapa-múndi", 0, h / 2 + 10, w, "center")
  end
end

-- Caixa de diálogo: retrato do falante (comando EA do script) e texto em páginas de 3 linhas.
function View.drawDialog(b, w, h)
  local d = b.dialog
  local page = d.pages[d.index]
  local bh = 120
  local bx, by, bw = 20, h - bh - 24, w - 40
  panel(bx, by, bw, bh)
  local tx = bx + 16
  if page.speaker and View.speakerQuads[page.speaker] then
    love.graphics.setShader(View.shader)
    setPal(View.GRAY)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(View.assets.speakers, View.speakerQuads[page.speaker], bx + 14, by + 14, 0, 2.875, 2.875)
    love.graphics.setShader()
    tx = bx + 124
  end
  love.graphics.setFont(View.font)
  local _, lines = View.font:getWrap(page.text, bw - (tx - bx) - 20)
  local shown = 4
  b.dialogLayout = { shown = shown, total = #lines }
  love.graphics.setColor(1, 1, 1)
  for i = 0, shown - 1 do
    local line = lines[d.line + i]
    if line then love.graphics.print(line, tx, by + 14 + i * 24) end
  end
  local more = (d.line + shown <= #lines) or d.index < #d.pages
  love.graphics.setColor(1, 1, 0.5, 0.6 + 0.4 * math.sin(love.timer.getTime() * 6))
  local ix, iy = bx + bw - 24, by + bh - 22
  if more then
    love.graphics.polygon("fill", ix, iy, ix + 12, iy, ix + 6, iy + 8)
  else
    love.graphics.rectangle("fill", ix + 2, iy, 8, 8)
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

-- Caixa de menu genérica (mapa-múndi).
local function drawMenuBox(m, w, h)
  local mw = m.wide and 440 or 260
  local mh = 12 + #m.items * 24 + (m.title and 26 or 0)
  local mx, my = (w - mw) / 2, math.max(50, (h - mh) / 2 - 40)
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

-- Mapa-múndi: o mapa da fase 0, os nós do grafo e o cursor (o líder do time).
function View.drawWorld(wd, data, campaign)
  local World = require("src.game.world")
  local w, h = love.graphics.getDimensions()
  local img = View.assets.stages[0]
  local cx, cy = wd:cursorPos()
  -- o painel de baixo cobre ~40 px do canvas: a câmera pode passar da borda de baixo do mapa
  local camx = math.max(0, math.min(img:getWidth() - View.W, cx * CELL + 8 - View.W / 2))
  local camy = math.max(0, math.min(img:getHeight() - View.H + 44, cy * CELL + 8 - (View.H - 44) / 2))
  camx, camy = math.floor(camx + 0.5), math.floor(camy + 0.5)
  local t = love.timer.getTime()

  love.graphics.setCanvas(View.canvas)
  love.graphics.clear(0.02, 0.05, 0.15, 1)
  love.graphics.push()
  love.graphics.translate(-camx, -camy)
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(img, 0, 0)
  -- marcadores das fases: vencida (verde), aberta (amarelo pulsando), trancada por item-chave (vermelho)
  for n, node in pairs(wd.world.nodes) do
    if World.kind(n) == "stage" then
      local st = wd:stageStatus(n)
      local px, py = node.x * CELL, node.y * CELL
      if st == "vencida" then
        love.graphics.setColor(0.2, 0.9, 0.35, 0.9)
        love.graphics.circle("fill", px + 13, py + 3, 3)
      elseif st == "trancada" then
        love.graphics.setColor(1, 0.25, 0.25, 0.9)
        love.graphics.rectangle("fill", px + 10, py + 1, 5, 5)
      else
        love.graphics.setColor(1, 1, 0.3, 0.55 + 0.45 * math.sin(t * 5))
        love.graphics.rectangle("line", px + 0.5, py + 0.5, CELL - 1, CELL - 1)
      end
    end
  end
  -- direções possíveis a partir do nó atual
  if wd.mode == "map" and not wd.anim then
    local node = wd:node()
    local dirs = { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }
    for d = 1, 4 do
      if node.nb[d] ~= 0 then
        local ok = wd:canMove(d)
        local ax, ay = node.x * CELL + 8 + dirs[d][1] * 13, node.y * CELL + 8 + dirs[d][2] * 13
        if ok then love.graphics.setColor(1, 1, 1, 0.6 + 0.4 * math.sin(t * 6)) else love.graphics.setColor(1, 0.2, 0.2, 0.8) end
        love.graphics.circle("fill", ax, ay, 2)
      end
    end
  end
  -- cursor: o primeiro Pokémon do time
  local leader = campaign:recruited()[1]
  love.graphics.setShader(View.shader)
  setPal(data.stages[0].allyPal)
  love.graphics.setColor(1, 1, 1)
  local bob = math.floor(math.abs(math.sin(t * 4)) * 2)
  love.graphics.draw(View.assets.units, View.quads[(leader and leader.species or 1) % 256],
    math.floor(cx * CELL + 0.5), math.floor(cy * CELL + 0.5) - bob)
  love.graphics.setShader()
  love.graphics.pop()
  love.graphics.setCanvas()

  local s, ox, oy = View.layout()
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(View.canvas, ox, oy, 0, s, s)

  -- topo: progresso
  love.graphics.setFont(View.font)
  local cleared = 0
  for i = 1, 25 do if campaign.cleared[i] then cleared = cleared + 1 end end
  panel(10, 10, 300, 30)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print(("Mapa-múndi   Fases vencidas: %d/25"):format(cleared), 20, 16)

  if wd.mode == "dialog" and wd.dialog then
    View.drawDialog(wd, w, h)
    return
  end

  -- painel do lugar
  local n = campaign.node
  local kind = World.kind(n)
  local ph = 84
  panel(10, h - ph - 26, w - 20, ph)
  love.graphics.setFont(View.big)
  love.graphics.setColor(1, 1, 0.6)
  love.graphics.print(Names.place_name(n), 24, h - ph - 20)
  love.graphics.setFont(View.font)
  love.graphics.setColor(0.85, 0.9, 1)
  local info
  if kind == "stage" then
    local st = wd:stageStatus(n)
    info = ("Fase %d  -  %d inimigos  -  %s"):format(n, #data.stages[n].enemies, st)
    local k = World.KEY_FOR_STAGE[n]
    if k then
      info = info .. ("  -  exige: %s%s"):format(Names.key_item_name(k),
        (campaign.keyItems[k] or 0) ~= 0 and " (tem)" or "")
    end
  elseif kind == "town" then
    local g = Names.mode == "oficial" and "Ginásio" or "Palaestra"
    info = ("Cidade: %s (treino, pode repetir), Prefeito e Morador"):format(g)
      .. (campaign.cleared[n] and ("  -  %s vencido"):format(g) or "")
  elseif kind == "institute" then
    info = "Instituto do Doutor: vantagens de tipo e dicas"
  else
    info = "Evolução: gasta a insígnia do tipo do Pokémon"
  end
  love.graphics.print(info, 24, h - ph + 14)
  local team = {}
  for _, r in ipairs(campaign:recruited()) do
    team[#team + 1] = ("%s %d"):format(Names.species_name(r.species), r.level)
  end
  love.graphics.setFont(View.small)
  love.graphics.setColor(0.75, 0.85, 1)
  love.graphics.printf("Time: " .. table.concat(team, ", "), 24, h - ph + 38, w - 60)

  if wd.menu and wd.mode == "menu" then drawMenuBox(wd.menu, w, h) end

  if #wd.log > 0 then
    local lw = 380
    panel(w - lw - 10, 10, lw, 12 + #wd.log * 18)
    love.graphics.setFont(View.small)
    for i, line in ipairs(wd.log) do
      love.graphics.setColor(1, 1, 1, 1 - (i - 1) * 0.25)
      love.graphics.print(line, w - lw, 16 + (i - 1) * 18)
    end
  end
  love.graphics.setFont(View.small)
  love.graphics.setColor(1, 1, 1, 0.75)
  love.graphics.printf(("Setas: andar   Z/Enter: entrar   X: voltar   N: nomes e falas (%s)   Delete: novo jogo"):format(Names.mode == "oficial" and "PT" or "original"),
    0, h - 18, w - 10, "right")
  love.graphics.setFont(View.font)
end

-- Escolha do time ("One can attack NN/MM"): elenco na ordem das vagas, A marca, START vai ao botão.
function View.drawTeam(ts, data)
  local w, h = love.graphics.getDimensions()
  love.graphics.clear(0.03, 0.08, 0.25)
  local types = setmetatable({}, { __index = function(_, t) return Names.type_name(t) end })
  love.graphics.setFont(View.big)
  love.graphics.setColor(1, 1, 1)
  local World = require("src.game.world")
  local title = ts.stage <= 25 and ("Fase %d - %s"):format(ts.stage, Names.place_name(ts.stage))
    or ("%s - %s"):format(Names.mode == "oficial" and "Ginásio" or "Palaestra", Names.place_name(ts.stage))
  love.graphics.print(title, 24, 14)
  love.graphics.setColor(1, 1, 0.5)
  love.graphics.printf(("Podem lutar: %02d/%02d"):format(ts:count(), ts.max), 0, 18, w - 24, "right")
  love.graphics.setFont(View.font)
  local rowH, top = 34, 60
  local visible = math.floor((h - top - 110) / rowH)
  local first = math.max(1, math.min(ts.cursor - math.floor(visible / 2), #ts.list - visible + 1))
  for i = first, math.min(#ts.list, first + visible - 1) do
    local u = ts.list[i]
    local y = top + (i - first) * rowH
    local sel = (i == ts.cursor and not ts.onButton)
    panel(24, y, w - 48, rowH - 4)
    if sel then
      love.graphics.setColor(1, 1, 0.4, 0.25)
      love.graphics.rectangle("fill", 26, y + 2, w - 52, rowH - 8, 5, 5)
    end
    love.graphics.setShader(View.shader)
    setPal(data.stages[ts.stage].allyPal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(View.assets.units, View.quads[u.species % 256], 64, y + 6, 0, 1.25, 1.25)
    love.graphics.setShader()
    love.graphics.setColor(ts.picked[i] and { 0.4, 1, 0.5 } or { 0.5, 0.55, 0.7 })
    love.graphics.print(ts.picked[i] and "[X]" or "[ ]", 34, y + 6)
    love.graphics.setColor(sel and { 1, 1, 0.5 } or { 1, 1, 1 })
    love.graphics.print(Names.species_name(u.species), 96, y + 6)
    love.graphics.setColor(TYPE_COLORS[u.type] or { 1, 1, 1 })
    love.graphics.print(types[u.type] or "?", 270, y + 6)
    love.graphics.setColor(0.85, 0.9, 1)
    love.graphics.print(("Nv %2d   HP %d   SP %d   ATK %d  PRE %d  ESQ %d  MOV %d"):format(u.level, u.maxhp,
      u.maxsp, u.atk, u.acc, u.eva, u.move), 390, y + 6)
  end
  -- botão "attack"
  local bw, bh = 220, 40
  local bx, by = (w - bw) / 2, h - bh - 46
  panel(bx, by, bw, bh)
  local ok = ts:count() >= 1
  love.graphics.setColor(ts.onButton and { 1, 1, 0.4 } or (ok and { 1, 1, 1 } or { 0.5, 0.5, 0.6 }))
  love.graphics.printf((ts.onButton and "> " or "") .. "Lutar!", bx, by + 11, bw, "center")
  love.graphics.setFont(View.small)
  love.graphics.setColor(1, 1, 1, 0.75)
  love.graphics.printf("Cima/baixo: escolher   Z/Enter: marcar   Esc: ir para Lutar   X: voltar ao mapa   " ..
    "(as marcadas entram na ordem da lista)", 0, h - 18, w - 10, "right")
  love.graphics.setFont(View.font)
end

return View
