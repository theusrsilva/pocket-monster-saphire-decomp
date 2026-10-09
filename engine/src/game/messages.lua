-- Falas do script: resolve os desvios condicionais (comando E2) contra o estado da campanha.
local Messages = {}

-- Devolve { pages, effects } já seguindo os ramos E2 (byte[addr] == value -> eq, senão ne).
function Messages.resolve(msg, campaign)
  local pages, effects = {}, {}
  local m = msg
  while m do
    local base = #pages
    for _, p in ipairs(m.pages or {}) do pages[#pages + 1] = p end
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

return Messages
