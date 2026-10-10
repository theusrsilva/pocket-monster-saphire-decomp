-- Recorte da ROM com só o que a cena de ataque (src/anim/attack.lua) lê: tabelas, scripts de
-- animação, metasprites, tiles dos quadros, caixas de colisão, paletas e scripts de cenário.
-- O importador grava o recorte no cache (generated/attack.bin); assim o console não precisa da
-- ROM inteira. Formato: "SAPHANIM1" e blocos [banco u8][endereço u16][tamanho u16][bytes].
local Slice = {}

local function at(bank, addr) return bank * 0x4000 + addr - 0x4000 end

-- Leitor sobre a ROM inteira (string).
function Slice.fromRom(rom)
  return { u8 = function(_, bank, addr)
    if addr < 0x4000 then return rom:byte(addr + 1) end
    return rom:byte(at(bank, addr) + 1) or 0xFF
  end }
end

-- Monta o recorte percorrendo as estruturas a partir das tabelas.
function Slice.build(rom)
  local R = Slice.fromRom(rom)
  local function u8(b, a) return R:u8(b, a) end
  local function u16(b, a) return u8(b, a) + u8(b, a + 1) * 256 end
  local need = {}                                    -- [banco] = { [endereço] = true }
  local function mark(b, a, n)
    need[b] = need[b] or {}
    local t = need[b]
    for i = 0, n - 1 do t[a + i] = true end
  end
  local function mread(b, a) mark(b, a, 1) return u8(b, a) end
  local function mread16(b, a) mark(b, a, 2) return u16(b, a) end

  -- personagens: $7C + espécie (espécies da tabela $09:$6F4D), efeitos criados e a faísca $79
  local chars, done = {}, {}
  local function addChar(c) if not done[c] then done[c] = true; chars[#chars + 1] = c end end
  for sp = 0, 0x4B do addChar(0x7C + sp) end
  addChar(0x79)
  -- tabela de golpes por espécie
  for sp = 0, 0x4B do
    local list = mread16(0x09, 0x6F4D + sp * 2)
    mark(0x09, list, 8)
  end
  mark(0x01, 0x64DF, 0x4C + 1)                       -- música por espécie
  mark(0x38, 0x7139, 0x20)                           -- terreno -> cenário
  for sp = 0, 0x4B do mark(0x38, mread16(0x38, 0x71BC + sp * 2), 8) end   -- paletas

  local sizes = { [0x81] = 4, [0x85] = 8, [0x8C] = 4, [0x8E] = 4 }
  local i = 1
  while i <= #chars do
    local c = chars[i]
    i = i + 1
    local frames = { [0] = true }              -- quadro 0: caixas lidas antes do 1º passo
    local t = 0x4000 + c * 4
    local list, bank = mread16(0x04, t), mread(0x04, t + 2)
    local first = u16(bank, list)
    local n = first > list and math.floor((first - list) / 2) or 1
    mark(bank, list, n * 2)
    local anims = {}
    for k = 0, n - 1 do
      anims[k] = true
      local p = u16(bank, list + k * 2)
      for _ = 1, 400 do
        local b0, b1 = mread(bank, p), mread(bank, p + 1)
        if b0 == 0xFF and b1 == 0xFF then break end
        mark(bank, p, 4)
        frames[u8(bank, p + 2)] = true
        p = p + 4
        local cmd = mread(bank, p)
        if cmd >= 0x80 and cmd < 0x93 then
          if cmd == 0x80 then mark(bank, p, 2) break end
          local sz = sizes[cmd] or error(("recorte: comando $%02X"):format(cmd))
          mark(bank, p, sz)
          if cmd == 0x85 then addChar(u8(bank, p + 1)) end
          p = p + sz
        end
      end
    end
    -- modelo de criação ($1C:$4000 + c*16)
    mark(0x1C, 0x4000 + c * 16, 16)
    -- caixas ($2D:$43ED) e colisão ($2D:$4FA7)
    local bp = mread16(0x2D, 0x43ED + c * 2)
    local hasBoxes = not (mread(0x2D, bp) == 0xFF and mread(0x2D, bp + 1) == 0xFF)
    local cp = mread16(0x2D, 0x4FA7 + c * 2)
    for k in pairs(anims) do mark(0x2D, cp + k * 2, 2) end
    -- metasprites ($80:$4000) e tiles dos quadros ($80:$4400)
    local mt = 0x4000 + c * 4
    local mp, mb = mread16(0x80, mt), (mark(0x80, mt + 2, 2) or u8(0x80, mt + 3))
    local gt = 0x4400 + c * 4
    local gb, gp = mread(0x80, gt), (mark(0x80, gt + 1, 3) or u16(0x80, gt + 2))
    for f in pairs(frames) do
      if hasBoxes then mark(0x2D, bp + f * 10, 10) end
      local fp = mread16(mb, mp + f * 2)
      local cnt = mread(mb, fp)
      mark(mb, fp, 2 + 5 * cnt)
      local e = gp + f * 4
      local tb = mread(gb, e)
      mark(gb, e, 4)
      local tp = u16(gb, e + 2)
      if tp ~= 0 and tb ~= 0 then
        local len = u8(tb, tp) * 256 + u8(tb, tp + 1)
        local nb = ((math.floor(len / 16) - 1) % 128 + 1) * 16
        mark(tb, tp, 16)
        mark(tb, tp + 16 - (tp % 16), nb)
      end
    end
  end

  -- cenários ($BC:$4000[$2F + terreno]) e scripts do painel
  local BG = 0xBC
  local seen = {}
  local function script(p)
    while not seen[p] do
      seen[p] = true
      local h = mread16(BG, p)
      if h == 0xFFFF then return end
      if h == 0x2DA0 then
        local q = p + 2
        while mread(BG, q) ~= 0xFF do mark(BG, q, 4) q = q + 4 end
        mark(BG, q, 2)
        p = q + 2
      elseif h == 0x2DDB then
        mark(BG, p, 12)
        local src, bank = u16(BG, p + 8), u8(BG, p + 6)
        mark(bank, src - src % 16, ((u8(BG, p + 10) % 128) + 1) * 16)
        p = p + 12
      elseif h == 0x2E3B then
        mark(BG, p, 12)
        mark(u8(BG, p + 4), u16(BG, p + 6), u8(BG, p + 10))
        p = p + 12
      elseif h == 0x2EB0 then
        mark(BG, p, 12)
        mark(u8(BG, p + 6), u16(BG, p + 8), u8(BG, p + 10) * u8(BG, p + 11))
        p = p + 12
      elseif h == 0x5940 then
        mark(BG, p, 4)
        p = u16(BG, p + 2)
      elseif h == 0x322B or h == 0x5D49 or h == 0x5E23 then
        mark(BG, p, 10)
        if h == 0x322B then
          local st = 0x60A2 + u8(BG, p + 8) * 6
          mark(BG, st, 6)
          mark(BG, u16(BG, st), 2 * 10 * u8(BG, st + 2) * u8(BG, st + 4))
        end
        p = p + 10
      else
        error(("recorte: comando de cenário $%04X"):format(h))
      end
    end
  end
  for k = 0, 0x1F do
    local s = (u8(0x38, 0x7139 + k) + 0x2F) % 256
    script(mread16(BG, 0x4000 + s * 2))
  end
  script(0x54BE)
  script(0x54E8)

  -- serializa em blocos contíguos
  local out = { "SAPHANIM1" }
  local banks = {}
  for b in pairs(need) do banks[#banks + 1] = b end
  table.sort(banks)
  local total = 0
  for _, b in ipairs(banks) do
    local addrs = {}
    for a in pairs(need[b]) do addrs[#addrs + 1] = a end
    table.sort(addrs)
    local k = 1
    while k <= #addrs do
      local s, e = addrs[k], addrs[k]
      while addrs[k + 1] and addrs[k + 1] <= e + 8 and addrs[k + 1] - s < 0xFFFF do
        k = k + 1
        e = addrs[k]
      end
      local len = e - s + 1
      local base = (b == 0 and 0 or at(b, 0x4000)) + s - 0x4000
      if b == 0 then base = s end
      out[#out + 1] = string.char(b, s % 256, math.floor(s / 256), len % 256, math.floor(len / 256))
      out[#out + 1] = rom:sub(base + 1, base + len)
      total = total + len
      k = k + 1
    end
  end
  return table.concat(out), total, need
end

-- Leitor sobre o recorte: um texto de 16 KB por banco, montado na primeira leitura do banco.
function Slice.load(data)
  assert(data:sub(1, 9) == "SAPHANIM1", "recorte de animação inválido")
  local blocks = {}
  local p = 10
  while p <= #data do
    local b = data:byte(p)
    local s = data:byte(p + 1) + data:byte(p + 2) * 256
    local len = data:byte(p + 3) + data:byte(p + 4) * 256
    blocks[b] = blocks[b] or {}
    table.insert(blocks[b], { s, data:sub(p + 5, p + 4 + len) })
    p = p + 5 + len
  end
  local banks = {}
  local reader = { missing = {} }
  local function bankStr(b)
    local s = banks[b]
    if s then return s end
    local parts, pos = {}, 0x4000
    table.sort(blocks[b] or {}, function(x, y) return x[1] < y[1] end)
    for _, blk in ipairs(blocks[b] or {}) do
      if blk[1] > pos then parts[#parts + 1] = string.rep("\255", blk[1] - pos) end
      parts[#parts + 1] = blk[2]
      pos = blk[1] + #blk[2]
    end
    if pos < 0x8000 then parts[#parts + 1] = string.rep("\255", 0x8000 - pos) end
    s = table.concat(parts)
    banks[b] = s
    return s
  end
  function reader.u8(_, bank, addr)
    if addr < 0x4000 then return 0xFF end
    return bankStr(bank):byte(addr - 0x3FFF)
  end
  reader.blocks = blocks
  return reader
end

return Slice
