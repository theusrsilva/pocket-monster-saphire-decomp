-- Serializador mínimo de tabelas Lua (números, strings, booleanos, tabelas aninhadas).
local function ser(v, out, indent)
  local t = type(v)
  if t == "number" or t == "boolean" then
    out[#out + 1] = tostring(v)
  elseif t == "string" then
    out[#out + 1] = string.format("%q", v)
  elseif t == "table" then
    out[#out + 1] = "{"
    -- parte de array só até o primeiro buraco (# é indefinido em tabelas esparsas)
    local n = 0
    while v[n + 1] ~= nil do n = n + 1 end
    for i = 1, n do
      ser(v[i], out, indent)
      out[#out + 1] = ","
    end
    local keys = {}
    for k in pairs(v) do
      if not (type(k) == "number" and k >= 1 and k <= n and k % 1 == 0) then
        keys[#keys + 1] = k
      end
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
      if type(k) == "string" and k:match("^[%a_][%w_]*$") then
        out[#out + 1] = k .. "="
      else
        out[#out + 1] = "["
        ser(k, out, indent)
        out[#out + 1] = "]="
      end
      ser(v[k], out, indent)
      out[#out + 1] = ","
    end
    out[#out + 1] = "}"
  else
    error("tipo não serializável: " .. t)
  end
end

return function(v)
  local out = { "return " }
  ser(v, out, "")
  return table.concat(out)
end
