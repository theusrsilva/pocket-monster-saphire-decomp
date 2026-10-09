-- Escolha do time antes da luta ("One can attack NN/MM"), como no original:
--   lista   $10:$42C8  elenco recrutado ($AA00 + vaga*64, byte +$1D) na ordem das vagas, 4 por página
--   máximo  [$C0DE] = min(recrutados, 10)   (10 = posições iniciais de cada fase, $10:$450E)
--   marcar  $01:$75C4  A liga/desliga a unidade; não liga além do máximo ([$C0DF] = marcadas)
--   lutar   START vai para o botão "attack"; A nele só começa com pelo menos uma unidade marcada
-- Na luta as marcadas ocupam as posições iniciais na ordem das vagas, não na ordem em que foram
-- marcadas (conferido no PyBoy: BoBo marcado antes do Piku, Piku fica na posição 1).
local TeamSelect = {}
TeamSelect.__index = TeamSelect
TeamSelect.MAX = 10

function TeamSelect.new(data, campaign, stage)
  local list = campaign:recruited()
  local self = setmetatable({
    data = data, campaign = campaign, stage = stage, list = list, picked = {},
    cursor = 1, onButton = false,
    max = math.min(#list, TeamSelect.MAX, #data.stages[stage].starts),
  }, TeamSelect)
  return self
end

function TeamSelect:count()
  local n = 0
  for i = 1, #self.list do if self.picked[i] then n = n + 1 end end
  return n
end

function TeamSelect:toggle(i)
  i = i or self.cursor
  if self.picked[i] then
    self.picked[i] = nil
  elseif self:count() < self.max then
    self.picked[i] = true
  else
    return false
  end
  return true
end

function TeamSelect:move(d)
  if self.onButton then
    self.onButton = false
    self.cursor = d > 0 and 1 or #self.list
    return
  end
  self.cursor = (self.cursor - 1 + d) % #self.list + 1
end

-- Time escolhido, na ordem das vagas do elenco.
function TeamSelect:team()
  local out = {}
  for i, u in ipairs(self.list) do if self.picked[i] then out[#out + 1] = u end end
  return out
end

-- A: marca/desmarca, ou começa a luta se o cursor está no botão. Devolve o time quando começa.
function TeamSelect:confirm()
  if self.onButton then
    if self:count() >= 1 then return self:team() end
    return nil
  end
  self:toggle()
end

function TeamSelect:start()
  self.onButton = true
end

return TeamSelect
