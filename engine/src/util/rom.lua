-- Leitura de bytes da ROM (string Lua imutável, índices base 0 como na documentação).
local Rom = {}
Rom.__index = Rom

Rom.SHA1 = "9fa7da61c61d684f39e43d6899a68309ba8607b3"

function Rom.new(bytes)
  return setmetatable({ data = bytes, size = #bytes }, Rom)
end

-- Byte no offset absoluto o (base 0).
function Rom:u8(o)
  return self.data:byte(o + 1)
end

function Rom:u16(o)
  local lo, hi = self.data:byte(o + 1, o + 2)
  return lo + hi * 256
end

-- Offset absoluto de banco:endereço (endereço $4000-$7FFF).
function Rom.at(bank, addr)
  return bank * 0x4000 + (addr - 0x4000)
end

function Rom:sub(o, n)
  return self.data:sub(o + 1, o + n)
end

function Rom:sha1()
  return love.data.encode("string", "hex", love.data.hash("sha1", self.data))
end

return Rom
