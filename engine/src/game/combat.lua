-- Combate, seguindo o código do jogo original (banco $01:$6526 e $09:$695F):
--
--  acerto% ($01:$6542 / $65AC / $6616): a = max(0, 100 + PRE - ESQ); o ajuste de tipo olha só o
--            byte baixo: forte -> 100 se a >= 80, senão a + 20; fraco -> 0 se a < 32, senão a - 20;
--            no fim limita a 100. erro% = 100 - acerto%.
--  sorteio  ($38:$73C4 / $741B): erro >= 90 sempre erra; erro < 20 sempre acerta; no meio acerta
--            se o byte aleatório (0..99) for MAIOR que o erro
--  contra   ($09:$6842): o defensor usa o 1º golpe de ataque, do 4º espaço para o 1º, cujo alcance
--            máximo cubra o alcance máximo da ação do atacante (soma o poder e gasta SP sem
--            conferir); sem golpe assim, contra-ataca normal só a distância 1. Quando o inimigo
--            ataca ($01:$6AA9) o contra é sempre normal. Quem caiu não contra-ataca.
--  dano    = ATK (+ poder do golpe especial) x1.5 se forte / x0.5 se fraco  ($01:$664E)
--            -- não existe redução por defesa: o HP perde o ataque efetivo inteiro ($09:$695F)
--  EXP     = derrubou: 16 x 2^dif, só acertou: 8 x 2^dif (dif = nível do alvo - nível próprio,
--            1..9), máximo 100; alvo de nível menor dá 1; errar dá 0  ($01:$677A, $1D:$5860)
--
-- Ciclo de tipos: Celerity > Equilibrium > Strength > SuperPower > Defense > Celerity.
local Path = require("src.game.pathfind")
local Combat = {}

-- Gerador de números aleatórios trocável (os testes usam um fixo).
Combat.random = function() return love.math.random(0, 99) end

function Combat.isStrong(att, def) return att.strong == def.type end
function Combat.isWeak(att, def) return att.weak == def.type end

function Combat.multiplier(att, def)
  if Combat.isStrong(att, def) then return 1.5 end
  if Combat.isWeak(att, def) then return 0.5 end
  return 1
end

function Combat.hitChance(att, def)
  local h = math.max(0, 100 + att.acc - def.eva) % 256     -- o ajuste olha só o byte baixo
  if Combat.isStrong(att, def) then
    if h ~= 100 then h = (h < 80) and h + 20 or 100 end
  elseif Combat.isWeak(att, def) then
    if h ~= 0 then h = (h < 32) and 0 or h - 20 end
  end
  return math.min(100, h)
end

function Combat.damage(att, def, skillPower)
  local a = att.atk + (skillPower or 0)
  if Combat.isStrong(att, def) then a = a + math.floor(a / 2)
  elseif Combat.isWeak(att, def) then a = math.floor(a / 2) end
  return a
end

function Combat.rollHit(att, def)
  local miss = 100 - Combat.hitChance(att, def)
  if miss >= 90 then return false end
  if miss < 20 then return true end
  return Combat.random() > miss
end

function Combat.exp(att, def, killed)
  local diff = def.level - att.level
  if diff < 0 then return 1 end
  local mult = (diff >= 1 and diff < 10) and 2 ^ diff or 1
  if diff == 0 then mult = 2 end
  return math.min(100, (killed and 16 or 8) * mult)
end

function Combat.inRange(att, tx, ty, fromX, fromY)
  local d = Path.dist(fromX or att.x, fromY or att.y, tx, ty)
  return d >= att.rmin and d <= att.rmax
end

local function strike(att, def, ev, counter, skill)
  local hit = Combat.rollHit(att, def)
  local dmg = hit and Combat.damage(att, def, skill and skill.power) or 0
  def.hp = math.max(0, def.hp - dmg)
  local gained = hit and Combat.exp(att, def, def.hp == 0) or 0
  att.exp = (att.exp or 0) + gained
  ev[#ev + 1] = { who = att, target = def, dmg = dmg, hit = hit, mult = Combat.multiplier(att, def),
    counter = counter, exp = gained, skill = skill and skill.id }
end

-- Alcance de uma ação (ataque normal ou golpe).
function Combat.actionRange(unit, skill)
  if skill then return skill.rmin, skill.rmax end
  return unit.rmin, unit.rmax
end

-- Tabela de golpes ($09:$4D5B), preenchida pela batalha (Combat.skills = data.prog.skills).
Combat.skills = {}

-- Como o defensor responde: devolve "normal", o golpe usado no contra, ou nil (sem contra).
-- enemyTurn = ataque iniciado pela IA ($01:$6AA9): contra sempre normal.
function Combat.counterFor(att, def, skill, enemyTurn)
  if def.hp <= 0 then return nil end
  if enemyTurn then return "normal" end
  local _, attMax = Combat.actionRange(att, skill)
  local list = def.skills or {}
  for i = math.min(#list, 4), 1, -1 do
    local s = Combat.skills[list[i]]
    if s and list[i] >= 0x0C and not s.heal and s.rmax >= attMax then
      s.id = list[i]
      return s
    end
  end
  if Path.dist(att.x, att.y, def.x, def.y) == 1 then return "normal" end
  return nil
end

-- Resolve um ataque (normal ou golpe especial, que gasta SP e soma o poder ao ATK) e o
-- contra-ataque do defensor. Retorna a lista de eventos para a UI.
function Combat.attack(att, def, skill, enemyTurn)
  local ev = {}
  if skill then att.sp = att.sp - skill.cost end
  strike(att, def, ev, false, skill)
  local c = Combat.counterFor(att, def, skill, enemyTurn)
  if c == "normal" then
    strike(def, att, ev, true)
  elseif c then
    def.sp = math.max(0, def.sp - c.cost)    -- o original desconta sem conferir o SP
    strike(def, att, ev, true, c)
  end
  return ev
end

-- Golpe de cura (ids $01-$0B): recupera "poder" de HP do alvo aliado.
function Combat.heal(user, target, skill)
  user.sp = user.sp - skill.cost
  local before = target.hp
  target.hp = math.min(target.maxhp, target.hp + skill.power)
  return { { who = user, target = target, heal = target.hp - before, skill = skill.id } }
end

return Combat
