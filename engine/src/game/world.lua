-- Mapa-múndi (fase 0): cursor que anda de nó em nó pelo grafo do original e libera as fases.
--   movimento   $09:$69D8  grafo $09:$6B7D (vizinho e flag exigida por direção)
--   entrar      $01:$547D  fase vencida não reabre; fases 9/11/16/19/24/25 pedem item-chave
--   cidades     $01:$55A8  menu Palaestra / Prefeito / Morador (falas 0 e 1 do script da cidade)
--   Instituto e BabyAlliance: menus próprios (estados de janela $18 e $19)
local I18n = require("src.game.i18n")
local T = I18n.T
local Names = require("src.game.names")
local Messages = require("src.game.messages")
local Progress = require("src.game.progress")
local Items = require("src.game.items")
local Sound = require("src.audio.sound")

local World = {}
World.__index = World

World.UP, World.DOWN, World.LEFT, World.RIGHT = 1, 2, 3, 4
World.INSTITUTE, World.ALLIANCE = 32, 33
World.FIRST_TOWN, World.LAST_TOWN = 26, 31
-- Item-chave exigido para entrar ($01:$5497-$54ED): fase -> id em $C4F1 + id.
World.KEY_FOR_STAGE = { [9] = 0, [11] = 1, [16] = 2, [19] = 3, [24] = 4, [25] = 5 }
World.MSG_GATE = 0x22          -- fala da porta (E2 testa o item-chave)
World.FINAL_STAGE = 25         -- antes dela o jogo mostra também a mensagem 0
World.TOWN_PALAESTRA = 26      -- Palaestra da cidade n (26..31) = fase n
World.INSTITUTE_SPEAKER, World.ALLIANCE_SPEAKER = 3, 4   -- [$C270] em $01:$55DC / $55ED

function World.kind(node)
  if node >= 1 and node <= 25 then return "stage" end
  if node >= World.FIRST_TOWN and node <= World.LAST_TOWN then return "town" end
  if node == World.INSTITUTE then return "institute" end
  if node == World.ALLIANCE then return "alliance" end
end

function World.new(data, campaign)
  local self = setmetatable({
    data = data, campaign = campaign, world = data.world, mode = "map", menu = nil, dialog = nil,
    log = {}, anim = nil,
  }, World)
  if not self.world.nodes[campaign.node or 0] then campaign.node = 0x20 end
  if campaign.introSeen == false then             -- jogo novo: a introdução da história (script $20)
    campaign.introSeen = true
    self.intro = true
    Sound.music(Sound.INTRO)
    self:showMessages(0, { 1, 2, 3, 4, 5 }, nil, function()
      self.intro = false
      campaign:save()
      Sound.stageMusic_(0)
    end)
  end
  return self
end

function World:node() return self.world.nodes[self.campaign.node] end

function World:say(msg)
  table.insert(self.log, 1, msg)
  self.logAt = love.timer and love.timer.getTime() or 0
  if #self.log > 3 then table.remove(self.log) end
end

-- Pode andar na direção d? O vizinho precisa existir e a flag da direção (fase vencida) estar ligada.
function World:canMove(d)
  local n = self:node()
  local to = n.nb[d]
  if not to or to == 0 or not self.world.nodes[to] then return false end
  local g = n.gate[d]
  return g == 0 or self.campaign.cleared[g] == true, to
end

function World:move(d)
  if self.mode ~= "map" then return false end
  local ok, to = self:canMove(d)
  if ok then
    local from = self:node()
    self.campaign.node = to
    self.anim = { fx = from.x, fy = from.y, t = 0 }
  end
  return ok
end

function World:update(dt)
  if self.anim then
    self.anim.t = self.anim.t + dt * 6
    if self.anim.t >= 1 then self.anim = nil end
  end
end

-- Posição do cursor em casas (com a animação entre nós).
function World:cursorPos()
  local n = self:node()
  if not self.anim then return n.x, n.y end
  local t = self.anim.t
  return self.anim.fx + (n.x - self.anim.fx) * t, self.anim.fy + (n.y - self.anim.fy) * t
end

-- Estado de uma fase no mapa: "vencida", "trancada" (falta item-chave) ou "aberta".
function World:stageStatus(s)
  if self.campaign.cleared[s] then return "vencida" end
  local k = World.KEY_FOR_STAGE[s]
  if k and (self.campaign.keyItems[k] or 0) == 0 then return "trancada" end
  return "aberta"
end

---------------------------------------------------------------- diálogos

local function withSpeaker(pages, speaker)
  local out = {}
  for _, p in ipairs(pages) do
    out[#out + 1] = { speaker = p.speaker or speaker, text = p.text, key = p.key }
  end
  return out
end

-- Mostra uma ou mais mensagens do script do nó, em sequência.
function World:showMessages(node, list, speaker, onClose)
  local pages = {}
  for _, idx in ipairs(list) do
    local m = (self.data.messages[node] or {})[idx]
    if m then
      local r = Messages.resolve(m, self.campaign)
      for _, p in ipairs(withSpeaker(r.pages, speaker)) do
        p.key = ("%d:%d"):format(node, idx)
        pages[#pages + 1] = p
      end
    end
  end
  if #pages == 0 then if onClose then onClose() end return end
  self.dialog = { pages = pages, index = 1, line = 1, onClose = onClose, prevMode = self.mode }
  self.mode = "dialog"
end

function World:advanceDialog(linesShown, totalLines)
  local d = self.dialog
  if d.line + linesShown <= totalLines then
    d.line = d.line + linesShown
    return
  end
  d.index, d.line = d.index + 1, 1
  if d.index > #d.pages then
    self.dialog = nil
    self.mode = d.prevMode == "dialog" and "map" or d.prevMode
    if d.onClose then d.onClose() end
  end
end

---------------------------------------------------------------- ações

function World:openMenu(title, items)
  self.menu = { title = title, items = items, index = 1 }
  self.mode = "menu"
  Sound.music(Sound.TEAM)          -- menus das cidades usam a música $0D, como no original
end

function World:closeMenu()
  self.menu, self.mode = nil, "map"
  Sound.stageMusic_(0)
end

function World:menuMove(d)
  local m = self.menu
  if m then m.index = (m.index - 1 + d) % #m.items + 1; Sound.sfx(Sound.CURSOR) end
end

function World:confirm()
  if self.mode == "menu" then
    self.menu.items[self.menu.index].action()
  elseif self.mode == "map" then
    self.anim = nil
    self:activate()
  end
end

function World:cancel()
  if self.mode == "menu" then
    if self.menu.back then self.menu.back() else self:closeMenu() end
  end
end

-- A no nó atual ($01:$547D e menus das cidades). onEnter(fase) é chamado para começar uma luta.
function World:activate()
  local node = self.campaign.node
  local kind = World.kind(node)
  if kind == "stage" then
    if self.campaign.cleared[node] then
      self:say(Names.place_name(node) .. T(": fase já vencida"))
      return
    end
    local k = World.KEY_FOR_STAGE[node]
    if k then
      local has = (self.campaign.keyItems[k] or 0) ~= 0
      self:showMessages(node, { World.MSG_GATE }, nil, function()
        if has then self:enterStage(node) end
      end)
      return
    end
    self:enterStage(node)
  elseif kind == "town" then
    local sp = self.world.townSpeakers[node] or {}
    local stage = node                       -- Palaestra: c007 = terreno - $20
    self:openMenu(Names.place_name(node), {
      { label = T("Ginásio") .. (self.campaign.cleared[stage] and T("  (vencido)") or ""),
        action = function() self:closeMenu(); self:enterStage(stage) end },
      { label = T("Prefeito"), action = function() self:showMessages(node, { 0 }, sp[1]) end },
      { label = T("Morador"), action = function() self:showMessages(node, { 1 }, sp[2]) end },
    })
  elseif kind == "institute" then
    self:openMenu(Names.place_name(node), {
      { label = T("Vantagens de tipo"), action = function()
        self:showMessages(node, { 8 }, World.INSTITUTE_SPEAKER) end },
      { label = T("Dicas"), action = function()
        self:showMessages(node, { 0, 1, 2, 3, 4, 5 }, World.INSTITUTE_SPEAKER) end },
    })
  elseif kind == "alliance" then
    self:openMenu(Names.place_name(node), {
      { label = T("Condições de evolução"), action = function()
        self:showMessages(node, { 0, 1, 2, 3 }, World.ALLIANCE_SPEAKER) end },
      { label = T("Evoluir"), action = function() self:openEvolveMenu() end },
    })
  end
end

function World:enterStage(s)
  if s == World.FINAL_STAGE then
    self:showMessages(s, { 0 }, nil, function() if self.onEnter then self.onEnter(s) end end)
    return
  end
  if self.onEnter then self.onEnter(s) end
end

---------------------------------------------------------------- evolução (BabyAlliance)

-- Insígnia do tipo da unidade ($C4EC + tipo - 1), consumida por $01:$5630.
function World.badgeFor(u) return 0x0B + u.type end

function World:evolvable()
  local out = {}
  for _, u in ipairs(self.campaign:recruited()) do
    if Progress.canEvolve(u, self.data.prog) and (self.campaign.inventory[World.badgeFor(u)] or 0) > 0 then
      out[#out + 1] = u
    end
  end
  return out
end

function World:evolve(u)
  local inv = self.campaign.inventory
  local b = World.badgeFor(u)
  inv[b] = inv[b] - 1
  local old = Names.species_name(u.species)
  local learned = Progress.evolve(u, self.data.prog)
  self:say((T("%s evoluiu para %s!")):format(old, Names.species_name(u.species)))
  if learned then self:say((T("%s aprendeu %s")):format(Names.species_name(u.species), Names.skill_name(learned))) end
  self.campaign:save()
end

function World:openEvolveMenu()
  local items = {}
  for _, u in ipairs(self:evolvable()) do
    local b = World.badgeFor(u)
    items[#items + 1] = {
      label = ("%s Nv %d -> %s   (%s x%d)"):format(Names.species_name(u.species), u.level,
        Names.species_name(u.species + 1), Items.name(b), self.campaign.inventory[b]),
      action = function() self:evolve(u); self:openEvolveMenu() end,
    }
  end
  if #items == 0 then
    self:say(T("Ninguém pode evoluir: falta a insígnia do tipo"))
    self:closeMenu()
    return
  end
  self:openMenu(T("Evoluir (gasta a insígnia do tipo)"), items)
  self.menu.wide = true
  self.menu.back = function() self:closeMenu() end
end

return World
