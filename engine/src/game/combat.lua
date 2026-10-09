-- Combate, seguindo o código do jogo original (banco $01:$6526 e $09:$695F):
--
--  acerto% = clamp(100 + PRE(atacante) - ESQ(defensor) +/-20 pela vantagem de tipo, 0, 100)
--            ($01:$6542 / $65AC; o sorteio fica em $38:$73C0: com chance de erro >= 90 sempre erra,
--             < 10 sempre acerta; no meio compara com um byte aleatório)
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
  local h = 100 + att.acc - def.eva
  if h < 0 then h = 0 end
  if Combat.isStrong(att, def) then h = math.min(100, h + 20)
  elseif Combat.isWeak(att, def) then h = math.max(0, h - 20) end
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
  if miss < 10 then return true end
  return Combat.random() >= miss
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

local function strike(att, def, ev, counter)
  local hit = Combat.rollHit(att, def)
  local dmg = hit and Combat.damage(att, def) or 0
  def.hp = math.max(0, def.hp - dmg)
  local gained = hit and Combat.exp(att, def, def.hp == 0) or 0
  att.exp = (att.exp or 0) + gained
  ev[#ev + 1] = { who = att, target = def, dmg = dmg, hit = hit, mult = Combat.multiplier(att, def),
    counter = counter, exp = gained }
end

-- Resolve um ataque com contra-ataque. Retorna a lista de eventos para a UI.
function Combat.attack(att, def)
  local ev = {}
  strike(att, def, ev, false)
  if def.hp > 0 and Combat.inRange(def, att.x, att.y) then
    strike(def, att, ev, true)
  end
  return ev
end

return Combat
