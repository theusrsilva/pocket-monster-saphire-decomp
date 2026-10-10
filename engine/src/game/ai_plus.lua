-- IA melhorada (opcional, não é do jogo original). Para cada casa alcançável e cada ação possível
-- (ataque normal no alcance real da unidade, golpes de ataque com SP, golpe de cura em aliado),
-- calcula o valor esperado e escolhe o melhor:
--   ataque: dano x chance de acerto, bônus grande se pode derrubar, menos o contra-ataque esperado
--   cura:   HP recuperado de um aliado ferido (inclusive ela mesma)
-- Sem ação útil, anda para a casa mais perto do aliado inimigo mais próximo. O chefe (vaga 0)
-- e quem tem MOV 0 não andam. Usa as mesmas regras de combate e movimento do original.
local Combat = require("src.game.combat")
local Path = require("src.game.pathfind")

local AIPlus = {}

local function expectedCounter(b, e, t, x, y, skill)
  local ox, oy = e.x, e.y
  e.x, e.y = x, y
  local c = Combat.counterFor(e, t, skill)
  local v = 0
  if c then
    v = Combat.damage(t, e, c ~= "normal" and c.power or nil) * Combat.hitChance(t, e) / 100
  end
  e.x, e.y = ox, oy
  return v
end

function AIPlus.act(b, e)
  local cols = b.stage.cols
  local stops
  if e.move > 0 and e.enemySlot ~= 0 then
    stops = b:stopCells(e, b:computeReach(e))
  else
    stops = { [e.y * cols + e.x] = true }
  end
  local actions = { false }
  for _, id in ipairs(e.skills) do
    local s = b:skill(id)
    if s and e.sp >= s.cost then actions[#actions + 1] = s end
  end
  local best
  for k in pairs(stops) do
    local x, y = k % cols, math.floor(k / cols)
    for _, s in ipairs(actions) do
      local skill = s or nil
      for _, t in ipairs(b:targetsFrom(e, x, y, skill)) do
        local score
        if skill and skill.heal then
          local gain = math.min(skill.power, t.maxhp - t.hp)
          if gain >= skill.power / 3 then score = gain * 1.2 end
        else
          local dmg = Combat.damage(e, t, skill and skill.power)
          local hit = Combat.hitChance(e, t) / 100
          score = math.min(dmg, t.hp) * hit
          if dmg >= t.hp then score = score + 200 * hit
          else score = score - expectedCounter(b, e, t, x, y, skill) * 0.6 end
          score = score - (skill and skill.cost * 0.2 or 0)
        end
        if score and (not best or score > best.score) then
          best = { score = score, x = x, y = y, t = t, skill = skill }
        end
      end
    end
  end
  local function blocked(x, y)
    local o = b:unitAt(x, y)
    return o ~= nil and o.side ~= e.side
  end
  if best and best.score > 0 then
    b:enemyMove(e, best.x, best.y, function()
      if best.skill and best.skill.heal then
        for _, ev in ipairs(Combat.heal(e, best.t, best.skill)) do b:announce(ev) end
      else
        b:attack(e, best.t, best.skill)
      end
      b:checkEnd()
    end, blocked)
    return
  end
  -- sem ação: aproxima-se do aliado mais próximo
  local bk, bd
  for k in pairs(stops) do
    local x, y = k % cols, math.floor(k / cols)
    for _, a in ipairs(b:alive("ally")) do
      local d = Path.dist(x, y, a.x, a.y)
      if not bd or d < bd then bk, bd = k, d end
    end
  end
  if bk then b:enemyMove(e, bk % cols, math.floor(bk / cols), nil, blocked) end
end

return AIPlus
