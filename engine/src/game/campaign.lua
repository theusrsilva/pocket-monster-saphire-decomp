-- Estado da campanha (equivalente à SRAM do original), salvo em <pasta do LÖVE>/save.lua.
--   elenco: 20 vagas ($AA00 + vaga*64); a vaga i começa com o registro i de $09:$4000 e
--           "recrutado" = byte +$1D (ligado pelo comando de script EE 02)
--   inventário: $C4E0 + id   itens-chave: $C4F1 + id   fases vencidas: $C4F7 + fase - 1
--   nó do mapa-múndi onde está o cursor: [$C529] (jogo novo: $20, o Instituto do Doutor)
local serialize = require("src.util.serialize")

local Campaign = {}
Campaign.__index = Campaign
Campaign.FILE = "save.lua"
Campaign.VERSION = 2
Campaign.START_NODE = 0x20

local function unitFromRecord(sp)
  local skills = {}
  for _, id in ipairs(sp.skills) do if id ~= 0 then skills[#skills + 1] = id end end
  return {
    species = sp.species, type = sp.type, level = sp.level, exp = 0,
    hp = sp.hp, maxhp = sp.hp, sp = sp.sp, maxsp = sp.sp,
    atk = sp.atk, acc = sp.acc, eva = sp.eva, move = sp.move,
    strong = sp.strong, weak = sp.weak, rmin = sp.rmin, rmax = sp.rmax, skills = skills,
  }
end

function Campaign.new(data)
  local self = setmetatable({
    version = Campaign.VERSION, roster = {}, inventory = {}, keyItems = {}, cleared = {},
    node = Campaign.START_NODE,
  }, Campaign)
  for i, sp in ipairs(data.species) do
    local u = unitFromRecord(sp)
    u.slot, u.recruited = i - 1, sp.starter
    self.roster[i - 1] = u
  end
  return self
end

function Campaign.load(data)
  if love.filesystem.getInfo(Campaign.FILE) then
    local ok, t = pcall(function() return love.filesystem.load(Campaign.FILE)() end)
    if ok and type(t) == "table" and t.version == 1 then   -- save antigo: sem posição no mapa
      t.version, t.node = Campaign.VERSION, Campaign.START_NODE
    end
    if ok and type(t) == "table" and t.version == Campaign.VERSION then
      return setmetatable(t, Campaign)
    end
  end
  return Campaign.new(data)
end

function Campaign:save()
  local t = {}
  for k, v in pairs(self) do t[k] = v end
  love.filesystem.write(Campaign.FILE, serialize(t))
end

function Campaign:recruited()
  local out = {}
  for i = 0, 19 do
    local u = self.roster[i]
    if u and u.recruited then out[#out + 1] = u end
  end
  return out
end

function Campaign:recruit(slot)
  local u = self.roster[slot]
  if u and not u.recruited then u.recruited = true return u end
end

-- Copia o estado das unidades que lutaram de volta para o elenco (nível, EXP, status, evolução).
-- HP/SP voltam ao máximo depois da luta.
function Campaign:storeUnits(units)
  for _, u in ipairs(units) do
    if u.side == "ally" and u.slot then
      local r = self.roster[u.slot]
      for _, k in ipairs({ "species", "level", "exp", "maxhp", "maxsp", "atk", "acc", "eva", "move" }) do
        r[k] = u[k]
      end
      r.hp, r.sp = r.maxhp, r.maxsp
      r.skills = {}
      for i, id in ipairs(u.skills) do r.skills[i] = id end
    end
  end
end

-- Lê um byte da WRAM equivalente (usado pelo comando E2 das falas e pelas travas do mapa).
function Campaign:peek(addr)
  if addr >= 0xC4E0 and addr <= 0xC4F0 then return self.inventory[addr - 0xC4E0] or 0 end
  if addr >= 0xC4F1 and addr <= 0xC4F6 then return (self.keyItems[addr - 0xC4F1] or 0) % 256 end
  if addr >= 0xC4F7 and addr <= 0xC516 then
    local s = addr - 0xC4F7 + 1
    return self.cleared[s] and s or 0              -- o original grava o número da fase ($00:$092F)
  end
  return 0
end

return Campaign
