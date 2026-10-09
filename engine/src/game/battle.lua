-- Estado de uma batalha: unidades, turnos, cursor, menus, progressão e IA inimiga.
local Path = require("src.game.pathfind")
local Combat = require("src.game.combat")
local Progress = require("src.game.progress")
local nameOf = require("src.game.names")

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

function Battle.new(data, stageIndex)
  local st = data.stages[stageIndex]
  local self = setmetatable({
    data = data, prog = data.prog, stageIndex = stageIndex, stage = st, units = {},
    phase = "player", turn = 1, mode = "cursor",
    cursor = { x = 0, y = 0 }, selected = nil, reach = nil, prev = nil,
    menu = nil, popups = {}, queue = {}, timer = 0, result = nil, log = {}, pending = {},
    -- PROVISÓRIO: enquanto itens/eventos não existem, cada batalha começa com 1 pedra de evolução
    -- de cada tipo (no original elas vêm de casas, baús e lojas).
    stones = { 1, 1, 1, 1, 1 },
  }, Battle)
  local i = 0
  for _, sp in ipairs(data.species) do
    if sp.starter and i < #st.starts then
      i = i + 1
      local u = newUnit("ally", setmetatable({ x = st.starts[i].x, y = st.starts[i].y }, { __index = sp }))
      for _, id in ipairs(sp.skills) do if id ~= 0 then u.skills[#u.skills + 1] = id end end
      self.units[#self.units + 1] = u
    end
  end
  for _, e in ipairs(st.enemies) do
    local u = newUnit("enemy", e)
    if e.skill then u.skills[1] = e.skill end
    self.units[#self.units + 1] = u
  end
  for _, u in ipairs(self.units) do u.name = nameOf(u.species) end
  local first = self:alive("ally")[1]
  if first then self.cursor.x, self.cursor.y = first.x, first.y end
  return self
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
    self.targetIndex = (self.targetIndex + (dx + dy) - 1) % #t + 1
    self.cursor.x, self.cursor.y = t[self.targetIndex].x, t[self.targetIndex].y
    return
  end
  if self.mode ~= "cursor" and self.mode ~= "move" then return end
  self.cursor.x = math.max(0, math.min(self.stage.cols - 1, self.cursor.x + dx))
  self.cursor.y = math.max(0, math.min(self.stage.rows - 1, self.cursor.y + dy))
end

function Battle:confirm()
  if self.result then return end
  if self.mode == "bonus" or self.mode == "menu" then
    self.menu.items[self.menu.index].action()
    return
  end
  if self.phase ~= "player" then return end
  local c = self.cursor
  if self.mode == "cursor" then
    local u = self:unitAt(c.x, c.y)
    if u and u.side == "ally" and not u.acted then
      self.selected = u
      self.preview, self.previewReach = nil, nil
      self.reach, self.prev = self:computeReach(u)
      self.stops = self:stopCells(u, self.reach)
      self.mode = "move"
    elseif u then
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
  elseif self.mode == "target" then
    local u, t, s = self.selected, self.targets[self.targetIndex], self.action
    if s and s.heal then
      for _, ev in ipairs(Combat.heal(u, t, s)) do self:announce(ev) end
    else
      for _, ev in ipairs(Combat.attack(u, t, s)) do self:announce(ev) end
    end
    self:finishUnit(u)
  end
end

function Battle:chooseTarget(u, skill)
  local targets = self:targetsFrom(u, u.x, u.y, skill)
  self.action, self.targets, self.targetIndex = skill, targets, 1
  self.cursor.x, self.cursor.y = targets[1].x, targets[1].y
  self.mode = "target"
end

function Battle:openMenu(u)
  local items = {}
  if #self:targetsFrom(u, u.x, u.y) > 0 then
    items[#items + 1] = { label = "Atacar", action = function() self:chooseTarget(u, nil) end }
  end
  local skills = self:usableSkills(u)
  if #skills > 0 then
    items[#items + 1] = { label = "Golpe", action = function() self:openSkillMenu(u, skills) end }
  end
  if Progress.canEvolve(u, self.prog) and (self.stones[u.type] or 0) > 0 then
    items[#items + 1] = { label = "Evoluir", action = function() self:evolve(u) end }
  end
  items[#items + 1] = { label = "Esperar", action = function() self:finishUnit(u) end }
  self.menu = { items = items, index = 1, title = u.name }
  self.mode = "menu"
end

function Battle:openSkillMenu(u, skills)
  local items = {}
  for _, s in ipairs(skills) do
    local label = s.heal and ("Cura #%02X  +%d HP  %d SP"):format(s.id, s.power, s.cost)
      or ("Golpe #%02X  +%d  %d SP  %d-%d"):format(s.id, s.power, s.cost, s.rmin, s.rmax)
    items[#items + 1] = { label = label, action = function() self:chooseTarget(u, s) end }
  end
  self.menu = { items = items, index = 1, title = "Golpes", parent = u, wide = true }
end

function Battle:evolve(u)
  self.stones[u.type] = self.stones[u.type] - 1
  local old = u.name
  local learned = Progress.evolve(u, self.prog)
  u.name = nameOf(u.species)
  self:say(("%s evoluiu para %s!"):format(old, u.name))
  if learned then self:say(("%s aprendeu o golpe #%02X"):format(u.name, learned)) end
  self.popups[#self.popups + 1] = { x = u.x, y = u.y, text = "EVOLUIU!", t = 0 }
  -- evoluir não gasta a ação (melhoria/simplificação até existir o menu de itens)
  self:openMenu(u)
end

function Battle:cancel()
  if self.mode == "bonus" then return end
  if self.mode == "move" then
    self.mode, self.selected, self.reach = "cursor", nil, nil
  elseif self.mode == "menu" then
    if self.menu.parent then self:openMenu(self.menu.parent) return end
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
  if self.result or #self.pending > 0 or self.phase ~= "player" then return end
  for _, a in ipairs(self:alive("ally")) do if not a.acted then return end end
  self:endPlayerTurn()
end

function Battle:endPlayerTurn()
  if self.phase ~= "player" or self.result then return end
  self.mode, self.selected, self.reach, self.menu = "cursor", nil, nil, nil
  self.phase = "enemy"
  self:say(("Turno %d: inimigos"):format(self.turn))
  self.queue = self:alive("enemy")
  self.timer = 0.4
end

---------------------------------------------------------------- eventos, EXP e nível

function Battle:announce(ev)
  local who = (ev.counter and "Contra: " or "") .. ev.who.name
  local tag = ev.skill and (" [golpe #%02X]"):format(ev.skill) or ""
  if ev.heal then
    self:say(("%s cura %d de %s%s"):format(ev.who.name, ev.heal, ev.target.name, tag))
    self.popups[#self.popups + 1] = { x = ev.target.x, y = ev.target.y, text = "+" .. ev.heal, t = 0, heal = true }
    return
  end
  if not ev.hit then
    self:say(("%s errou %s%s"):format(who, ev.target.name, tag))
    self.popups[#self.popups + 1] = { x = ev.target.x, y = ev.target.y, text = "errou", t = 0 }
    return
  end
  local adv = ev.mult > 1 and " (forte!)" or (ev.mult < 1 and " (fraco)" or "")
  self:say(("%s causa %d em %s%s%s"):format(who, ev.dmg, ev.target.name, adv, tag))
  self.popups[#self.popups + 1] = { x = ev.target.x, y = ev.target.y, text = tostring(ev.dmg), t = 0 }
  if ev.target.hp == 0 then self:say(ev.target.name .. " caiu!") end
  if ev.who.side == "ally" and ev.exp > 0 then self:grantExp(ev.who, ev.exp) end
end

function Battle:grantExp(u, amount)
  -- Combat.strike já somou em u.exp; desfaz e passa pela regra de progressão.
  u.exp = u.exp - amount
  local ups = Progress.gainExp(u, amount, self.prog)
  self:say(("%s ganhou %d EXP"):format(u.name, amount))
  for _, d in ipairs(ups) do
    self:say(("%s subiu para o nível %d! HP+%d SP+%d ATK+%d PRE+%d ESQ+%d"):format(
      u.name, u.level, d.hp, d.sp, d.atk, d.acc, d.eva))
    self.popups[#self.popups + 1] = { x = u.x, y = u.y, text = "NÍVEL " .. u.level, t = 0, heal = true }
    self.pending[#self.pending + 1] = u
  end
  if #ups == 0 and u.level >= (self.prog.maxLevel[u.species] or 99) and not self.prog.final[u.species] then
    self:say(u.name .. " está no nível máximo da forma: precisa evoluir")
  end
  self:openBonusIfPending()
end

-- Depois de subir de nível, o jogador escolhe um bônus extra (como no original).
function Battle:openBonusIfPending()
  if self.mode == "bonus" or #self.pending == 0 then return end
  local u = self.pending[1]
  local items = {}
  for _, opt in ipairs(Progress.bonusOptions(self.prog, u)) do
    items[#items + 1] = { label = ("%s +%d"):format(Progress.LABELS[opt.stat], opt.amount), action = function()
      Progress.applyBonus(u, opt)
      self:say(("%s: %s +%d"):format(u.name, Progress.LABELS[opt.stat], opt.amount))
      table.remove(self.pending, 1)
      self.menu, self.mode = nil, "cursor"
      if #self.pending > 0 then self:openBonusIfPending() else self:afterAction() end
    end }
  end
  self.bonusUnit = u
  self.menu = { items = items, index = 1, title = ("%s - nível %d: escolha um bônus"):format(u.name, u.level),
    center = true, wide = true }
  self.mode = "bonus"
end

function Battle:checkEnd()
  if #self:alive("enemy") == 0 then self.result = "vitória"
  elseif #self:alive("ally") == 0 then self.result = "derrota" end
end

---------------------------------------------------------------- IA inimiga

-- IA (provisória, a original ainda não foi extraída): considera ataque normal e golpes de cada
-- casa alcançável e escolhe o que mais tira HP do alvo mais fraco; cura aliados feridos; se não
-- dá para agir, anda na direção do aliado mais próximo. MOV 0 (chefes) nunca anda.
function Battle:enemyAct(e)
  local cols = self.stage.cols
  local stops
  if e.move > 0 then stops = self:stopCells(e, self:computeReach(e))
  else stops = { [e.y * cols + e.x] = true } end
  local best
  local options = { false }
  for _, id in ipairs(e.skills) do
    local s = self:skill(id)
    if s and e.sp >= s.cost then options[#options + 1] = s end
  end
  for k in pairs(stops) do
    local x, y = k % cols, math.floor(k / cols)
    for _, s in ipairs(options) do
      local skill = s or nil
      for _, t in ipairs(self:targetsFrom(e, x, y, skill)) do
        local score
        if skill and skill.heal then
          score = (t.maxhp - t.hp < skill.power / 2) and nil or -(t.maxhp - t.hp) * 0.5
        else
          local dmg = Combat.damage(e, t, skill and skill.power) * Combat.hitChance(e, t) / 100
          score = t.hp - dmg * 2 - (dmg >= t.hp and 1000 or 0)
        end
        if score and (best == nil or score < best.score) then
          best = { score = score, k = k, t = t, skill = skill }
        end
      end
    end
  end
  if best then
    e.x, e.y = best.k % cols, math.floor(best.k / cols)
    local evs = (best.skill and best.skill.heal) and Combat.heal(e, best.t, best.skill)
      or Combat.attack(e, best.t, best.skill)
    for _, ev in ipairs(evs) do self:announce(ev) end
  elseif e.move > 0 then
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
    if p.t > 1.2 then table.remove(self.popups, i) end
  end
  if self.phase == "enemy" and not self.result and self.mode ~= "bonus" then
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

Battle.TYPE_NAMES = TYPE_NAMES
return Battle
