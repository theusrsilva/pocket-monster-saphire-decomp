-- Operações de bits: usa o "bit" do LuaJIT (LÖVE no PC) e cai para uma versão em Lua puro
-- quando ele não existe (LÖVE Potion no 3DS/Switch roda Lua 5.1 sem LuaJIT).
local ok, lib = pcall(require, "bit")
if ok and lib then return lib end
ok, lib = pcall(require, "bit32")
if ok and lib then
  return { band = lib.band, bor = lib.bor, bxor = lib.bxor, lshift = lib.lshift, rshift = lib.rshift }
end

local floor = math.floor
local B = {}
local function op(a, b, f)
  a, b = a % 4294967296, b % 4294967296
  local r, p = 0, 1
  while a > 0 or b > 0 do
    local x, y = a % 2, b % 2
    if f(x, y) then r = r + p end
    a, b, p = floor(a / 2), floor(b / 2), p * 2
  end
  return r
end
function B.band(a, b, ...) local r = op(a, b, function(x, y) return x == 1 and y == 1 end); if ... then return B.band(r, ...) end return r end
function B.bor(a, b, ...) local r = op(a, b, function(x, y) return x == 1 or y == 1 end); if ... then return B.bor(r, ...) end return r end
function B.bxor(a, b) return op(a, b, function(x, y) return x ~= y end) end
function B.lshift(a, n) return (a * 2 ^ n) % 4294967296 end
function B.rshift(a, n) return floor((a % 4294967296) / 2 ^ n) end
return B
