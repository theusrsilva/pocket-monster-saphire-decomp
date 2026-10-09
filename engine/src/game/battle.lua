-- Estado de uma batalha: unidades, turnos, cursor, menus e IA inimiga.
local Path = require("src.game.pathfind")
local Combat = require("src.game.combat")
local nameOf = require("src.game.names")

local Battle = {}
Battle.__index = Battle

local function unitFromSpecies(sp, x, y)
  return {
    side = "ally", species = sp.species, type = sp.type, level = sp.level,
    hp = sp.hp, maxhp = sp.hp, sp = sp.sp, maxsp = sp.sp,
    atk = sp.atk, acc = sp.acc, eva = sp.eva, move = sp.move, exp = 0,
    strong = sp.strong, weak = sp.weak, rmin = sp.rmin, rmax = sp.rmax,
    x = x, y = y, acted = false, name = nameOf(sp.species),
  }
end

local function unitFromEnemy(e)
  return {
    side = "enemy", species = e.species, type = e.type, level = e.level,
    hp = e.hp, maxhp = e.hp, sp = e.sp, maxsp = e.sp,
    atk = e.atk, acc = e.acc, eva = e.eva, move = e.move, exp = 0,
    strong = e.strong, weak = e.weak, rmin = e.rmin, rmax = e.rmax,
    x = e.x, y = e.y, acted = false, name = nameOf(e.species),
  }
end

function Battle.new(data, stageIndex)
  local st = data.stages[stageIndex]
  local self = setmetatable({
    data = data, stageIndex = stageIndex, stage = st, units = {},
    phase = "player", turn = 1, mode = "cursor",
    cursor = { x = 0, y = 0 }, selected = nil, reach = nil, prev = nil,
    menu = nil, popups = {}, queue = {}, timer = 0, result = nil, log = {},
  }, Battle)
  -- Time inicial: as espécies marcadas como iniciais, nas posições da fase.
  local i = 0
  for _, sp in ipairs(data.species) do
    if sp.starter and i < #st.starts then
      i = i + 1
      local p = st.starts[i]
      self.units[#self.units + 1] = unitFromSpecies(sp, p.x, p.y)
    end
  end
  for _, e in ipairs(st.enemies) do
    self.units[#self.units + 1] = unitFromEnemy(e)
  end
  local first = self:alive("ally")[1]
  if first then self.cursor.x, self.cursor.y = first.x, first.y end
  return self
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
  if #self.log > 5 then table.remove(self.log) end
end

function Battle:computeReach(u)
  local blocked = function(x, y)
    local o = self:unitAt(x, y)
    return o ~= nil and o.side ~= u.side
  end
  return Path.reach(self.stage, self.data.costs, u, blocked)
end

-- Casas onde a unidade pode parar (alcançáveis e livres).
function Battle:stopCells(u, reach)
  local cols, out = self.stage.cols, {}
  for k in pairs(reach) do
    local x, y = k % cols, math.floor(k / cols)
    local o = self:unitAt(x, y)
    if o == nil or o == u then out[k] = true end
  end
  return out
end

function Battle:targetsFrom(u, x, y)
  local out = {}
  for _, o in ipairs(self:alive(u.side == "ally" and "enemy" or "ally")) do
    if Combat.inRange(u, o.x, o.y, x, y) then out[#out + 1] = o end
  end
  return out
end

---------------------------------------------------------------- ações do jogador

function Battle:moveCursor(dx, dy)
  if self.mode ~= "cursor" and self.mode ~= "move" and self.mode ~= "target" then return end
  if self.mode == "target" then
    -- no modo alvo, as setas alternam entre os alvos possíveis
    local t = self.targets
    self.targetIndex = (self.targetIndex + (dx + dy) - 1) % #t + 1
    self.cursor.x, self.cursor.y = t[self.targetIndex].x, t[self.targetIndex].y
    return
  end
  self.cursor.x = math.max(0, math.min(self.stage.cols - 1, self.cursor.x + dx))
  self.cursor.y = math.max(0, math.min(self.stage.rows - 1, self.cursor.y + dy))
end

function Battle:confirm()
  if self.phase ~= "player" or self.result then return end
  local c = self.cursor
  if self.mode == "cursor" then
    local u = self:unitAt(c.x, c.y)
    if u and u.side == "ally" and not u.acted then
      self.selected = u
      self.reach, self.prev = self:computeReach(u)
      self.stops = self:stopCells(u, self.reach)
      self.mode = "move"
    elseif u then
      -- mostra o alcance de qualquer outra unidade (útil para planejar)
      self.preview = u
      self.previewReach = self:computeReach(u)
    end
  elseif self.mode == "move" then
    local k = c.y * self.stage.cols + c.x
    if self.stops[k] then
      local u = self.selected
      self.origin = { x = u.x, y = u.y }
      u.x, u.y = c.x, c.y
      self.reach = nil
      self:openMenu(u)
    end
  elseif self.mode == "menu" then
    local item = self.menu.items[self.menu.index]
    item.action()
  elseif self.mode == "target" then
    local u, t = self.selected, self.targets[self.targetIndex]
    for _, ev in ipairs(Combat.attack(u, t)) do self:announce(ev) end
    self:finishUnit(u)
  end
end

function Battle:openMenu(u)
  local items = {}
  local targets = self:targetsFrom(u, u.x, u.y)
  if #targets > 0 then
    items[#items + 1] = { label = "Atacar", action = function()
      self.targets, self.targetIndex = targets, 1
      self.cursor.x, self.cursor.y = targets[1].x, targets[1].y
      self.mode = "target"
    end }
  end
  items[#items + 1] = { label = "Esperar", action = function() self:finishUnit(u) end }
  self.menu = { items = items, index = 1 }
  self.mode = "menu"
end

function Battle:cancel()
  if self.mode == "move" then
    self.mode, self.selected, self.reach = "cursor", nil, nil
  elseif self.mode == "menu" then
    -- desfazer movimento (melhoria em relação ao original)
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
  if self.mode == "menu" then
    local m = self.menu
    m.index = (m.index - 1 + d) % #m.items + 1
  end
end

function Battle:finishUnit(u)
  u.acted = true
  self.selected, self.menu, self.reach, self.mode = nil, nil, nil, "cursor"
  self.cursor.x, self.cursor.y = u.x, u.y
  self:checkEnd()
  if not self.result then
    local pending = false
    for _, a in ipairs(self:alive("ally")) do if not a.acted then pending = true end end
    if not pending then self:endPlayerTurn() end
  end
end

function Battle:endPlayerTurn()
  if self.phase ~= "player" or self.result then return end
  self.mode, self.selected, self.reach, self.menu = "cursor", nil, nil, nil
  self.phase = "enemy"
  self:say(("Turno %d: inimigos"):format(self.turn))
  self.queue = self:alive("enemy")
  self.timer = 0.4
end

function Battle:announce(ev)
  local who = (ev.counter and "Contra: " or "") .. ev.who.name
  if not ev.hit then
    self:say(("%s errou %s"):format(who, ev.target.name))
    self.popups[#self.popups + 1] = { x = ev.target.x, y = ev.target.y, text = "errou", t = 0 }
    return
  end
  local tag = ev.mult > 1 and " (forte!)" or (ev.mult < 1 and " (fraco)" or "")
  self:say(("%s causa %d em %s%s"):format(who, ev.dmg, ev.target.name, tag))
  self.popups[#self.popups + 1] = { x = ev.target.x, y = ev.target.y, text = tostring(ev.dmg), t = 0 }
  if ev.target.hp == 0 then self:say(ev.target.name .. " caiu!") end
  if ev.who.side == "ally" and ev.exp > 0 then self:say(("%s ganhou %d EXP"):format(ev.who.name, ev.exp)) end
end

function Battle:checkEnd()
  if #self:alive("enemy") == 0 then self.result = "vitória"
  elseif #self:alive("ally") == 0 then self.result = "derrota" end
end

---------------------------------------------------------------- IA inimiga

-- IA simples: se dá para atacar alguém neste turno, ataca o alvo com menos HP;
-- senão anda na direção do aliado mais próximo.
function Battle:enemyAct(e)
  local reach = self:computeReach(e)
  local stops = self:stopCells(e, reach)
  local cols = self.stage.cols
  local bestK, bestT, bestScore
  for k in pairs(stops) do
    local x, y = k % cols, math.floor(k / cols)
    for _, t in ipairs(self:targetsFrom(e, x, y)) do
      local exp = Combat.damage(e, t) * Combat.hitChance(e, t) / 100
      local score = t.hp - exp * 2 + (reach[k] or 0) * 0.01
      if bestScore == nil or score < bestScore then bestK, bestT, bestScore = k, t, score end
    end
  end
  if bestK then
    e.x, e.y = bestK % cols, math.floor(bestK / cols)
    for _, ev in ipairs(Combat.attack(e, bestT)) do self:announce(ev) end
  else
    local allies = self:alive("ally")
    local bk, bd
    for k in pairs(stops) do
      local x, y = k % cols, math.floor(k / cols)
      for _, a in ipairs(allies) do
        local d = Path.dist(x, y, a.x, a.y)
        if bd == nil or d < bd then bk, bd = k, d end
      end
    end
    if bk then e.x, e.y = bk % cols, math.floor(bk / cols) end
  end
  self.cursor.x, self.cursor.y = e.x, e.y
  self:checkEnd()
end

function Battle:update(dt)
  for i = #self.popups, 1, -1 do
    local p = self.popups[i]
    p.t = p.t + dt
    if p.t > 1 then table.remove(self.popups, i) end
  end
  if self.phase == "enemy" and not self.result then
    self.timer = self.timer - dt
    if self.timer <= 0 then
      local e = table.remove(self.queue, 1)
      while e and e.hp <= 0 do e = table.remove(self.queue, 1) end
      if e then
        self:enemyAct(e)
        self.timer = 0.5
      else
        self.phase, self.turn = "player", self.turn + 1
        for _, u in ipairs(self.units) do u.acted = false end
        self:say(("Turno %d: sua vez"):format(self.turn))
        local first = self:alive("ally")[1]
        if first then self.cursor.x, self.cursor.y = first.x, first.y end
      end
    end
  end
end

return Battle
