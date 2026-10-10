-- Estado de uma batalha: unidades, turnos, cursor, menus, progressão e IA inimiga.
local I18n = require("src.game.i18n")
local T = I18n.T
local Path = require("src.game.pathfind")
local Combat = require("src.game.combat")
local Progress = require("src.game.progress")
local Names = require("src.game.names")
local Items = require("src.game.items")
local Messages = require("src.game.messages")
local Sound = require("src.audio.sound")
local Options = require("src.game.options")
local nameOf = Names.species_name

local Battle = {}
Battle.__index = Battle

local TYPE_NAMES = { "Celerity", "Equilibrium", "Strength", "SuperPower", "Defense" }

local function newUnit(side, t)
  return {
    side = side, species = t.species, type = t.type, level = t.level,
    hp = t.hp, maxhp = t.hp, sp = t.sp, maxsp = t.sp,
    atk = t.atk, acc = t.acc, eva = t.eva, move = t.move, exp = 0,
    strong = t.strong, weak = t.weak, rmin = t.rmin, rmax = t.rmax,
    x = t.x, y = t.y, acted = false, skills = {},
  }
end

-- team: unidades do elenco escolhidas na tela de escolha (nil = todo o elenco recrutado)
function Battle.new(data, stageIndex, campaign, team)
  local st = data.stages[stageIndex]
  Combat.skills = data.prog.skills
  local self = setmetatable({
    data = data, prog = data.prog, stageIndex = stageIndex, stage = st, units = {}, steps = {},
    phase = "player", turn = 1, mode = "cursor",
    cursor = { x = 0, y = 0 }, selected = nil, reach = nil, prev = nil,
    menu = nil, popups = {}, queue = {}, timer = 0, result = nil, log = {}, pending = {},
    campaign = campaign, inventory = campaign.inventory,
    messages = (data.messages or {})[stageIndex] or {}, dialog = nil, visited = {},
  }, Battle)
  -- Aliados: o elenco recrutado da campanha, nas posições iniciais da fase.
  for i, r in ipairs(team or campaign:recruited()) do
    if i > #st.starts then break end
    local u = newUnit("ally", setmetatable({ x = st.starts[i].x, y = st.starts[i].y }, { __index = r }))
    u.maxhp, u.maxsp, u.exp, u.slot = r.maxhp, r.maxsp, r.exp, r.slot
    for _, id in ipairs(r.skills) do u.skills[#u.skills + 1] = id end
    self.units[#self.units + 1] = u
  end
  for i, e in ipairs(st.enemies) do
    local u = newUnit("enemy", e)
    u.enemySlot = i - 1                       -- vaga em $B200 + vaga*64 (a vaga 0 é o chefe)
    if e.skill then u.skills[1] = e.skill end
    self.units[#self.units + 1] = u
  end
  for _, u in ipairs(self.units) do u.name = nameOf(u.species) end
  local first = self:alive("ally")[1]
  if first then self.cursor.x, self.cursor.y = first.x, first.y end
  return self
end

function Battle:refreshNames()
  for _, u in ipairs(self.units) do u.name = nameOf(u.species) end
end

function Battle:skill(id)
  local s = self.prog.skills[id]
  if s then s.id = id end
  return s
end

function Battle:alive(side)
  local out = {}
  for _, u in ipairs(self.units) do
    if u.hp > 0 and (side == nil or u.side == side) then out[#out + 1] = u end
  end
  return out
end

function Battle:unitAt(x, y)
  for _, u in ipairs(self.units) do
    if u.hp > 0 and u.x == x and u.y == y then return u end
  end
end

function Battle:say(msg)
  table.insert(self.log, 1, msg)
  self.logAt = love.timer and love.timer.getTime() or 0
  if #self.log > 5 then table.remove(self.log) end
end

function Battle:computeReach(u)
  local blocked = function(x, y)
    local o = self:unitAt(x, y)
    return o ~= nil and o.side ~= u.side
  end
  return Path.reach(self.stage, self.data.costs, u, blocked)
end

function Battle:stopCells(u, reach)
  local cols, out = self.stage.cols, {}
  for k in pairs(reach) do
    local x, y = k % cols, math.floor(k / cols)
    local o = self:unitAt(x, y)
    if o == nil or o == u then out[k] = true end
  end
  return out
end

-- Alvos de uma ação a partir de (x,y). skill nil = ataque normal.
function Battle:targetsFrom(u, x, y, skill)
  local out = {}
  local rmin, rmax = Combat.actionRange(u, skill)
  local wantAllies = skill and skill.heal
  local side = (u.side == "ally") == (wantAllies == true) and "ally" or "enemy"
  for _, o in ipairs(self:alive(side)) do
    local d = Path.dist(x, y, o.x, o.y)
    if d >= rmin and d <= rmax and (not wantAllies or (o.hp < o.maxhp)) then out[#out + 1] = o end
  end
  return out
end

function Battle:usableSkills(u)
  local out = {}
  for _, id in ipairs(u.skills) do
    local s = self:skill(id)
    if s and u.sp >= s.cost and #self:targetsFrom(u, u.x, u.y, s) > 0 then out[#out + 1] = s end
  end
  return out
end

---------------------------------------------------------------- ações do jogador

function Battle:moveCursor(dx, dy)
  if self.mode == "target" then
    local t = self.targets
    if #t == 0 then return end
    self.targetIndex = (self.targetIndex + (dx + dy) - 1) % #t + 1
    self.cursor.x, self.cursor.y = t[self.targetIndex].x, t[self.targetIndex].y
    return
  end
  if self.mode ~= "cursor" and self.mode ~= "move" then return end
  self.cursor.x = math.max(0, math.min(self.stage.cols - 1, self.cursor.x + dx))
  self.cursor.y = math.max(0, math.min(self.stage.rows - 1, self.cursor.y + dy))
end

function Battle:confirm()
  if self.result or self.mode == "dialog" then return end
  if self.mode == "bonus" or self.mode == "menu" then
    local it = self.menu.items[self.menu.index]
    if it.disabled and not it.open then return end
    it.action()
    return
  end
  if self.phase ~= "player" then return end
  local c = self.cursor
  if self.mode == "cursor" then
    local u = self:unitAt(c.x, c.y)
    if u and u.side == "ally" and not u.acted then
      self.selected, self.noUndo = u, false
      self.preview, self.previewReach = nil, nil
      self.reach, self.prev = self:computeReach(u)
      self.stops = self:stopCells(u, self.reach)
      self.mode = "move"
    elseif u then
      self.preview = u
      self.previewReach = self:computeReach(u)
    else
      self:openMapMenu()                      -- casa vazia: menu do mapa, como no original
    end
  elseif self.mode == "move" then
    local k = c.y * self.stage.cols + c.x
    if self.stops[k] then
      local u = self.selected
      self.origin = { x = u.x, y = u.y }
      local path = Path.route(self.prev, self.stage.cols, u.y * self.stage.cols + u.x, k)
      self.reach = nil
      self.mode = "walk"
      self:walk(u, path, function()
        self.mode = "cursor"
        if not self:triggerEvent(u) then self:openMenu(u) end
      end)
    end
  elseif self.mode == "target" then
    local u, t, s = self.selected, self.targets[self.targetIndex], self.action
    if not t then return end                  -- nada ao alcance: só B volta
    if s and s.heal then
      for _, ev in ipairs(Combat.heal(u, t, s)) do self:announce(ev) end
    else
      self:attack(u, t, s)
    end
    self:finishUnit(u)
  end
end

---------------------------------------------------------------- eventos e diálogos

-- Eventos ao parar numa casa ($01:$4D37, terreno = 3º byte da tabela +2C da fase):
--   15        centro de cura: mostra a mensagem 15 e enche HP/SP (repete)
--   16, 17    nada
--   18..32    casas e baús: mostra a mensagem de mesmo número, uma vez por entrada na fase
--             (flags $C518 + t - 18, zeradas ao entrar na fase)
--   27 ($1B)  em vez de mensagem, ensina um golpe a certas espécies ($09:$4C12, ver LEARN_SPOTS)
-- Golpe ensinado pelo terreno $1B: fase -> { espécies, golpe } ($09:$4C5E/$4CA8/$4CF2).
-- O original grava no 4º espaço de golpe só se ele estiver vazio.
Battle.LEARN_SPOTS = {
  [21] = { species = { [0x1C] = true, [0x1D] = true }, skill = 0x57 },
  [18] = { species = { [0x27] = true, [0x28] = true }, skill = 0x1E },
  [8] = { species = { [0x2E] = true, [0x2F] = true }, skill = 0x45 },
}

function Battle:triggerEvent(u)
  local st = self.stage
  local t = st.terrain[u.y * st.cols + u.x + 1]
  if t == 0x1B then return self:learnSpot(u) end
  if t ~= 15 and (t < 18 or t > 32) then return false end
  local msg = self.messages[t]
  if not msg then return false end
  local heal = (t == 15)
  if not heal and self.visited[t] then return false end
  if heal then
    u.hp, u.sp = u.maxhp, u.maxsp
    self:say(u.name .. T(" foi curado"))
  else
    self.visited[t] = true
  end
  self.eventUnit = u
  self.noUndo = true                          -- depois de um evento não dá para desfazer o movimento
  self:showMessage(msg, function() self:openMenu(u) end)
  return true
end

function Battle:learnSpot(u)
  local spot = Battle.LEARN_SPOTS[self.stageIndex]
  if not spot or not spot.species[u.species] or #u.skills >= 4 then return false end
  for _, id in ipairs(u.skills) do if id == spot.skill then return false end end
  u.skills[#u.skills + 1] = spot.skill
  self:say((T("%s aprendeu %s!")):format(u.name, Names.skill_name(spot.skill)))
  self.popups[#self.popups + 1] = { x = u.x, y = u.y, text = T("GOLPE NOVO"), t = 0, heal = true }
  return false
end

-- Aplica os efeitos do script (itens, recrutamento, itens-chave) e abre a caixa de diálogo.
function Battle:showMessage(msg, onClose)
  msg = Messages.resolve(msg, self.campaign)
  for _, ef in ipairs(msg.effects) do
    if ef.item then
      self.inventory[ef.item] = (self.inventory[ef.item] or 0) + 1
      self:say(T("Recebeu ") .. Items.name(ef.item))
    elseif ef.recruit then
      local r = self.campaign:recruit(ef.recruit)
      if r then self:say(nameOf(r.species) .. T(" entrou no time!")) end
    elseif ef.key then
      self.campaign.keyItems[ef.key] = ef.value
    end
  end
  if #msg.pages == 0 then if onClose then onClose() end return end
  self.dialog = { pages = msg.pages, index = 1, line = 1, onClose = onClose, prevMode = self.mode }
  self.mode = "dialog"
end

function Battle:advanceDialog(linesShown, totalLines)
  local d = self.dialog
  if d.line + linesShown <= totalLines then
    d.line = d.line + linesShown
    return
  end
  d.index, d.line = d.index + 1, 1
  if d.index > #d.pages then
    self.dialog = nil
    self.mode = "cursor"
    if d.onClose then d.onClose() end
  end
end

-- Sem alvo ao alcance, o modo de alvo abre do mesmo jeito (só mostra o alcance em laranja); B volta.
function Battle:chooseTarget(u, skill)
  local targets = self:targetsFrom(u, u.x, u.y, skill)
  self.action, self.targets, self.targetIndex = skill, targets, #targets > 0 and 1 or 0
  local t = targets[1] or u
  self.cursor.x, self.cursor.y = t.x, t.y
  self.mode = "target"
  if #targets == 0 then self:say(T("Nenhum alvo ao alcance.")) end
end

-- Menu de ação como no original ($BD:$40F0): sempre as cinco opções, as que não dão para usar
-- ficam apagadas (Atacar sem alvo, Skill sem SP/alvo, Itens sem item usável), mas Atacar, Skill e
-- Itens ainda abrem (open): mostram o alcance, os golpes ou os itens e por que não dá para usar.
function Battle:openMenu(u)
  local hasTarget = #self:targetsFrom(u, u.x, u.y) > 0
  local items = {
    { id = "attack", label = T("Atacar"), disabled = not hasTarget, open = true,
      action = function() self:chooseTarget(u, nil) end },
    { id = "skill", label = T("Skill"), disabled = #self:usableSkills(u) == 0, open = true,
      action = function() self:openSkillMenu(u) end },
    { id = "goods", label = T("Itens"), disabled = #self:usableItems(u) == 0, open = true,
      action = function() self:openGoodsMenu(u) end },
    { id = "state", label = T("Estado"), action = function() self:openStateView(u) end },
    { id = "rest", label = T("Esperar"), action = function() self:finishUnit(u) end },
  }
  local first = 1
  while items[first].disabled do first = first + 1 end
  self.menu = { kind = "actions", items = items, index = first, title = u.name, unit = u }
  self.mode = "menu"
end

-- Golpes da unidade nas quatro vagas ($BD:$41C8); os que não dão para usar ficam apagados.
function Battle:openSkillMenu(u)
  local usable = {}
  for _, sk in ipairs(self:usableSkills(u)) do usable[sk.id] = sk end
  local items = {}
  for i = 1, 4 do
    local id = u.skills[i]
    local sk = id and self:skill(id)
    local label = sk and (sk.heal and ("%s  +%d HP  %d SP"):format(Names.skill_name(id), sk.power, sk.cost)
      or ("%s  +%d  %d SP  %d-%d"):format(Names.skill_name(id), sk.power, sk.cost, sk.rmin, sk.rmax)) or "-"
    items[i] = { label = label, skill = sk, disabled = not (id and usable[id]),
      action = function() self:chooseTarget(u, sk) end }
  end
  local first = 1
  while items[first] and items[first].disabled do first = first + 1 end
  self.menu = { kind = "skills", items = items, index = first <= 4 and first or 1, title = T("Golpes"),
    parent = u, unit = u, wide = true, extraWide = true }
end

-- Itens ($BD:$4180): recuperação (ids 0-5, $BD:$43A8) ou especiais (pedras, ids 6-11, $BD:$4678).
function Battle:openGoodsMenu(u)
  local function any(a, b)
    for id = a, b do
      if (self.inventory[id] or 0) > 0 and Items.usable(id, u, self.prog) then return true end
    end
    return false
  end
  self.menu = { kind = "goods", index = 1, title = T("Itens"), parent = u, unit = u, items = {
    { label = T("Recuperação"), disabled = not any(0, 5), open = true, action = function() self:openGoodsList(u, 0) end },
    { label = T("Especial"), disabled = not any(6, 11), open = true, action = function() self:openGoodsList(u, 6) end },
  } }
  if self.menu.items[1].disabled then self.menu.index = 2 end
end

function Battle:openGoodsList(u, first)
  local items = {}
  for id = first, first + 5 do
    local n = self.inventory[id] or 0
    items[#items + 1] = {
      label = ("%s x%d  %s"):format(Items.name(id), n, Items.desc(id)), item = id,
      disabled = n == 0 or not Items.usable(id, u, self.prog),
      action = function() self:useItem(u, id) end }
  end
  local idx = 1
  while items[idx] and items[idx].disabled do idx = idx + 1 end
  self.menu = { kind = "goodslist", first = first, items = items, index = idx <= 6 and idx or 1,
    title = T("Itens"), parent = u, unit = u, wide = true, extraWide = true,
    back = function() self:openGoodsMenu(u) end }
end

-- Estado da unidade ($BD:$4948): qualquer botão volta ao menu.
function Battle:openStateView(u)
  self.menu = { kind = "state", index = 1, unit = u, parent = u, title = u.name,
    items = { { label = T("Voltar"), action = function() self:openMenu(u) end } } }
end

function Battle:usableItems(u)
  local out = {}
  for id = 0x00, 0x10 do
    if (self.inventory[id] or 0) > 0 and not Items.list[id].badge and Items.usable(id, u, self.prog) then
      out[#out + 1] = id
    end
  end
  return out
end

-- As insígnias só são usadas na BabyAlliance ("Role evolve", $01:$5630), fora da luta.
-- Usar item gasta a ação da unidade (como escolher "Goods" no original).
function Battle:useItem(u, id)
  self.inventory[id] = self.inventory[id] - 1
  local it = Items.list[id]
  it.use(u)
  self:say((T("%s usou %s (%s)")):format(u.name, Items.name(id), Items.desc(id)))
  self.popups[#self.popups + 1] = { x = u.x, y = u.y, text = Items.desc(id), t = 0, heal = true }
  self:finishUnit(u)
end

function Battle:cancel()
  if self.mode == "bonus" then return end
  if self.mode == "move" then
    self.mode, self.selected, self.reach = "cursor", nil, nil
  elseif self.mode == "menu" then
    if self.menu.back then self.menu.back() return end
    if self.menu.parent then self:openMenu(self.menu.parent) return end
    if self.noUndo or not Options.get("undo") then return end
    local u = self.selected
    u.x, u.y = self.origin.x, self.origin.y
    self.cursor.x, self.cursor.y = u.x, u.y
    self.reach, self.prev = self:computeReach(u)
    self.stops = self:stopCells(u, self.reach)
    self.mode, self.menu = "move", nil
  elseif self.mode == "target" then
    self.cursor.x, self.cursor.y = self.selected.x, self.selected.y
    self:openMenu(self.selected)
  else
    self.preview, self.previewReach = nil, nil
  end
end

function Battle:menuMove(d)
  if self.menu then
    local m = self.menu
    m.index = (m.index - 1 + d) % #m.items + 1
    Sound.sfx(Sound.CURSOR)
  end
end

function Battle:finishUnit(u)
  u.acted = true
  self.selected, self.reach, self.action = nil, nil, nil
  if self.mode ~= "bonus" then self.mode, self.menu = "cursor", nil end
  self.cursor.x, self.cursor.y = u.x, u.y
  self:checkEnd()
  self:afterAction()
end

function Battle:afterAction()
  if self.result or self.ending or #self.pending > 0 or self.phase ~= "player" then return end
  for _, a in ipairs(self:alive("ally")) do if not a.acted then return end end
  self:endPlayerTurn()
end

-- Encerrar o turno com Pokémon que ainda não agiram pede confirmação (tela $BC:$484C do original,
-- "Are you sure to end this turn? Yes / No"). SUPOSIÇÃO: quando o original mostra essa tela não foi
-- achado (o "End" do menu do mapa encerra direto); no motor ela evita encerrar sem querer.
-- Menu do mapa ($BD:$4C18, tela $09 do script $BC): A numa casa vazia. Opções do original: Time,
-- Salvar, Carregar, Objetivo e Fim. Fim encerra o turno (com a confirmação $0D se alguém ainda não
-- agiu); Objetivo mostra a tela $0F. Time (tela $0A) e salvar/carregar no meio da fase ainda não
-- existem no motor (a campanha é salva ao fim de cada fase): ficam apagadas.
function Battle:openMapMenu()
  if self.phase ~= "player" or self.result then return end
  self.preview, self.previewReach = nil, nil
  local function close() self.mode, self.menu = "cursor", nil end
  self.menu = { kind = "mapmenu", index = 4, back = close, items = {
    { id = "team", label = T("Time"), disabled = true },
    { id = "save", label = T("Salvar"), disabled = true },
    { id = "load", label = T("Carregar"), disabled = true },
    { id = "goal", label = T("Objetivo"), action = function()
        self.menu = { kind = "objective", index = 1, back = function() self:openMapMenu() end,
          items = { { label = T("Voltar"), action = function() self:openMapMenu() end } } }
      end },
    { id = "end", label = T("Fim"), action = function() close(); self:askEndTurn() end },
  } }
  self.mode = "menu"
end

function Battle:askEndTurn()
  if self.phase ~= "player" or self.result then return end
  local pending = false
  for _, a in ipairs(self:alive("ally")) do if not a.acted then pending = true end end
  if not pending then self:endPlayerTurn() return end
  self.preview, self.previewReach = nil, nil
  local prev = { mode = self.mode, menu = self.menu }
  local function close() self.mode, self.menu = prev.mode == "menu" and "cursor" or prev.mode, nil end
  self.menu = { kind = "endturn", index = 1, title = T("Encerrar o turno?"), center = true, back = close,
    items = {
      { label = T("Sim"), action = function() self.menu = nil; self:endPlayerTurn() end },
      { label = T("Não"), action = close },
    } }
  self.mode = "menu"
end

function Battle:endPlayerTurn()
  if self.phase ~= "player" or self.result then return end
  self.mode, self.selected, self.reach, self.menu = "cursor", nil, nil, nil
  self.phase = "enemy"
  self:say((T("Turno %d: inimigos")):format(self.turn))
  -- o original percorre os inimigos da última vaga para a primeira ($B6C0 -> $B200)
  self.queue = {}
  local enemies = self:alive("enemy")
  for i = #enemies, 1, -1 do self.queue[#self.queue + 1] = enemies[i] end
  self.banner = { kind = "enemy", t = Battle.BANNER_TIME }        -- "Enemy action" ($BD:$55B0)
  self.timer = Battle.BANNER_TIME
end

---------------------------------------------------------------- ataque e animação original

-- Quando o main liga Battle.animHook (opção "animações" + ROM no cache), o ataque guarda um pedido
-- de animação (estado de antes + resultado) e os anúncios (dano, EXP) esperam a cena terminar.
Battle.animHook = false

local function unitBefore(u)
  return { species = u.species, level = u.level, hp = u.hp, maxhp = u.maxhp, sp = u.sp, maxsp = u.maxsp,
    atk = u.atk, acc = u.acc, eva = u.eva, move = u.move, type = u.type, strong = u.strong, weak = u.weak,
    rmin = u.rmin, rmax = u.rmax, x = u.x, y = u.y }
end

function Battle:attack(att, def, skill, enemyTurn)
  local a0, d0 = unitBefore(att), unitBefore(def)
  local evs = Combat.attack(att, def, skill, enemyTurn)
  if not Battle.animHook then
    for _, ev in ipairs(evs) do self:announce(ev) end
    return evs
  end
  local e1, e2 = evs[1], evs[2]
  self.anim = {
    att = a0, def = d0, skill = skill and skill.id, hit = e1.hit, dmg = e1.dmg,
    counter = e2 and { skill = e2.skill, hit = e2.hit, dmg = e2.dmg } or nil,
    enemyTurn = enemyTurn and true or false, stage = self.stageIndex,
    terrain = self.stage.terrain[def.y * self.stage.cols + def.x + 1] or 0, evs = evs,
  }
  return evs
end

-- Fim da cena (ou cena pulada/indisponível): anuncia o resultado.
function Battle:finishAnim()
  local a = self.anim
  self.anim = nil
  if a then for _, ev in ipairs(a.evs) do self:announce(ev) end end
end

---------------------------------------------------------------- eventos, EXP e nível

function Battle:announce(ev)
  local who = (ev.counter and T("Contra: ") or "") .. ev.who.name
  local tag = ev.skill and (" [%s]"):format(Names.skill_name(ev.skill)) or ""
  if ev.heal then
    self:say((T("%s cura %d de %s%s")):format(ev.who.name, ev.heal, ev.target.name, tag))
    self.popups[#self.popups + 1] = { x = ev.target.x, y = ev.target.y, text = "+" .. ev.heal, t = 0, heal = true }
    return
  end
  if not ev.hit then
    self:say((T("%s errou %s%s")):format(who, ev.target.name, tag))
    self.popups[#self.popups + 1] = { x = ev.target.x, y = ev.target.y, text = T("errou"), t = 0 }
    return
  end
  local adv = ev.mult > 1 and T(" (forte!)") or (ev.mult < 1 and T(" (fraco)") or "")
  self:say((T("%s causa %d em %s%s%s")):format(who, ev.dmg, ev.target.name, adv, tag))
  self.popups[#self.popups + 1] = { x = ev.target.x, y = ev.target.y, text = tostring(ev.dmg), t = 0 }
  if ev.target.hp == 0 then self:say(ev.target.name .. T(" caiu!")) end
  if ev.who.side == "ally" and ev.exp > 0 then self:grantExp(ev.who, ev.exp) end
end

function Battle:grantExp(u, amount)
  -- Combat.strike já somou em u.exp; desfaz e passa pela regra de progressão.
  u.exp = u.exp - amount
  local ups = Progress.gainExp(u, amount, self.prog)
  self:say((T("%s ganhou %d EXP")):format(u.name, amount))
  for _, d in ipairs(ups) do
    self:say((T("%s subiu para o nível %d! HP+%d SP+%d ATK+%d PRE+%d ESQ+%d")):format(
      u.name, u.level, d.hp, d.sp, d.atk, d.acc, d.eva))
    self.popups[#self.popups + 1] = { x = u.x, y = u.y, text = T("NÍVEL ") .. u.level, t = 0, heal = true }
    self.pending[#self.pending + 1] = u
  end
  if #ups == 0 and u.level >= (self.prog.maxLevel[u.species] or 99) and not self.prog.final[u.species] then
    self:say(u.name .. T(" está no nível máximo da forma: precisa evoluir"))
  end
  self:openBonusIfPending()
end

-- Depois de subir de nível, o jogador escolhe um bônus extra (como no original).
function Battle:openBonusIfPending()
  if self.mode == "bonus" or #self.pending == 0 then return end
  local u = self.pending[1]
  local items = {}
  for _, opt in ipairs(Progress.bonusOptions(self.prog, u)) do
    items[#items + 1] = { label = ("%s +%d"):format(T(Progress.LABELS[opt.stat]), opt.amount), amount = opt.amount,
      action = function()
      Progress.applyBonus(u, opt)
      self:say(("%s: %s +%d"):format(u.name, T(Progress.LABELS[opt.stat]), opt.amount))
      table.remove(self.pending, 1)
      self.menu, self.mode = nil, "cursor"
      if #self.pending > 0 then self:openBonusIfPending()
      elseif self.victoryAfterBonus then self.victoryAfterBonus = false; self:checkEnd()
      else self:afterAction() end
    end }
  end
  self.bonusUnit = u
  self.menu = { kind = "bonus", unit = u, items = items, index = 1, title = (T("%s - nível %d: escolha um bônus")):format(u.name, u.level),
    center = true, wide = true }
  self.mode = "bonus"
end

function Battle:checkEnd()
  if self.result or self.ending then return end
  if #self:alive("enemy") == 0 and (#self.pending > 0 or self.mode == "bonus") then
    self.victoryAfterBonus = true                 -- termina de escolher os bônus antes
    return
  end
  if #self:alive("enemy") == 0 then
    self.ending = true
    self.campaign:storeUnits(self.units)
    self.campaign.cleared[self.stageIndex] = true
    Sound.music(self.stageIndex == 25 and Sound.ENDING or Sound.VICTORY)
    local finish = function()
      self.result = "vitória"
      self.campaign:save()
    end
    -- mensagem 33: recompensa e quem entra no time ($C2B1 = $21 no fim da fase; só fases < $1A)
    local msg = self.stageIndex <= 25 and self.messages[33]
    if msg then
      self.queue = {}
      self:showMessage(msg, finish)
    else
      finish()
    end
  elseif #self:alive("ally") == 0 then
    self.result = "derrota"
  end
end

---------------------------------------------------------------- IA inimiga

-- IA do jogo original ($01:$6B95). Os inimigos agem da última vaga para a primeira. Para cada um:
--  1. Se o 1º golpe é de cura ($01-$0B) e HP <= HP máx/2: cura a si mesmo se tiver SP (soma
--     $18:$697B[golpe]); com ou sem SP, o turno dele acaba aí.
--  2. Procura um aliado colado (anel de raio 1, na ordem cima, direita, esquerda, baixo) e ataca.
--     O raio da busca é sempre 1 ([$C9BE] = [$C9BF] = 1), qualquer que seja o alcance da unidade.
--  3. A vaga 0 (o chefe) nunca anda.
--  4. Calcula o alcance (MOV até 16; só outros inimigos bloqueiam a passagem, ids >= $A1 em $A000).
--     Para cada aliado vivo, na ordem das vagas do elenco, procura em volta dele (raio 1) uma casa
--     alcançável e vazia ($01:$7133 + $09:$4F74); achando, anda até lá e ataca o primeiro aliado
--     colado (de novo na ordem cima, direita, esquerda, baixo).
--  5. Senão, repete o passo 4 com o raio 4 (anéis do mais distante para o mais próximo, $09:$5088)
--     e só se aproxima, sem atacar. Sem casa possível, fica parado.
-- O ataque é sempre o normal ($01:$6AA9 zera o golpe), com contra-ataque.

function Battle:aiRing(r)
  return (self.data.ai and self.data.ai.rings[r]) or {}
end

-- Primeiro aliado (vivo) colado a (x, y) na ordem do anel de raio 1.
function Battle:aiAdjacentAlly(x, y)
  for _, off in ipairs(self:aiRing(1)) do
    if not off.stop then
      local u = self:unitAt(x + off.dx, y + off.dy)
      if u and u.side == "ally" then return u end
    end
  end
end

-- Casa de destino: em volta de cada aliado (ordem das vagas), a primeira casa alcançável e vazia.
function Battle:aiDestination(stops, radius)
  local st, cols = self.stage, self.stage.cols
  local allies = self:alive("ally")
  table.sort(allies, function(a, b) return (a.slot or 0) < (b.slot or 0) end)
  for _, a in ipairs(allies) do
    for _, off in ipairs(self:aiRing(radius)) do
      if not off.stop then
        local x, y = a.x + off.dx, a.y + off.dy
        if x >= 0 and y >= 0 and x < cols and y < st.rows and st.terrain[y * cols + x + 1] ~= 0
          and not self:unitAt(x, y) and stops[y * cols + x] then
          return x, y
        end
      end
    end
  end
end

---------------------------------------------------------------- andar casa a casa

-- No original a unidade anda casa a casa, 4 px por quadro com um quadro parado a cada três
-- (~6 quadros por casa, medido no PyBoy na fase 1); no turno inimigo a câmera vai até o inimigo,
-- ele anda e há uma pausa de ~27 quadros antes da próxima ação.
Battle.TILE_TIME = 6 / 60
Battle.FOCUS_TIME = 9 / 60
Battle.AFTER_WALK = 27 / 60

local function fast() return Options.get("enemySpeed") == "rapida" end

-- Passos pendentes (esperar, andar, chamar): o turno só segue quando acabam.
function Battle:queueStep(st) self.steps[#self.steps + 1] = st end

-- Anda pela lista de casas (sem a de partida) e chama after no fim.
function Battle:walk(u, path, after)
  if #path == 0 then
    if after then after() end
    return
  end
  self:queueStep({ walk = { u = u, path = path, i = 1, t = 0, fx = u.x, fy = u.y } })
  if after then self:queueStep({ fn = after }) end
end

-- Caminho até (x, y) com a mesma regra de bloqueio usada para decidir o destino.
function Battle:pathTo(u, x, y, blocked)
  local walker = { species = u.species, x = u.x, y = u.y, move = math.min(u.move, 16) }
  local _, prev = Path.reach(self.stage, self.data.costs, walker, blocked)
  local cols = self.stage.cols
  return Path.route(prev, cols, u.y * cols + u.x, y * cols + x)
end

-- Inimigo vai até (x, y) (câmera nele, anda, pausa) e depois faz after.
function Battle:enemyMove(e, x, y, after, blocked)
  self.cursor.x, self.cursor.y = e.x, e.y
  local f = fast() and 0.3 or 1
  self:queueStep({ wait = Battle.FOCUS_TIME * f })
  if x and (x ~= e.x or y ~= e.y) then
    self:walk(e, self:pathTo(e, x, y, blocked))
    self:queueStep({ wait = Battle.AFTER_WALK * f })
  end
  if after then self:queueStep({ fn = after }) end
end

-- Avança os passos pendentes. Devolve true enquanto houver algum.
function Battle:updateSteps(dt)
  local st = self.steps[1]
  if not st then return false end
  if st.wait then
    st.wait = st.wait - dt
    if st.wait <= 0 then table.remove(self.steps, 1) end
  elseif st.walk then
    local w = st.walk
    local tt = Battle.TILE_TIME * ((w.u.side == "enemy" and fast()) and 0.4 or 1)
    w.t = w.t + dt
    while w.t >= tt and w.path[w.i] do
      w.t = w.t - tt
      w.fx, w.fy = w.path[w.i].x, w.path[w.i].y
      w.i = w.i + 1
    end
    local nxt = w.path[w.i]
    if nxt then
      local k = w.t / tt
      w.u.px = (w.fx + (nxt.x - w.fx) * k) * 16
      w.u.py = (w.fy + (nxt.y - w.fy) * k) * 16
      self.cursor.x, self.cursor.y = nxt.x, nxt.y
    else
      w.u.x, w.u.y = w.fx, w.fy
      w.u.px, w.u.py = nil, nil
      self.cursor.x, self.cursor.y = w.u.x, w.u.y
      table.remove(self.steps, 1)
    end
  elseif st.fn then
    table.remove(self.steps, 1)
    st.fn()
  end
  return true
end

-- Termina na hora todos os passos pendentes (testes).
function Battle:flushSteps()
  local n = 0
  while self.steps[1] and n < 10000 do
    self:updateSteps(1)
    n = n + 1
  end
end

function Battle:enemyAct(e)
  if Options.get("ai") == "melhorada" then
    require("src.game.ai_plus").act(self, e)
    return
  end
  local function attack(t)
    self:attack(e, t, nil, true)
    self:checkEnd()
  end
  -- 1. cura
  local s1 = e.skills[1] and self:skill(e.skills[1])
  if s1 and s1.heal and e.hp <= math.floor(e.maxhp / 2) then
    if e.sp >= s1.cost then
      e.sp = e.sp - s1.cost
      local amount = (self.data.ai and self.data.ai.heal[s1.id]) or s1.power
      local before = e.hp
      e.hp = e.hp + amount                       -- o original não limita ao HP máx. (bug)
      if Options.get("fixHeal") then e.hp = math.min(e.maxhp, e.hp) end
      self:announce({ who = e, target = e, heal = e.hp - before, skill = s1.id })
    end
    self.cursor.x, self.cursor.y = e.x, e.y
    self:checkEnd()
    return
  end
  -- 2. aliado colado: ataca sem andar
  local t = self:aiAdjacentAlly(e.x, e.y)
  if t then
    self:enemyMove(e, nil, nil, function() attack(t) end)
  elseif e.enemySlot ~= 0 and e.move > 0 then
    -- 3/4/5. anda (atravessa aliados; só outros inimigos bloqueiam)
    local function blocked(x, y)
      local o = self:unitAt(x, y)
      return o ~= nil and o.side == "enemy" and o ~= e
    end
    local walker = { species = e.species, x = e.x, y = e.y, move = math.min(e.move, 16) }
    local reach = Path.reach(self.stage, self.data.costs, walker, blocked)
    local x, y = self:aiDestination(reach, 1)
    if x then
      self:enemyMove(e, x, y, function()
        local t2 = self:aiAdjacentAlly(e.x, e.y)
        if t2 then attack(t2) end
      end, blocked)
    else
      x, y = self:aiDestination(reach, 4)
      if x then self:enemyMove(e, x, y, nil, blocked) end
    end
  end
end

Battle.BANNER_TIME = 1.0

function Battle:update(dt)
  if self.banner then
    self.banner.t = self.banner.t - dt
    if self.banner.t <= 0 then self.banner = nil end
  end
  for i = #self.popups, 1, -1 do
    local p = self.popups[i]
    p.t = p.t + dt
    if p.t > 1.2 then table.remove(self.popups, i) end
  end
  if self.mode ~= "dialog" and self.mode ~= "bonus" and self:updateSteps(dt) then return end
  if self.phase == "enemy" and not self.result and self.mode ~= "bonus" and self.mode ~= "dialog" then
    self.timer = self.timer - dt
    if self.timer <= 0 then
      local e = table.remove(self.queue, 1)
      while e and e.hp <= 0 do e = table.remove(self.queue, 1) end
      if e then
        self:enemyAct(e)
        self.timer = Options.get("enemySpeed") == "rapida" and 0.15 or 0.5
      else
        self.phase, self.turn = "player", self.turn + 1
        self.banner = { kind = "player", t = Battle.BANNER_TIME }   -- "Player action" ($BD:$5600)
        for _, u in ipairs(self.units) do u.acted = false end
        self:say((T("Turno %d: sua vez")):format(self.turn))
        local first = self:alive("ally")[1]
        if first then self.cursor.x, self.cursor.y = first.x, first.y end
      end
    end
  end
end

Battle.TYPE_NAMES = TYPE_NAMES
return Battle
