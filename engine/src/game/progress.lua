-- Nível, ganho de status e evolução, seguindo o jogo original:
--   subida de nível  $1D:$5620   ganho de status $01:$6856   bônus escolhido $01:$5370
--   evolução         $01:$5630 -> $19:$5B52 / $19:$5F82
local Progress = {}

-- Sorteio 0..99, como o RNG do jogo ($C035 = ($C035 + 1 + ($C037 & $3F)) mod 100).
Progress.random = function() return love.math.random(0, 99) end

Progress.STATS = { "hp", "sp", "atk", "acc", "eva" }
Progress.LABELS = { hp = "HP", sp = "SP", atk = "ATK", acc = "PRE", eva = "ESQ" }

-- Opções do bônus que o jogador escolhe depois de subir de nível.
function Progress.bonusOptions(prog, unit)
  local b = prog.bonusChoice[prog.growth[unit.species] or 1] or prog.bonusChoice[1]
  return { { stat = "hp", amount = b[1] }, { stat = "sp", amount = b[2] }, { stat = "atk", amount = b[3] },
    { stat = "acc", amount = b[4] }, { stat = "eva", amount = b[5] } }
end

function Progress.applyBonus(unit, opt)
  if opt.stat == "hp" then unit.maxhp = unit.maxhp + opt.amount; unit.hp = unit.maxhp
  elseif opt.stat == "sp" then unit.maxsp = unit.maxsp + opt.amount; unit.sp = unit.maxsp
  else unit[opt.stat] = unit[opt.stat] + opt.amount end
end

-- Um nível: HP/SP sobem valores fixos; ATK/PRE/ESQ sobem só se o sorteio passar no limiar,
-- e o valor vem de gainValues[estágio][sorteio & 3]. Depois HP e SP voltam ao máximo.
local function levelUp(unit, prog)
  local s = unit.species
  local g = prog.gains[s]
  local class = prog.growth[s] or 1
  local delta = { hp = g[1], sp = g[2], atk = 0, acc = 0, eva = 0 }
  for i, stat in ipairs({ "atk", "acc", "eva" }) do
    local r = Progress.random()
    if r < g[2 + i] then delta[stat] = prog.gainValues[class][(r % 4) + 1] end
  end
  unit.level = unit.level + 1
  unit.maxhp, unit.maxsp = unit.maxhp + delta.hp, unit.maxsp + delta.sp
  unit.atk, unit.acc, unit.eva = unit.atk + delta.atk, unit.acc + delta.acc, unit.eva + delta.eva
  unit.hp, unit.sp = unit.maxhp, unit.maxsp
  return delta
end

-- Soma EXP. No nível máximo da forma a EXP zera (precisa evoluir). Retorna a lista de níveis ganhos.
function Progress.gainExp(unit, amount, prog)
  local ups = {}
  if amount <= 0 or unit.side ~= "ally" then return ups end
  local maxLv = prog.maxLevel[unit.species] or 99
  if unit.level >= maxLv then unit.exp = 0 return ups end
  unit.exp = unit.exp + amount
  while unit.exp >= 100 and unit.level < 99 and unit.level < maxLv do
    unit.exp = unit.exp - 100
    ups[#ups + 1] = levelUp(unit, prog)
  end
  if unit.level >= maxLv then unit.exp = 0 end
  return ups
end

function Progress.canEvolve(unit, prog)
  return unit.side ~= "enemy" and not prog.final[unit.species] and prog.evoBonus[unit.species + 1] ~= nil
end

-- Evolução: espécie+1, soma o bônus da nova forma, recupera HP/SP e aprende o golpe da forma.
function Progress.evolve(unit, prog)
  local ns = unit.species + 1
  local b = prog.evoBonus[ns]
  unit.species = ns
  unit.maxsp, unit.maxhp = unit.maxsp + b.sp, unit.maxhp + b.hp
  unit.atk, unit.acc, unit.eva = unit.atk + b.atk, unit.acc + b.acc, unit.eva + b.eva
  unit.move = unit.move + b.move
  unit.hp, unit.sp = unit.maxhp, unit.maxsp
  local learn = prog.learn[ns]
  if learn and learn ~= 0 and #unit.skills < 4 then
    unit.skills[#unit.skills + 1] = learn
    return learn
  end
end

return Progress
