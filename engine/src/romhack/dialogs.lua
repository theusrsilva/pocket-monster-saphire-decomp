-- Falas em português dentro da ROM (ver docs/FINDINGS.md, "ROM traduzida").
--
-- Motor de texto do original:
--   * índice $5D:$4000: ponteiro u16 por script ([$C2B0]) -> entradas [lo, hi, banco, 00] por
--     mensagem ([$C2B1]); leitora ROM0:$3296.
--   * bytes < $E0 são caracteres; o glifo sai da tabela $39:$4226 (byte -> tile) e é escrito direto
--     no mapa de tiles; a fonte (64 tiles, banco 1 da VRAM $8C00) vem de $39:$4365.
--   * quebra de linha só por coluna (Text_Char, $39:$4125): ao chegar na largura da caixa passa
--     para a linha de baixo, mesmo no meio da palavra; com a caixa cheia espera o botão e rola.
--   * largura da caixa por script: $39:$407D[script] -> configuração de 8 bytes em $39:$40ED
--     (+2 = largura); fases ($21-$39) mensagens $17-$1B usam 16 colunas.
--   * comandos: E2 a16 v16 pIgual pDif (desvio no mesmo banco), E8 xx (velocidade), EA xx (falante),
--     EE 01/02 a16 e EE 03 a16 v16 (efeitos), FF fim. Tamanhos na tabela ROM0:$3427.
--
-- A conversão grava cada trecho de fala de novo, em bancos vazios da ROM, com o texto da
-- tradução (src/game/translation_pt.lua) em MAIÚSCULAS e já quebrado em palavras inteiras, e
-- reaponta o índice. As letras acentuadas ocupam os glifos das minúsculas (que deixam de ser usados:
-- todo texto que continua no original é passado para maiúsculas).
local Buffer = require("src.romhack.buffer")

local Dialogs = {}

local at = Buffer.at
local INDEX_BANK, INDEX_ADDR = 0x5D, 0x4000
local TEXT_BANKS = { [0x5D] = true, [0x70] = true }

-- Letra acentuada -> byte (o glifo da minúscula correspondente é redesenhado, ver Dialogs.font).
Dialogs.ACCENTS = {
  { "Á", "a", "A", "acute" }, { "À", "b", "A", "grave" }, { "Â", "c", "A", "circ" },
  { "Ã", "d", "A", "tilde" }, { "É", "e", "E", "acute" }, { "Ê", "f", "E", "circ" },
  { "Í", "g", "I", "acute" }, { "Ó", "h", "O", "acute" }, { "Ô", "i", "O", "circ" },
  { "Õ", "j", "O", "tilde" }, { "Ú", "k", "U", "acute" }, { "Ç", "l", "C", "cedilla" },
  { "Ü", "m", "U", "dier" },
}
local LOWER_ACC = {
  ["á"] = "Á", ["à"] = "À", ["â"] = "Â", ["ã"] = "Ã", ["é"] = "É", ["ê"] = "Ê", ["í"] = "Í",
  ["ó"] = "Ó", ["ô"] = "Ô", ["õ"] = "Õ", ["ú"] = "Ú", ["ç"] = "Ç", ["ü"] = "Ü",
}
local ACC_BYTE = {}
for _, a in ipairs(Dialogs.ACCENTS) do ACC_BYTE[a[1]] = a[2]:byte() end
-- Caracteres sem glifo na fonte do jogo.
local SUBST = { ['"'] = "'", ["`"] = "'", ["…"] = "...", ["—"] = "-", ["–"] = "-", ["~"] = "-" }

-- Texto UTF-8 -> lista de bytes do jogo (maiúsculas, acentos nos glifos remapeados).
function Dialogs.encode(s)
  local out = {}
  for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    ch = SUBST[ch] or LOWER_ACC[ch] or ch
    if ACC_BYTE[ch] then
      out[#out + 1] = ACC_BYTE[ch]
    elseif #ch == 1 then
      for i = 1, #ch do
        local b = ch:upper():byte(i)
        if b >= 32 and b < 127 then out[#out + 1] = b end
      end
    else
      for i = 1, #ch do                     -- sequência longa sem glifo (ex.: "...")
        local b = ch:byte(i)
        if b < 128 then out[#out + 1] = b end
      end
    end
  end
  return out
end

-- Quebra em palavras inteiras para uma caixa de `width` colunas: completa a linha com espaços
-- (o motor só quebra pela coluna). Palavras maiores que a linha são cortadas como no original.
function Dialogs.wrap(bytes, width)
  local words, cur = {}, {}
  for _, b in ipairs(bytes) do
    if b == 32 then
      if #cur > 0 then words[#words + 1] = cur; cur = {} end
    else
      cur[#cur + 1] = b
    end
  end
  if #cur > 0 then words[#words + 1] = cur end
  local out, col = {}, 0
  for _, w in ipairs(words) do
    if col > 0 then
      if col + 1 + #w <= width then
        out[#out + 1] = 32; col = col + 1
      else
        for _ = col + 1, width do out[#out + 1] = 32 end
        col = 0
      end
    end
    for _, b in ipairs(w) do out[#out + 1] = b end
    col = (col + #w) % width
  end
  return out
end

-- Lê um trecho (até FF ou E2). Devolve a lista de itens: {text = {bytes}} | {cmd = {bytes}} |
-- {e2 = {addr, value, eq, ne}} | {stop = true}.
local function parse(rom, cmdLen, bank, addr)
  local items, o, text = {}, at(bank, addr), nil
  for _ = 1, 4000 do
    local c = rom:u8(o)
    if c == 0xFF then
      items[#items + 1] = { stop = true }
      return items
    elseif c < 0xE0 then
      if not text then text = { text = {} }; items[#items + 1] = text end
      text.text[#text.text + 1] = c
      o = o + 1
    elseif c == 0xE2 then
      items[#items + 1] = { e2 = { rom:u16(o + 1), rom:u16(o + 3), rom:u16(o + 5), rom:u16(o + 7) } }
      return items
    else
      local n = math.max(cmdLen[c] or 1, 1)
      if c == 0xEE and rom:u8(o + 1) == 3 then n = 6 end
      local cmd = {}
      for i = 0, n - 1 do cmd[#cmd + 1] = rom:u8(o + i) end
      items[#items + 1] = { cmd = cmd }
      text = nil
      o = o + n
    end
  end
  error(("trecho sem fim em %02X:%04X"):format(bank, addr))
end

local function blank(bytes)
  for _, b in ipairs(bytes) do if b ~= 32 then return false end end
  return true
end

local function upperBytes(bytes)
  local t = {}
  for i, b in ipairs(bytes) do t[i] = (b >= 0x61 and b <= 0x7A) and b - 32 or b end
  return t
end

-- Regiões de página: começam no início do trecho e em cada EA (a fala troca de falante); o
-- mesmo critério de página do importador (src/import/importer.lua: decodeMessage).
local function regions(items)
  local regs, cur = {}, {}
  regs[1] = cur
  for _, it in ipairs(items) do
    if it.cmd and it.cmd[1] == 0xEA and #cur > 0 then
      cur = {}
      regs[#regs + 1] = cur
    end
    if not it.stop and not it.e2 then cur[#cur + 1] = it end
  end
  return regs
end

-- Codifica um trecho. pages = tradução (uma string por página não vazia) ou nil.
-- ptr(key) devolve o novo endereço de outro trecho (desvios E2).
local function encodeSegment(items, pages, width, ptr, bank)
  local out = {}
  local function put(t) for _, b in ipairs(t) do out[#out + 1] = b end end
  local page = 0
  for _, reg in ipairs(regions(items)) do
    local raw = {}
    for _, it in ipairs(reg) do if it.text then for _, b in ipairs(it.text) do raw[#raw + 1] = b end end end
    if blank(raw) then
      for _, it in ipairs(reg) do put(it.cmd or upperBytes(it.text)) end
    else
      page = page + 1
      local pt = pages and pages[page]
      if not pt then
        for _, it in ipairs(reg) do put(it.cmd or upperBytes(it.text)) end
      else
        local seenText, after = false, {}
        for _, it in ipairs(reg) do
          if it.text and not blank(it.text) then seenText = true end
          if it.cmd then
            if seenText then after[#after + 1] = it.cmd else put(it.cmd) end
          end
        end
        put(Dialogs.wrap(Dialogs.encode(pt), width))
        for _, c in ipairs(after) do put(c) end
      end
    end
  end
  local last = items[#items]
  if last.e2 then
    local a, v, eq, ne = last.e2[1], last.e2[2], ptr(bank, last.e2[3]), ptr(bank, last.e2[4])
    put({ 0xE2, a % 256, math.floor(a / 256), v % 256, math.floor(v / 256),
          eq % 256, math.floor(eq / 256), ne % 256, math.floor(ne / 256) })
  else
    put({ 0xFF })
  end
  return out
end

-- Todas as entradas do índice: { script, msg, offset da entrada, bank, addr }.
function Dialogs.entries(rom)
  local base = at(INDEX_BANK, INDEX_ADDR)
  local ptrs, lowest = {}, 0x8000
  for s = 0, 0x7F do
    if INDEX_ADDR + s * 2 >= lowest then break end
    local p = rom:u16(base + s * 2)
    ptrs[s] = p
    if p >= 0x4000 and p < lowest then lowest = p end
  end
  local sorted = {}
  for _, p in pairs(ptrs) do sorted[#sorted + 1] = p end
  table.sort(sorted)
  -- 1ª passada: cada lista até o próximo ponteiro, para achar onde começa o texto no banco $5D
  local textStart = 0x8000
  local function read(limitOf)
    local out = {}
    for s, p in pairs(ptrs) do
      local nextp = 0x8000
      for _, q in ipairs(sorted) do if q > p then nextp = q; break end end
      local stop = limitOf(p, nextp)
      local m = 0
      while p + m * 4 + 3 < stop do
        local e = at(INDEX_BANK, p) + m * 4
        local lo, hi, bank = rom:u8(e), rom:u8(e + 1), rom:u8(e + 2)
        local addr = lo + hi * 256
        if not (TEXT_BANKS[bank] and addr >= 0x4000 and addr < 0x8000) then break end
        out[#out + 1] = { script = s, msg = m, entry = e, bank = bank, addr = addr, table = p }
        m = m + 1
      end
    end
    return out
  end
  for _, e in ipairs(read(function(_, nextp) return nextp end)) do
    if e.bank == INDEX_BANK and e.addr > sorted[#sorted] and e.addr < textStart then textStart = e.addr end
  end
  -- 2ª passada: as listas se sobrepõem (a do script $46 continua na do $47), então cada uma vai até
  -- uma entrada inválida ou o começo do texto; a lista vazia compartilhada ($4096) vai até o próximo
  local all = read(function(p, nextp) return p == lowest and nextp or textStart end)
  local byEntry = {}
  for _, e in ipairs(all) do                     -- cada entrada fica com a lista mais próxima
    local cur = byEntry[e.entry]
    if not cur or e.table > cur.table then byEntry[e.entry] = e end
  end
  local out = {}
  for _, e in pairs(byEntry) do out[#out + 1] = e end
  table.sort(out, function(a, b) return a.entry < b.entry end)
  return out
end

-- Largura da caixa de texto de uma mensagem ($39:$4000).
function Dialogs.boxWidth(rom, script, msg)
  if script >= 0x21 and script < 0x3A and msg >= 0x17 and msg < 0x1C then return 16 end
  local cfg = rom:u8(at(0x39, 0x407D) + script)
  local w = rom:u8(at(0x39, 0x40ED) + cfg * 8 + 2)
  return (w >= 4 and w <= 20) and w or 16
end

local function key(bank, addr) return ("%02X:%04X"):format(bank, addr) end

-- Aplica as falas. freeBanks = lista de bancos vazios para usar. Devolve um relatório.
function Dialogs.apply(rom, PT, freeBanks)
  local cmdLen = {}
  for i = 0, 31 do cmdLen[0xE0 + i] = rom:u8(0x3427 + i * 4 + 2) end
  -- 1) todos os trechos alcançáveis, ligados pelos desvios E2 (um grupo precisa ficar num banco só)
  local segs, order = {}, {}
  local parent = {}
  local function find(k) while parent[k] ~= k do k = parent[k] end return k end
  local function visit(bank, addr, width)
    local k = key(bank, addr)
    local s = segs[k]
    if s then
      s.width = math.min(s.width, width)
      return k
    end
    s = { bank = bank, addr = addr, width = width, items = parse(rom, cmdLen, bank, addr) }
    segs[k] = s; order[#order + 1] = k; parent[k] = k
    local last = s.items[#s.items]
    if last.e2 then
      for i = 3, 4 do
        local t = visit(bank, last.e2[i], width)
        parent[find(t)] = find(k)
      end
    end
    return k
  end
  local entries = Dialogs.entries(rom)
  local nDesc
  PT, nDesc = require("src.romhack.descriptions").add(rom, PT, entries)
  for _, e in ipairs(entries) do
    e.key = visit(e.bank, e.addr, Dialogs.boxWidth(rom, e.script, e.msg))
  end
  local groups, gorder = {}, {}
  for _, k in ipairs(order) do
    local r = find(k)
    if not groups[r] then groups[r] = {}; gorder[#gorder + 1] = r end
    table.insert(groups[r], k)
  end
  -- 2) codifica cada grupo (duas passadas: tamanhos, depois endereços dos desvios)
  local newAddr, newBank = {}, {}
  local report = { segments = #order, translated = 0, bytes = 0, banks = {} }
  local bi, free = 1, 0x4000
  local function ptr(_, a) return newAddr[key(_, a)] end
  for _, r in ipairs(gorder) do
    local ks = groups[r]
    local sizes, total = {}, 0
    for _, k in ipairs(ks) do
      local s = segs[k]
      s.pages = PT[k]
      local enc = encodeSegment(s.items, s.pages, s.width, function() return 0 end, s.bank)
      sizes[k] = #enc; total = total + #enc
    end
    if free + total > 0x8000 then bi = bi + 1; free = 0x4000 end
    local bank = assert(freeBanks[bi], "sem bancos livres para o texto")
    local a = free
    for _, k in ipairs(ks) do newAddr[k] = a; newBank[k] = bank; a = a + sizes[k] end
    local function gptr(b, addr) return assert(newAddr[key(b, addr)]) end
    for _, k in ipairs(ks) do
      local s = segs[k]
      local enc = encodeSegment(s.items, s.pages, s.width, gptr, s.bank)
      assert(#enc == sizes[k])
      rom:write(at(bank, newAddr[k]), enc)
      if s.pages then report.translated = report.translated + 1 end
    end
    free = a
    report.bytes = report.bytes + total
    report.banks[bi] = bank
  end
  -- 3) reaponta o índice
  for _, e in ipairs(entries) do
    local k = e.key
    rom:write(e.entry, { newAddr[k] % 256, math.floor(newAddr[k] / 256), newBank[k] })
  end
  report.entries = #entries
  report.descriptions = nDesc
  return report
end

-- ---------------------------------------------------------------------------------------------
-- Fonte: os glifos das minúsculas viram as letras acentuadas, desenhadas a partir da maiúscula
-- da própria fonte da ROM (o corpo é achatado em 5 linhas para caber o acento em cima).
local FONT_BANK, FONT_ADDR, CHARMAP = 0x39, 0x4365, 0x4226
local MARKS = {
  acute = { "....##..", "...##..." },
  grave = { "..##....", "...##..." },
  circ = { "...##...", "..#..#.." },
  tilde = { "..##.#..", ".#.##..." },
  dier = { "..#..#..", "........" },
}

local function glyphOffset(rom, ch)
  local tile = rom:u8(at(FONT_BANK, CHARMAP) + ch:byte())
  return at(FONT_BANK, FONT_ADDR) + (tile - 0xC0) * 16
end

-- Lê um tile 2bpp como matriz de cores 0-3.
local function readTile(rom, o)
  local px = {}
  for y = 0, 7 do
    local lo, hi = rom:u8(o + 2 * y), rom:u8(o + 2 * y + 1)
    px[y] = {}
    for x = 0, 7 do
      local bit = 2 ^ (7 - x)
      px[y][x] = (math.floor(lo / bit) % 2) + 2 * (math.floor(hi / bit) % 2)
    end
  end
  return px
end

local function writeTile(rom, o, px)
  for y = 0, 7 do
    local lo, hi = 0, 0
    for x = 0, 7 do
      local c = px[y][x]
      if c % 2 == 1 then lo = lo + 2 ^ (7 - x) end
      if c >= 2 then hi = hi + 2 ^ (7 - x) end
    end
    rom:set(o + 2 * y, lo)
    rom:set(o + 2 * y + 1, hi)
  end
end

local function rowKey(r) return table.concat(r, ",", 0, 7) end

function Dialogs.font(rom)
  local space = readTile(rom, glyphOffset(rom, " "))
  local bg = space[0][0]
  for _, a in ipairs(Dialogs.ACCENTS) do
    local base = readTile(rom, glyphOffset(rom, a[3]))
    local ink
    for y = 0, 7 do for x = 0, 7 do if not ink and base[y][x] ~= bg then ink = base[y][x] end end end
    local out = {}
    for y = 0, 7 do out[y] = {} for x = 0, 7 do out[y][x] = bg end end
    if a[4] == "cedilla" then
      for y = 0, 6 do out[y] = base[y] end
      local m = "...##..."
      for x = 0, 7 do out[7][x] = m:sub(x + 1, x + 1) == "#" and ink or bg end
    else
      -- corpo: linhas 0-6 da maiúscula -> 5 linhas (tira duas linhas repetidas, de preferência 5 e 1)
      local rows = {}
      for y = 0, 6 do rows[#rows + 1] = base[y] end
      local drops = 0
      for _, cand in ipairs({ 6, 2, 5, 3 }) do                 -- índices em rows (1-based)
        if drops < 2 and rows[cand] and (rowKey(rows[cand]) == rowKey(rows[cand - 1])
            or (rows[cand + 1] and rowKey(rows[cand]) == rowKey(rows[cand + 1]))) then
          table.remove(rows, cand); drops = drops + 1
        end
      end
      while #rows > 5 do table.remove(rows, #rows > 6 and 6 or 2) end
      if a[3] == "I" then             -- o I da fonte é só uma haste: com o acento parecia "1"
        rows = {}
        for i, m in ipairs({ "...####.", "....##..", "....##..", "....##..", "...####." }) do
          rows[i] = {}
          for x = 0, 7 do rows[i][x] = m:sub(x + 1, x + 1) == "#" and ink or bg end
        end
      end
      for i = 1, 5 do out[i + 1] = rows[i] end
      local mk = MARKS[a[4]]
      for y = 0, 1 do
        for x = 0, 7 do out[y][x] = mk[y + 1]:sub(x + 1, x + 1) == "#" and ink or bg end
      end
    end
    writeTile(rom, glyphOffset(rom, a[2]), out)
  end
end

return Dialogs
