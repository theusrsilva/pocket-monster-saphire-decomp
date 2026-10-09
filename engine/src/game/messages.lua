-- Falas do script: resolve os desvios condicionais (comando E2) contra o estado da campanha e
-- escolhe o texto original ou a tradução (src/game/translation_pt.lua).
local I18n = require("src.game.i18n")

local Messages = {}

local ok, PT = pcall(require, "src.game.translation_pt")
Messages.PT = ok and PT or {}

-- Texto da página n do trecho seg (chave "BB:AAAA" = banco:endereço do trecho na ROM).
-- Em português (I18n.lang = "pt") usa a tradução; em inglês, o texto original do jogo.
function Messages.text(seg, n, original)
  if I18n.lang == "pt" then
    local t = Messages.PT[seg]
    if t and t[n] then return t[n] end
  end
  return original
end

-- Devolve { pages, effects } já seguindo os ramos E2 (byte[addr] == value -> eq, senão ne).
function Messages.resolve(msg, campaign)
  local pages, effects = {}, {}
  local m = msg
  while m do
    local base = #pages
    for i, p in ipairs(m.pages or {}) do
      pages[#pages + 1] = { speaker = p.speaker, text = Messages.text(m.key, i, p.text) }
    end
    for _, e in ipairs(m.effects or {}) do
      local c = {}
      for k, v in pairs(e) do c[k] = v end
      c.page = (e.page or 1) + base
      effects[#effects + 1] = c
    end
    if m.cond then
      m = (campaign:peek(m.cond.addr) == m.cond.value) and m.eq or m.ne
    else
      m = nil
    end
  end
  return { pages = pages, effects = effects }
end

-- Todos os trechos de fala distintos (para o despejo de texto e os testes da tradução).
function Messages.segments(data)
  local out, seen = {}, {}
  local function visit(m, where)
    if not m or not m.key then return end
    if not seen[m.key] then
      seen[m.key] = true
      out[#out + 1] = { key = m.key, pages = m.pages, effects = m.effects, where = where }
    end
    visit(m.eq, where .. " =")
    visit(m.ne, where .. " !=")
  end
  for node = 0, 33 do
    local msgs = data.messages[node] or {}
    for idx = 0, 40 do
      if msgs[idx] then visit(msgs[idx], ("nó %d msg %d"):format(node, idx)) end
    end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

return Messages
