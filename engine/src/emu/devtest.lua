-- Desenvolvimento: roda o executor GBC a partir de um snapshot do PyBoy (memória + registradores)
-- e grava quadros em PNG para comparar com o emulador de referência. Nada disso vai para o git.
local GBC = require("src.emu.gbc")

local Dev = {}

local function readAll(p)
  local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return s
end

function Dev.loadSnapshot(m, dir)
  local blob = readAll(dir .. "/mem.bin")
  local o = 1
  local function take(t, n) for i = 0, n - 1 do t[i] = blob:byte(o + i) end; o = o + n end
  take(m.wram[0], 0x1000)
  for b = 1, 7 do take(m.wram[b], 0x1000) end
  for b = 0, 3 do take(m.sram[b], 0x2000) end
  take(m.vram[0], 0x2000); take(m.vram[1], 0x2000)
  take(m.oam, 0xA0); take(m.io, 0x80)
  local hr = {}; take(hr, 0x80)
  for i = 0, 0x7E do m.hram[i] = hr[i] end
  m.ie = hr[0x7F]
  if #blob >= o + 127 then take(m.bgpal, 64); take(m.obpal, 64) end
  local js = readAll(dir .. "/regs.json")
  local function num(k) return tonumber(js:match('"' .. k .. '": (%d+)')) end
  local cpu = m.cpu
  cpu.a, cpu.f, cpu.b, cpu.c = num("a"), num("f"), num("b"), num("c")
  cpu.d, cpu.e, cpu.h, cpu.l = num("d"), num("e"), num("h"), num("l")
  cpu.sp, cpu.pc = num("sp"), num("pc")
  m.romBank = num("bank"); m.svbk = math.max(1, num("svbk") % 8); m.vbk = num("vbk") % 2
  m.double = m.io[0x4D] >= 128
  m.ly = m.io[0x44]
end

function Dev.run(rom, dir, out, n, every)
  local m = GBC.new(rom)
  Dev.loadSnapshot(m, dir)
  local img = love.image.newImageData(160, 144)
  local t0 = love.timer.getTime()
  for i = 0, n - 1 do
    if not m:frame() then print("quadro " .. i .. ": não chegou ao VBlank (pc " .. string.format("%04X", m.cpu.pc) .. ")") break end
    if i % (every or 2) == 0 then
      m:render(function(x, y, r, g, b) img:setPixel(x, y, r, g, b, 1) end)
      local f = assert(io.open(("%s/emu_%03d.png"):format(out, i / (every or 2)), "wb"))
      f:write(img:encode("png"):getString()); f:close()
    end
  end
  local f = assert(io.open(out .. "/vram.bin", "wb"))
  for b = 0, 1 do for i = 0, 0x1FFF do f:write(string.char(m.vram[b][i])) end end
  f:close()
  for _, y in ipairs({ 0, 50, 95, 100, 111, 112, 120, 143 }) do
    local L = m.lines[y] or {}
    print(("linha %d: lcdc %02X scx %d scy %d wx %d wy %d"):format(y, L.lcdc or -1, L.scx or -1, L.scy or -1, L.wx or -1, L.wy or -1))
  end
  print(("io: lcdc %02X stat %02X lyc %d ie %02X"):format(m.io[0x40], m.io[0x41], m.io[0x45], m.ie))
  print(("%d quadros em %.2fs; pc %04X banco %02X"):format(m.frames, love.timer.getTime() - t0, m.cpu.pc, m.romBank))
end


-- Rastreia as leituras feitas antes de qualquer escrita (entradas da rotina) até ela retornar.
function Dev.trace(rom, dir, out)
  local m = GBC.new(rom)
  Dev.loadSnapshot(m, dir)
  local seenW, inputs = {}, {}
  local rd, wr = m.read, m.write
  local function key(a)
    if a >= 0x8000 and a < 0xA000 then return 0x100000 + m.vbk * 0x10000 + a end
    if a >= 0xA000 and a < 0xC000 then return 0x200000 + (m.ramBank % 4) * 0x10000 + a end
    if a >= 0xD000 and a < 0xE000 then return 0x300000 + m.svbk * 0x10000 + a end
    if (a >= 0xC000 and a < 0xD000) or a >= 0xFF80 then return a end
  end
  m.read = function(self, a)
    local k = key(a)
    if k and not seenW[k] then inputs[k] = true end
    return rd(self, a)
  end
  m.write = function(self, a, v)
    local k = key(a)
    if k then seenW[k] = true end
    return wr(self, a, v)
  end
  local sp0 = m.cpu.sp
  local ret = tonumber(os.getenv("UNTIL") or "", 16) or (m:read(sp0) + m:read(sp0 + 1) * 256)
  local frames = 0
  m.hooks[ret] = function(self)
    if os.getenv("UNTIL") or self.cpu.sp > sp0 then self.stopped = true end
    return false
  end
  local nf = tonumber(os.getenv("NF") or "1500")
  while not m.stopped and frames < nf do m:frame(); frames = frames + 1 end
  local names = { [1] = "V", [2] = "S", [3] = "W" }
  local keys, list = {}, {}
  for k in pairs(inputs) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local kind = math.floor(k / 0x100000)
    local b = math.floor(k / 0x10000) % 16
    list[#list + 1] = kind == 0 and ("%04X"):format(k) or ("%s%d:%04X"):format(names[kind], b, k % 0x10000)
  end
  local f = assert(io.open(out, "w"))
  f:write(table.concat(list, "\n"))
  f:close()
  print(("retornou=%s quadros=%d entradas=%d"):format(tostring(m.stopped), frames, #list))
end


-- Cena montada do zero (sem snapshot), como o motor fará.
function Dev.scene(out, n)
  local Scene = require("src.emu.battlescene")
  local s = Scene.new({
    att = { species = 7, level = 1, hp = 65, maxhp = 65, sp = 40, maxsp = 40, atk = 20, acc = 10, eva = 10, move = 6, x = 26, y = 6 },
    def = { species = 63, level = 1, hp = 55, maxhp = 55, sp = 0, maxsp = 0, atk = 19, acc = 10, eva = 10, move = 4, x = 26, y = 5 },
    hit = true, dmg = 30, counter = { hit = true, dmg = 9 }, stage = 1, terrain = 2,
  })
  local t0 = love.timer.getTime()
  local i = 0
  while s:step() and i < n do
    if i % 10 == 0 then
      local f = assert(io.open(("%s/scene_%03d.png"):format(out, i / 10), "wb"))
      f:write(s.img:encode("png"):getString()); f:close()
    end
    i = i + 1
  end
  print(("cena: %d quadros em %.2fs, acabou=%s"):format(i, love.timer.getTime() - t0, tostring(s.done)))
end

return Dev
