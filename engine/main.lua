-- Pocket Monster Saphire - recriação nativa em LÖVE2D (protótipo).
-- O jogador fornece a própria ROM; o importador gera o cache na pasta de dados do LÖVE.
--
-- Linha de comando (útil para desenvolvimento/testes):
--   love engine --rom caminho/saphire.gbc     importa a ROM (se ainda não houver cache)
--   love engine --stage 26                    vai direto para uma fase (sem passar pelo mapa-múndi)
--   love engine --node 9                      põe o cursor do mapa-múndi num nó
--   love engine --script "right z wait10"     injeta entradas (teclas/waitN)
--   love engine --shot saida.png              salva um screenshot ao fim do script e sai
--   love engine --cheat-move 1                (testes) aliados com movimento alto
--   love engine --cheat-win 1                 (testes) vence a fase ao entrar
--   love engine --cleared 5 --keys 2          (testes) fases 1-5 vencidas, itens-chave 0-1
--   love engine --new-save 1                  (testes) começa do zero
--   love engine --dump-text out/falas.txt     (tradução) despeja as falas originais (não vai pro git)
--   love engine --render-music out --ids "16 17" --secs 20   (som) despeja músicas em WAV
--   love engine --audio-rate 11025            taxa do som (padrão 22050; 11025 no 3DS)
-- Com qualquer opção de teste o progresso vai para save_test.lua, não para o save do jogador.
local I18n = require("src.game.i18n")
local T = I18n.T
local Importer = require("src.import.importer")
local Battle = require("src.game.battle")
local View = require("src.ui.view")
local Names = require("src.game.names")
local Campaign = require("src.game.campaign")
local World = require("src.game.world")
local TeamSelect = require("src.game.teamselect")
local Sound = require("src.audio.sound")
local Dual = require("src.ui.dual")
-- LÖVE Potion (3DS/Switch) define love._console; o 3DS tem duas telas.
local CONSOLE = love._console or love._console_name
-- Android/iOS: controle na tela, seletor de arquivo para a ROM, voltar do sistema = B.
local OS = love.system and love.system.getOS and love.system.getOS() or ""
local MOBILE = OS == "Android" or OS == "iOS"
local Pad = require("src.ui.pad")
local Touch = require("src.ui.touch")
local dual = false
local campaign, world, teamsel

local Options = require("src.game.options")
local Launcher = require("src.ui.launcher")
local launcher, fromLauncher

local testRun = false

local function saveOptions() Options.save() end

local state = "boot"
local data, battle = nil, nil
local importCo, importMsg, importErr = nil, "", nil
local opts = {}

local rawArgs = {}
local function hasFlag(f)
  for _, a in ipairs(rawArgs) do if a == f then return true end end
  return false
end

local function parseArgs(args)
  rawArgs = args
  local i = 1
  while i <= #args do
    local a = args[i]
    if a:sub(1, 2) == "--" then
      opts[a:sub(3)] = args[i + 1]
      i = i + 2
    else
      i = i + 1
    end
  end
end

local function loadAssets()
  assetsLoaded = true
  local assets = { stages = {} }
  for s = 0, 31 do
    assets.stages[s] = love.graphics.newImage(("generated/stage_%02d.png"):format(s))
  end
  assets.units = love.graphics.newImage("generated/units.png")
  assets.portraits = love.graphics.newImage("generated/portraits.png")
  assets.speakers = love.graphics.newImage("generated/speakers.png")
  assets.paths = { units = "generated/units.png", portraits = "generated/portraits.png", speakers = "generated/speakers.png" }
  if opts.noshader then View.noShader = true end
  campaign = Campaign.load(data)
  View.init(assets)
  if not testRun and not opts.mute then
    local rate = tonumber(opts["audio-rate"] or "") or (CONSOLE == "3DS" and 11025 or nil)
    Sound.init(data.music and data.music.stage, rate)
  end
end

local enterStage

local function openWorld()
  world = World.new(data, campaign)
  world.onEnter = function(s)
    teamsel = TeamSelect.new(data, campaign, s)
    Sound.music(Sound.TEAM)
    state = "team"
  end
  if not world.intro then Sound.stageMusic_(0) end
  state = "world"
end

-- Abertura e título (src/ui/opening.lua): NOVO JOGO começa uma campanha nova, RECORDES continua.
local opening
local function openOpening(skipIntro)
  local Opening = require("src.ui.opening")
  opening = Opening.new(data, love.filesystem.getInfo(Campaign.FILE) ~= nil, function(choice)
    if choice == "new" then
      campaign = Campaign.new(data)
      campaign.introSeen = true                  -- a história já passou na abertura
      campaign:save()
    end
    opening = nil
    openWorld()
  end, skipIntro)
  state = "opening"
end

local function startImport(bytes)
  importErr = nil
  importCo = coroutine.create(function()
    return Importer.run(bytes, function(msg)
      importMsg = msg
      coroutine.yield()
    end)
  end)
  state = "importing"
end

local function readFile(path)
  local f = io.open(path, "rb")
  if f then
    local b = f:read("*a")
    f:close()
    return b
  end
  -- no console (ou sem a pasta rom/), procura a ROM na pasta de dados do jogo
  for _, p in ipairs({ "saphire.gbc", "rom/saphire.gbc" }) do
    if love.filesystem.getInfo(p) then return love.filesystem.read(p) end
  end
end

local AttackScene = require("src.anim.scene")
local Toolbar = require("src.ui.toolbar")
local scene                                  -- animação de batalha original em andamento
local sceneCanvas

-- Animação de batalha original (reimplementada, src/anim): com o recorte da ROM no cache e a opção
-- ligada. Em execuções com --script fica desligada (a não ser com --anims 1), para os roteiros de
-- teste não esperarem a cena.
local function updateAnimHook()
  Battle.animHook = Options.get("anims") and AttackScene.available()
    and (not opts.script or opts.anims ~= nil) or false
end

local function endScene()
  scene = nil
  if battle then
    battle:finishAnim()
    Sound.current = nil
    Sound.stageMusic_(battle.stageIndex)
  end
end

function enterStage(i, team)
  updateAnimHook()
  battle = Battle.new(data, i, campaign, team)
  if opts["attack-demo"] then                 -- desenvolvimento: aliado encosta no 1º inimigo e ataca
    local a, e = battle:alive("ally")[1], battle:alive("enemy")[tonumber(opts["attack-demo"]) or 1]
    a.x, a.y = e.x, e.y + 1
    if opts.enemy then battle:attack(e, a, nil, true)
    else battle:attack(a, e, opts.skill and battle:skill(tonumber(opts.skill, 16)) or nil, false) end
  end
  Sound.stageMusic_(i)
  if opts["cheat-move"] then                  -- só para testes: aliados andam muito
    for _, u in ipairs(battle.units) do if u.side == "ally" then u.move = 60 end end
  end
  battle:say(T("Sua vez. Selecione um Pokémon."))
  state = "battle"
  local dev = opts["dev-screen"]                -- desenvolvimento: abre uma tela para conferir
  if dev then
    local u = battle:alive("ally")[1]
    if dev == "bonus" then
      battle.pending = { u }
      battle:openBonusIfPending()
    elseif dev == "skills" then
      u.skills = { 0x34, 0x0F, 0x01 }
      battle.selected = u
      battle:openSkillMenu(u)
      battle.mode = "menu"
    elseif dev == "goods" then
      for id = 0, 11 do battle.inventory[id] = id % 3 end
      battle.selected = u
      battle:openGoodsList(u, 0)
      battle.mode = "menu"
    elseif dev == "target" then                -- encosta no 1º inimigo e escolhe o alvo do ataque
      local e = battle:alive("enemy")[1]
      u.x, u.y = e.x, e.y + 1
      battle.selected = u
      battle:chooseTarget(u, nil)
    elseif dev == "reach" then                 -- desenvolvimento: alcance de cada unidade no terminal
      for _, x in ipairs(battle.units) do
        local best = battle:computeReach(x)
        local n = 0
        for _ in pairs(best) do n = n + 1 end
        local cells = {}
        for k in pairs(best) do cells[#cells + 1] = (k % battle.stage.cols) .. "," .. math.floor(k / battle.stage.cols) end
        table.sort(cells)
        print(("%s %s sp%02X lv%d mov%d em %d,%d: %d casas: %s"):format(x.side, x.name, x.species, x.level or 0,
          x.move, x.x, x.y, n, table.concat(cells, " ")))
      end
    elseif dev == "dialog" then
      local list = data.messages[1] or {}
      local m
      for _, k in ipairs({ 18, 19, 20, 15, 33 }) do m = m or list[k] end
      battle:showMessage(m or { pages = { { text = "Teste de fala com acentos: ação, maçã." } } })
    end
  end
  if opts["cheat-win"] then                   -- só para testes: vence a fase na hora
    for _, u in ipairs(battle.units) do if u.side == "enemy" then u.hp = 0 end end
    battle:checkEnd()
  end
end

---------------------------------------------------------------- script de teste
local script, scriptWait = {}, 0
local quitSoon = nil

local function runScriptStep()
  if scriptWait > 0 then scriptWait = scriptWait - 1 return end
  local tok = table.remove(script, 1)
  if not tok then
    if opts.shot then
      local target = opts.shot
      love.graphics.captureScreenshot(function(img)
        local fd = img:encode("png")
        local out = io.open(target, "wb")
        out:write(fd:getString())
        out:close()
        quitSoon = 3
      end)
      opts.shot = nil
    end
    return
  end
  local n = tok:match("^wait(%d+)$")
  if n then scriptWait = tonumber(n) return end
  local cx, cy, cb = tok:match("^click:(%d+),(%d+),?(%d*)$")       -- clique do mouse (testes)
  if cx then
    love.mousemoved(tonumber(cx), tonumber(cy))
    love.mousepressed(tonumber(cx), tonumber(cy), tonumber(cb) or 1)
    scriptWait = 2
    return
  end
  local hx, hy = tok:match("^hover:(%d+),(%d+)$")                  -- mouse parado sobre um ponto (testes)
  if hx then
    love.mousemoved(tonumber(hx), tonumber(hy), 0, 0, false)
    scriptWait = 2
    return
  end
  local pb = tok:match("^pad:(%a+)$")                              -- botão do controle (testes)
  if pb then
    love.gamepadpressed(nil, pb)
    love.gamepadreleased(nil, pb)
    scriptWait = 2
    return
  end
  local tx, ty = tok:match("^touch:(%d+),(%d+)$")                  -- toque na tela (testes, --mobile 1)
  if tx then
    love.touchpressed("t", tonumber(tx), tonumber(ty))
    love.mousepressed(tonumber(tx), tonumber(ty), 1, true)
    love.touchreleased("t")
    scriptWait = 2
    return
  end
  love.keypressed(tok)
  scriptWait = 2
end

---------------------------------------------------------------- configuração (launcher)
local fonts
local pickingRom = false
local assetsLoaded = false

local function openLauncher(msg)
  fonts = fonts or { font = love.graphics.newFont(15), small = love.graphics.newFont(12), big = love.graphics.newFont(24) }
  launcher = Launcher.new({
    hasData = function() return data ~= nil end,
    romInfo = function()
      if data then return T("ROM importada; o cache fica em ") .. love.filesystem.getSaveDirectory() end
      return T("Nenhuma ROM importada ainda. Precisa ser a versão Fixed (SHA-1 9fa7da61...).")
    end,
    loadRom = function(path, file, bytes)
      if bytes then
      elseif file then file:open("r"); bytes = file:read(); file:close() else bytes = readFile(path) end
      if not bytes then return false, T("Não consegui abrir o arquivo: ") .. path end
      love.filesystem.write("saphire.gbc", bytes)   -- cópia para gerar a ROM traduzida depois
      fromLauncher = true
      startImport(bytes)
      return true, T("Importando...")
    end,
    pickRom = MOBILE and function()                 -- seletor de arquivo do Android (tools/love-android.patch)
      pickingRom = true
      return love.system.openURL("saphire-recomp:pickrom")
    end or nil,
    mobile = MOBILE,
    play = function()
      if not assetsLoaded then loadAssets() end
      openOpening()
    end,
    quit = function() love.event.quit() end,
    buildRom = function()
      local src = Options.get("romPath")
      local bytes = src ~= "" and readFile(src) or nil
      if not bytes and love.filesystem.getInfo("saphire.gbc") then bytes = love.filesystem.read("saphire.gbc") end
      if not bytes then return T("Configure a ROM primeiro.") end
      local Rom = require("src.util.rom")
      if Rom.new(bytes):sha1() ~= Rom.SHA1 then return T("ROM diferente da esperada (precisa da versão Fixed).") end
      local ok, out = pcall(require("src.romhack.patcher").build, bytes, { fixHeal = Options.get("fixHeal") })
      if not ok then return T("Erro: ") .. tostring(out) end
      local name = "Pocket Monster Saphire (PT-BR).gbc"
      if src ~= "" then
        local dest = src:gsub("[^/\\]*$", "") .. name
        local f = io.open(dest, "wb")
        if f then
          f:write(out)
          f:close()
          return T("ROM traduzida gerada: ") .. dest
        end
      end
      love.filesystem.write(name, out)
      return T("ROM traduzida gerada: ") .. love.filesystem.getSaveDirectory() .. "/" .. name
    end,
  })
  launcher.msg = msg
  state = "launcher"
end

---------------------------------------------------------------- callbacks
function love.load(args)
  love.graphics.setDefaultFilter("nearest", "nearest")
  Options.load()
  Options.apply()
  parseArgs(args or {})
  if opts.mobile then MOBILE = true end         -- desenvolvimento: simula o celular no PC
  Touch.enabled = MOBILE
  if MOBILE then                                -- celular: sem tela cheia/minimizar na barra
    for i = #Toolbar.items, 1, -1 do
      local id = Toolbar.items[i].id
      if id == "fullscreen" or id == "minimize" then table.remove(Toolbar.items, i) end
    end
  end
  if opts.script or opts.shot then
    -- em execução automática, um erro encerra o processo em vez de parar na tela de erro
    function love.errorhandler(msg)
      io.stderr:write(debug.traceback("Erro: " .. tostring(msg), 3) .. "\n")
      os.exit(1)
    end
  end
  if opts.script then
    for tok in opts.script:gmatch("%S+") do
      local k, rep = tok:match("^(.-)%*(%d+)$")
      if k then for _ = 1, tonumber(rep) do script[#script + 1] = k end else script[#script + 1] = tok end
    end
  end
  -- execuções de teste não mexem no save do jogador
  if opts["cheat-move"] or opts["cheat-win"] or opts.cleared or opts.keys or opts["new-save"] then
    Campaign.FILE = "save_test.lua"
    testRun = true
    Options.testRun = true
    if opts["new-save"] then love.filesystem.remove(Campaign.FILE) end
  end
  dual = opts.dual ~= nil or CONSOLE == "3DS"
  if dual then
    View.W, View.H = Dual.TOP_W, Dual.TOP_H                  -- o mapa ocupa a tela de cima inteira
    Dual.init()
    if not CONSOLE then love.window.setMode(800, 960) end    -- --dual no PC: as duas telas em 2x
  end
  data = Importer.load()
  if opts["render-music"] then               -- desenvolvimento: despeja as músicas em WAV (fora do git)
    local Rom = require("src.util.rom")
    local Music = require("src.import.music")
    local rom = Rom.new(assert(readFile(opts.rom or (love.filesystem.getSource() .. "/../rom/saphire.gbc"))))
    local ids = {}
    for id in (opts.ids or "1"):gmatch("%x+") do ids[#ids + 1] = tonumber(id, 16) end
    if opts.bankscan then
      local used = {}
      for id = 1, 0x1F do
        local m = Music.machine(rom, 22050)
        local rd = m.cpu.read
        m.cpu.read = function(a) if a >= 0x4000 and a < 0x8000 then used[m.bank] = true end return rd(a) end
        m.mem[0xFFF7] = id
        for _ = 1, 3000 do Music.frame(m) end
        local s2 = Music.machine(rom, 22050)
        local rd2 = s2.cpu.read
        s2.cpu.read = function(a) if a >= 0x4000 and a < 0x8000 then used[s2.bank] = true end return rd2(a) end
        s2.mem[0xFFF8] = id
        for _ = 1, 300 do Music.frame(s2) end
      end
      local list = {}
      for b in pairs(used) do list[#list + 1] = ("%02X"):format(b) end
      print("bancos: " .. table.concat(list, " "))
      love.event.quit(0)
      return
    end
    if opts.ramscan then
      local m = Music.machine(rom, 22050)
      local snap = {}
      for a = 0xC000, 0xFFFF do snap[a] = m.mem[a] end
      m.mem[0xFFF7] = ids[1]
      local changed = {}
      for _ = 1, 3000 do
        Music.frame(m)
        for a = 0xC000, 0xFFFF do if m.mem[a] ~= snap[a] then changed[a] = true; snap[a] = m.mem[a] end end
      end
      local list = {}
      for a = 0xC000, 0xFFFF do if changed[a] then list[#list + 1] = ("%04X"):format(a) end end
      print(table.concat(list, " "))
      love.event.quit(0)
      return
    end
    for _, id in ipairs(ids) do
      local t0 = love.timer.getTime()
      local L, R, info = Music.render(rom, id, tonumber(opts.secs or "20"), 22050, opts.sfx ~= nil)
      if not L then print(("música %02X: erro %s"):format(id, R)) else
        local f = assert(io.open(("%s/%s_%02X.wav"):format(opts["render-music"], opts.sfx and "sfx" or "music", id), "wb"))
        f:write(Music.wav(L, R, 22050)); f:close()
        print(("%02X: %.1fs, loop em %s, %d escritas, %.1fs para gerar"):format(id, #L / 22050,
          info.loopStart and ("%.1fs"):format(info.loopStart / 22050) or "-", info.writes, love.timer.getTime() - t0))
      end
    end
    love.event.quit(0)
    return
  end
  if opts["dump-text"] then                  -- desenvolvimento: texto original para traduzir (fora do git)
    if not data then
      assert(Importer.run(assert(readFile(opts.rom or (love.filesystem.getSource() .. "/../rom/saphire.gbc")))))
      data = Importer.load()
    end
    local f = assert(io.open(opts["dump-text"], "w"))
    for _, seg in ipairs(require("src.game.messages").segments(data)) do
      f:write(("## %s  (%s)\n"):format(seg.key, seg.where))
      for i, p in ipairs(seg.pages) do f:write(("%d [%s] %s\n"):format(i, p.speaker and ("%02X"):format(p.speaker) or "--", p.text)) end
      for _, e in ipairs(seg.effects or {}) do
        if e.item then f:write(("  > item %02X %s (pág %d)\n"):format(e.item, require("src.game.items").list[e.item].pt, e.page)) end
        if e.recruit then f:write(("  > entra vaga %d: %s (pág %d)\n"):format(e.recruit, Names.species_name(data.species[e.recruit + 1].species), e.page)) end
        if e.key then f:write(("  > item-chave %d (pág %d)\n"):format(e.key, e.page)) end
      end
    end
    f:close()
    love.event.quit(0)
    return
  end
  if opts["emu-snap"] then                   -- desenvolvimento: executor GBC a partir de um snapshot
    local bytes = assert(readFile(opts.rom or (love.filesystem.getSource() .. "/../rom/saphire.gbc")))
    local Dev = require("src.emu.devtest")
    local ok, err
    if opts.scene then ok, err = pcall(Dev.scene, bytes, opts.out, tonumber(opts.frames or "800"))
    elseif opts.trace then ok, err = pcall(Dev.trace, bytes, opts["emu-snap"], opts.trace)
    else
      ok, err = pcall(Dev.run, bytes, opts["emu-snap"], opts.out or opts["emu-snap"],
        tonumber(opts.frames or "200"), tonumber(opts.every or "2"))
    end
    if not ok then print("erro: " .. tostring(err)) end
    love.event.quit(ok and 0 or 1)
    return
  end
  if opts["build-rom"] then                  -- gera a ROM convertida sem abrir a tela (fora do git)
    local bytes = assert(readFile(opts.rom or (love.filesystem.getSource() .. "/../rom/saphire.gbc")), "ROM não encontrada")
    local out, report = require("src.romhack.patcher").build(bytes, {})
    local f = assert(io.open(opts["build-rom"], "wb"))
    f:write(out)
    f:close()
    print(require("src.util.serialize")(report))
    love.event.quit(0)
    return
  end
  if opts.test ~= nil or hasFlag("--test") then
    local bytes = readFile(opts.rom or (love.filesystem.getSource() .. "/../rom/saphire.gbc"))
    if not data then
      if not bytes then
        print("ROM não encontrada: use --rom caminho/saphire.gbc")
        love.event.quit(1)
        return
      end
      assert(Importer.run(bytes))
      data = Importer.load()
    end
    local ok = require("src.tests").run(data, bytes)
    love.event.quit(ok and 0 or 1)
    return
  end
  if Options.get("fullscreen") and not CONSOLE then pcall(love.window.setFullscreen, true) end
  local automatic = opts.script or opts.shot or opts.stage or opts.node or testRun
  if not CONSOLE and (opts.launcher or (not automatic and (Options.get("launcher") or not data))) then
    openLauncher()
    if not data then                          -- cache ausente ou de versão antiga: reimporta sozinho
      local bytes = Options.get("romPath") ~= "" and readFile(Options.get("romPath")) or nil
      if not bytes and love.filesystem.getInfo("saphire.gbc") then bytes = love.filesystem.read("saphire.gbc") end
      if bytes then fromLauncher = true; startImport(bytes) end
    end
    return
  end
  if data then
    loadAssets()
    if opts.cleared then for i = 1, tonumber(opts.cleared) do campaign.cleared[i] = true end end
    if opts.keys then for i = 0, tonumber(opts.keys) - 1 do campaign.keyItems[i] = 1 end end
    if opts.node then campaign.node = tonumber(opts.node) end
    if automatic and not opts.opening then
      openWorld()
      if opts.stage then enterStage(tonumber(opts.stage)) end
    else
      openOpening()
    end
  else
    local path = opts.rom or (love.filesystem.getSource() .. "/../rom/saphire.gbc")
    local bytes = readFile(path)
    if bytes then startImport(bytes) else state = "needrom" end
  end
end

function love.textinput(t)
  if state == "launcher" then launcher:textinput(t) end
end

function love.filedropped(file)
  if state == "launcher" then launcher:filedropped(file) return end
  file:open("r")
  local bytes = file:read()
  file:close()
  startImport(bytes)
end

-- ROM escolhida no seletor do Android ou aberta com "Abrir com" (o patch do love-android copia o
-- arquivo para a pasta de dados como picked.gbc).
local pickTimer = 0
local function checkPickedRom(dt)
  pickTimer = pickTimer + dt
  if pickTimer < 0.5 then return end
  pickTimer = 0
  if not love.filesystem.getInfo("picked.gbc") then return end
  local bytes = love.filesystem.read("picked.gbc")
  love.filesystem.remove("picked.gbc")
  pickingRom = false
  if not bytes then return end
  if state ~= "launcher" then openLauncher() end
  local ok, msg = launcher.ctx.loadRom("picked.gbc", nil, bytes)
  launcher.msg = msg
end

function love.update(dt)
  Sound.update()
  Pad.update(dt)
  if MOBILE and (state == "launcher" or state == "needrom") then checkPickedRom(dt) end
  if quitSoon then
    quitSoon = quitSoon - 1
    if quitSoon <= 0 then love.event.quit() end
  end
  if state == "importing" then
    local ok, res, err = coroutine.resume(importCo)
    if not ok then
      importErr, state = tostring(res), "needrom"
      if fromLauncher then fromLauncher = false; openLauncher(T("Erro: ") .. importErr) end
    elseif coroutine.status(importCo) == "dead" then
      if res then
        data = Importer.load()
        if fromLauncher then
          fromLauncher = false
          openLauncher(T("ROM importada! Escolha Jogar."))
        else
          loadAssets()
          openWorld()
          if opts.stage then enterStage(tonumber(opts.stage)) end
        end
      else
        importErr, state = err, "needrom"
        if fromLauncher then fromLauncher = false; openLauncher(T("Erro: ") .. tostring(err)) end
      end
    end
  elseif state == "battle" then
    if battle.anim and not scene then
      local ok, sc = pcall(AttackScene.new, battle.anim, function(v) Sound.music(v) end)
      if ok then
        scene = sc
      else
        print("animação de batalha desligada: " .. tostring(sc))
        Battle.animHook = false
        battle:finishAnim()
      end
    end
    if scene then
      -- em roteiros (--script) o tempo não anda: um quadro por atualização
      local ok, alive = pcall(opts.script and scene.step or scene.update, scene, dt)
      if not ok then print("animação de batalha: " .. tostring(alive)) end
      if not ok or not alive then endScene() end
    else
      battle:update(dt)
    end
  elseif state == "world" then
    world:update(dt)
  elseif state == "opening" then
    opening:update(dt)
  end
  if #script > 0 or scriptWait > 0 or opts.shot then
    if state == "battle" or state == "world" or state == "team" or state == "launcher" or state == "opening" then
      runScriptStep()
    end
  end
end

local KEY = {
  up = "up", w = "up", down = "down", s = "down", left = "left", a = "left", right = "right", d = "right",
  z = "a", ["return"] = "a", space = "a", kpenter = "a",
  x = "b", backspace = "b", escape = "start", pause = "start", tab = "select",
}

function love.keypressed(key)
  -- Android: o "voltar" do sistema chega como escape e vale como B (fora da configuração)
  if MOBILE and key == "escape" and state ~= "launcher" then key = "x" end
  local k = KEY[key] or key
  if state == "launcher" then launcher:keypressed(key) return end
  if key == "f1" and not CONSOLE and (state == "world" or state == "team") then openLauncher() return end
  if key == "m" then                          -- música liga/desliga (os efeitos continuam)
    Options.set("music", not Options.get("music"))
    Options.apply()
    saveOptions()
    return
  end
  if key == "f11" and not CONSOLE then
    Options.set("fullscreen", not Options.get("fullscreen"))
    pcall(love.window.setFullscreen, Options.get("fullscreen"))
    saveOptions()
    return
  end
  if key == "n" then
    Options.set("lang", Options.get("lang") == "pt" and "en" or "pt")
    Options.apply()
    saveOptions()
    if battle then battle:refreshNames() end
    return
  end
  if state == "opening" then opening:keypressed(k) return end
  if state == "world" then
    local wd = world
    if key == "delete" and wd.mode == "map" then
      campaign = Campaign.new(data)
      campaign:save()
      openWorld()
      return
    end
    if wd.mode == "dialog" then
      if k == "a" or k == "b" then
        local l = wd.dialogLayout or { shown = 3, total = 1 }
        wd:advanceDialog(l.shown, l.total)
      end
    elseif wd.mode == "menu" then
      if k == "up" then wd:menuMove(-1) elseif k == "down" then wd:menuMove(1)
      elseif k == "a" then wd:confirm() elseif k == "b" then wd:cancel() end
    else
      if k == "up" then wd:move(World.UP) elseif k == "down" then wd:move(World.DOWN)
      elseif k == "left" then wd:move(World.LEFT) elseif k == "right" then wd:move(World.RIGHT)
      elseif k == "a" then wd:confirm() end
    end
  elseif state == "team" then
    local ts = teamsel
    if k == "up" then ts:move(-1) elseif k == "down" then ts:move(1)
    elseif k == "start" then ts:start()
    elseif k == "b" then
      if ts.onButton then ts.onButton = false else state = "world"; Sound.stageMusic_(0) end
    elseif k == "a" then
      local team = ts:confirm()
      if team then enterStage(ts.stage, team) end
    end
  elseif state == "battle" then
    local b = battle
    if scene then                            -- durante a animação: START/B/A pulam a cena
      if k == "start" or k == "b" or k == "a" then endScene() end
      return
    end
    if b.result then
      if k == "a" then campaign:save(); openWorld() end
      return
    end
    if b.mode == "dialog" then
      if k == "a" or k == "b" then
        local l = b.dialogLayout or { shown = 3, total = 1 }
        b:advanceDialog(l.shown, l.total)
      end
      return
    end
    if b.mode == "menu" or b.mode == "bonus" then
      if k == "up" or k == "left" then b:menuMove(-1) elseif k == "down" or k == "right" then b:menuMove(1)
      elseif k == "a" or (k == "start" and b.menu and b.menu.kind == "endturn") then b:confirm()
      elseif k == "b" then b:cancel() end
      return
    end
    if b.phase ~= "player" then return end
    if k == "up" then b:moveCursor(0, -1)
    elseif k == "down" then b:moveCursor(0, 1)
    elseif k == "left" then b:moveCursor(-1, 0)
    elseif k == "right" then b:moveCursor(1, 0)
    elseif k == "a" then b:confirm()
    elseif k == "b" then b:cancel()
    elseif k == "start" then b:askEndTurn()
    end
  end
end

-- Toque na tela de baixo do 3DS: confirma (como o botão A). Android/iOS: controle na tela.
function love.touchpressed(id, x, y)
  if dual and CONSOLE then love.keypressed("z") return end
  if state ~= "launcher" then Touch.pressed(id, x, y) end
end

function love.touchmoved(id, x, y) Touch.moved(id, x, y) end
function love.touchreleased(id) Touch.released(id) end

local function toolbarAction(id)
  if id == "music" then love.keypressed("m")
  elseif id == "fullscreen" then love.keypressed("f11")
  elseif id == "minimize" then pcall(love.window.minimize)
  elseif id == "config" and (state == "world" or state == "team") then openLauncher()
  end
end

-- Mouse no PC: barra de botões, regiões clicáveis das telas (menus, listas, lugares do mapa) e, na
-- batalha, as casas do mapa. Botão direito = voltar; clique durante a animação pula a cena.
function love.mousepressed(mx, my, button, istouch)
  if CONSOLE then return end
  if istouch and state ~= "launcher" and Touch.inside(mx, my) then return end   -- foi no controle na tela
  if not istouch then love.mouse.setVisible(true) end
  if state == "launcher" then launcher:mousepressed(mx, my, button) return end
  if dual then return end
  local tb = Toolbar.hit(mx, my)
  if tb then toolbarAction(tb) return end
  if button == 2 then love.keypressed("x") return end
  if button ~= 1 then return end
  local hit = View.hitAt(mx, my)
  if hit then hit.fn() return end
  if state == "world" and world.mode == "dialog" then love.keypressed("z") return end
  if state ~= "battle" or not battle.cam then return end
  local b = battle
  if scene or b.result or b.mode == "dialog" then love.keypressed("z") return end
  if b.mode == "menu" or b.mode == "bonus" then return end
  local x, y = View.cellAt(b, mx, my)
  if b.mode == "target" then
    for i, t in ipairs(b.targets) do
      if t.x == x and t.y == y then b.targetIndex = i; b.cursor.x, b.cursor.y = x, y; b:confirm() end
    end
    return
  end
  if x >= 0 and y >= 0 and x < b.stage.cols and y < b.stage.rows then
    if b.phase ~= "player" then return end
    if b.cursor.x == x and b.cursor.y == y or b.mode == "move" or b:unitAt(x, y) then
      b.cursor.x, b.cursor.y = x, y
      b:confirm()
    else
      b.cursor.x, b.cursor.y = x, y
    end
  end
end

function love.mousemoved(mx, my, _, _, istouch)
  if CONSOLE then return end
  if not istouch and not MOBILE then love.mouse.setVisible(true) end
  if state == "launcher" then launcher:mousemoved(mx, my) return end
  if dual then return end
  local hit = View.hitAt(mx, my)
  if hit and hit.hover then hit.hover() return end
  -- na batalha, o cursor do mapa acompanha o mouse: o painel mostra a unidade sob o ponteiro e
  -- some numa casa vazia (senão ficava o da última unidade clicada)
  local b = battle
  if state == "battle" and b and b.cam and not scene and not hit and not b.result and b.phase == "player"
      and (b.mode == "cursor" or b.mode == "move") and not istouch and not Toolbar.hit(mx, my) then
    local x, y = View.cellAt(b, mx, my)
    if x >= 0 and y >= 0 and x < b.stage.cols and y < b.stage.rows then
      b.cursor.x, b.cursor.y = x, y
    end
  end
end

function love.wheelmoved(_, dy)
  if CONSOLE or dual then return end
  if state == "launcher" then launcher:wheelmoved(dy) end
end

local function drawMessage(w, h)
  love.graphics.clear(0.04, 0.06, 0.16)
  love.graphics.setColor(1, 1, 1)
  local msg
  if state == "importing" then
    msg = T("Importando a ROM... ") .. importMsg
  else
    msg = CONSOLE and T("Coloque a ROM (saphire.gbc) na pasta de dados do jogo e reinicie.")
      or T("Arraste aqui a sua ROM do Pocket Monster Saphire (versão Fixed, .gbc).")
    if importErr then msg = msg .. T("\n\nErro: ") .. importErr end
  end
  love.graphics.printf(msg, 10, h / 2 - 30, w - 20, "center")
end

-- Uma das telas do modo duplo: "top" (mapa) ou "bottom" (painéis).
local function drawScreen(which)
  if which == "top" then
    View.forced = { Dual.TOP_W, Dual.TOP_H }
    if state == "battle" and scene then
      love.graphics.clear(0, 0, 0)
      local sc = math.min(Dual.TOP_W / 160, Dual.TOP_H / 144)
      scene:draw(math.floor((Dual.TOP_W - 160 * sc) / 2), math.floor((Dual.TOP_H - 144 * sc) / 2), sc)
    elseif state == "battle" then View.drawBattle(battle, true)
    elseif state == "world" then View.drawWorld(world, data, campaign, true)
    elseif state == "team" then Dual.drawTeamTop(teamsel, data)
    elseif state == "opening" then opening:draw(Dual.TOP_W, Dual.TOP_H)
    else drawMessage(Dual.TOP_W, Dual.TOP_H) end
  else
    View.forced = { Dual.BOT_W, Dual.BOT_H }
    if state == "battle" then Dual.drawBattleBottom(battle)
    elseif state == "world" then Dual.drawWorldBottom(world, data, campaign)
    elseif state == "team" then Dual.drawTeamBottom(teamsel, data)
    else love.graphics.clear(0.03, 0.06, 0.2) end
  end
  View.forced = nil
end

function love.draw(screen)
  if dual and CONSOLE then                 -- LÖVE Potion chama love.draw uma vez por tela
    drawScreen(screen == "bottom" and "bottom" or "top")
    return
  end
  if dual then                             -- PC: desenha as duas telas empilhadas, em 2x
    Dual.topCanvas = Dual.topCanvas or love.graphics.newCanvas(Dual.TOP_W, Dual.TOP_H)
    Dual.botCanvas = Dual.botCanvas or love.graphics.newCanvas(Dual.BOT_W, Dual.BOT_H)
    View.target = Dual.topCanvas
    love.graphics.setCanvas(Dual.topCanvas); drawScreen("top")
    View.target = Dual.botCanvas
    love.graphics.setCanvas(Dual.botCanvas); drawScreen("bottom")
    View.target = nil
    love.graphics.setCanvas()
    local w, h = love.graphics.getDimensions()
    local sc = math.max(1, math.floor(math.min(w / Dual.TOP_W, h / (Dual.TOP_H + Dual.BOT_H))))
    love.graphics.clear(0, 0, 0)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(Dual.topCanvas, math.floor((w - Dual.TOP_W * sc) / 2), 0, 0, sc, sc)
    love.graphics.draw(Dual.botCanvas, math.floor((w - Dual.BOT_W * sc) / 2), Dual.TOP_H * sc, 0, sc, sc)
    return
  end
  local w, h = love.graphics.getDimensions()
  View.hits = {}
  if state == "launcher" then launcher:draw(fonts); Pad.drawToast(fonts.font) return end
  if state == "battle" and scene then
    -- a cena (160x144, proporção da tela do Game Boy) ocupa a altura inteira da janela: desenhada
    -- em 1x num canvas e ampliada sem filtro (escala fracionária não deixa emendas entre tiles)
    sceneCanvas = sceneCanvas or love.graphics.newCanvas(160, 144)
    sceneCanvas:setFilter("nearest", "nearest")
    love.graphics.setCanvas(sceneCanvas)
    love.graphics.clear(0, 0, 0)
    scene:draw(0, 0, 1)
    love.graphics.setCanvas()
    love.graphics.clear(0, 0, 0)
    local sc = math.min(w / 160, h / 144)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(sceneCanvas, math.floor((w - 160 * sc) / 2), math.floor((h - 144 * sc) / 2), 0, sc, sc)
  elseif state == "battle" then
    View.drawBattle(battle)
  elseif state == "world" then
    View.drawWorld(world, data, campaign)
  elseif state == "team" then
    View.drawTeam(teamsel, data)
  elseif state == "opening" then
    opening:draw(w, h)
  else
    drawMessage(w, h)
  end
  if state == "battle" or state == "world" or state == "team" or state == "opening" then
    if MOBILE then Toolbar.draw(w - Toolbar.width() - 10, 10, state == "world" or state == "team", View.small)
    else Toolbar.draw(w - Toolbar.width() - 10, h - Toolbar.size - 26, state == "world" or state == "team", View.small) end
    Touch.draw(View.small)
  end
  if View.small then Pad.drawToast(View.small) end
end

-- Controles (DualSense, Xbox... no PC e no Android; botões do 3DS/Switch): src/ui/pad.lua.
function love.gamepadpressed(_, button)
  if not CONSOLE then pcall(love.mouse.setVisible, false) end
  Pad.pressed(button)
end

function love.gamepadreleased(_, button) Pad.released(button) end

function love.joystickadded(j)
  if CONSOLE then return end
  local ok, name = pcall(j.getName, j)
  Pad.notify(T("Controle conectado: ") .. (ok and name or "?"))
end

function love.joystickremoved(j)
  if CONSOLE then return end
  Pad.hold, Pad.stick = nil, nil
  Pad.notify(T("Controle desconectado"))
end
