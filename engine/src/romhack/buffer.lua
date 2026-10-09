-- Cópia editável da ROM: a string original fica intacta e as escritas vão para uma tabela esparsa.
-- Offsets absolutos base 0, como no resto do projeto.
local Buffer = {}
Buffer.__index = Buffer

function Buffer.new(bytes)
  return setmetatable({ base = bytes, size = #bytes, w = {}, dirty = {} }, Buffer)
end

function Buffer.at(bank, addr)
  return bank * 0x4000 + (addr - 0x4000)
end

function Buffer:u8(o)
  local v = self.w[o]
  if v then return v end
  return self.base:byte(o + 1)
end

function Buffer:u16(o)
  return self:u8(o) + self:u8(o + 1) * 256
end

function Buffer:set(o, v)
  assert(o >= 0 and o < self.size, "escrita fora da ROM")
  self.w[o] = v % 256
  self.dirty[math.floor(o / 0x4000)] = true
end

-- Escreve uma lista de bytes ou uma string.
function Buffer:write(o, data)
  if type(data) == "string" then
    for i = 1, #data do self:set(o + i - 1, data:byte(i)) end
  else
    for i, v in ipairs(data) do self:set(o + i - 1, v) end
  end
end

-- Confere bytes do original antes de alterar (protege contra ROM diferente da esperada).
function Buffer:expect(o, hex)
  for i = 1, #hex / 2 do
    local want = tonumber(hex:sub(2 * i - 1, 2 * i), 16)
    if self.base:byte(o + i) ~= want then
      error(("ROM inesperada em $%06X (esperado %s)"):format(o, hex))
    end
  end
end

-- O banco inteiro está vazio (só $00 ou só $FF) no original?
function Buffer:bankEmpty(bank)
  local s = self.base:sub(bank * 0x4000 + 1, bank * 0x4000 + 0x4000)
  return not s:find("[^%z]") or not s:find("[^\255]")
end

-- Monta a ROM final e recalcula o checksum global (cabeçalho $14E-$14F, big-endian).
function Buffer:build()
  local parts = {}
  for b = 0, self.size / 0x4000 - 1 do
    local o = b * 0x4000
    if self.dirty[b] then
      local t = {}
      for i = 0, 0x3FFF do t[i + 1] = string.char(self:u8(o + i)) end
      parts[#parts + 1] = table.concat(t)
    else
      parts[#parts + 1] = self.base:sub(o + 1, o + 0x4000)
    end
  end
  local rom = table.concat(parts)
  local sum = 0
  for i = 1, #rom, 4096 do
    local chunk = { rom:byte(i, math.min(i + 4095, #rom)) }
    for _, v in ipairs(chunk) do sum = sum + v end
  end
  sum = sum - rom:byte(0x14E + 1) - rom:byte(0x14F + 1)
  sum = sum % 0x10000
  return rom:sub(1, 0x14E) .. string.char(math.floor(sum / 256), sum % 256) .. rom:sub(0x151)
end

return Buffer
