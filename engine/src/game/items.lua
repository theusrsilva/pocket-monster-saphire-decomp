-- Itens: inventário em $C4E0 + id (1 byte por item). Efeitos de $01:$4ECB em diante.
-- Os nomes vêm do script do jogo ("Acquire the bread!! {GIVE $C4E2}").
local Progress = require("src.game.progress")

local Items = {}

local function heal(stat, amount)
  return function(u)
    if stat == "hp" then u.hp = math.min(u.maxhp, u.hp + amount)
    else u.sp = math.min(u.maxsp, u.sp + amount) end
  end
end

local function boost(stat, amount, cap)
  return function(u)
    if stat == "maxhp" then u.maxhp = u.maxhp + amount; u.hp = u.hp + amount
    elseif stat == "maxsp" then u.maxsp = u.maxsp + amount; u.sp = u.sp + amount
    else u[stat] = cap and math.min(cap, u[stat] + amount) or (u[stat] + amount) end
  end
end

-- id = deslocamento em $C4E0
Items.list = {
  [0x00] = { en = "Candy", pt = "Doce", desc = "+200 HP", use = heal("hp", 200) },
  [0x01] = { en = "Juice", pt = "Suco", desc = "+200 SP", use = heal("sp", 200) },
  [0x02] = { en = "Bread", pt = "Pão", desc = "+500 HP", use = heal("hp", 500) },
  [0x03] = { en = "Milk", pt = "Leite", desc = "+400 SP", use = heal("sp", 400) },
  [0x04] = { en = "Cake", pt = "Bolo", desc = "HP cheio", use = function(u) u.hp = u.maxhp end },
  [0x05] = { en = "Honey", pt = "Mel", desc = "+600 SP", use = heal("sp", 600) },
  [0x06] = { en = "Life stone", pt = "Pedra da Vida", desc = "HP máx +10", use = boost("maxhp", 10) },
  [0x07] = { en = "Spirit stone", pt = "Pedra do Espírito", desc = "SP máx +5", use = boost("maxsp", 5) },
  [0x08] = { en = "Flames stone", pt = "Pedra das Chamas", desc = "ATK +2", use = boost("atk", 2) },
  [0x09] = { en = "Eye stone", pt = "Pedra do Olho", desc = "PRE +2", use = boost("acc", 2) },
  [0x0A] = { en = "Phoenix stone", pt = "Pedra da Fênix", desc = "ESQ +2", use = boost("eva", 2) },
  [0x0B] = { en = "Flight stone", pt = "Pedra do Voo", desc = "MOV +2 (máx. 15)", use = boost("move", 2, 15) },
  -- Badges ($C4EC-$C4F0): pedras de evolução, uma por tipo.
  [0x0C] = { en = "Celerity badge", pt = "Insígnia Celerity", badge = 1 },
  [0x0D] = { en = "Equilibrium badge", pt = "Insígnia Equilibrium", badge = 2 },
  [0x0E] = { en = "Strength badge", pt = "Insígnia Strength", badge = 3 },
  [0x0F] = { en = "Exceed badge", pt = "Insígnia SuperPower", badge = 4 },
  [0x10] = { en = "Defense badge", pt = "Insígnia Defense", badge = 5 },
}

function Items.name(id, mode)
  local it = Items.list[id]
  return mode == "original" and it.en or it.pt
end

-- O item pode ser usado nesta unidade agora?
function Items.usable(id, u, prog)
  local it = Items.list[id]
  if it.badge then
    -- SUPOSIÇÃO: a insígnia precisa ser do tipo da unidade (o código consome a insígnia escolhida;
    -- o filtro do menu original ainda não foi confirmado).
    return it.badge == u.type and Progress.canEvolve(u, prog)
  end
  if id == 0x00 or id == 0x02 or id == 0x04 then return u.hp < u.maxhp end
  if id == 0x01 or id == 0x03 or id == 0x05 then return u.sp < u.maxsp end
  if id == 0x0B then return u.move < 15 end
  return true
end

return Items
