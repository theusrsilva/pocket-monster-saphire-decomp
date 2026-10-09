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
-- Com qualquer opção de teste o progresso vai para save_test.lua, não para o save do jogador.
local Importer = require("src.import.importer")
local Battle = require("src.game.battle")
local View = require("src.ui.view")
local Names = require("src.game.names")
local Campaign = require("src.game.campaign")
local World = require("src.game.world")
local TeamSelect = require("src.game.teamselect")
local campaign, world, teamsel

-- Preferências do jogador (pasta de dados do LÖVE)
local function loadOptions()
  local ok, o = pcall(function() return love.filesystem.load("options.lua")() end)
  if ok and type(o) == "table" and o.names then Names.mode = o.names end
end

local testRun = false

local function saveOptions()
  if testRun then return end                   -- execuções de teste não mudam as preferências
  love.filesystem.write("options.lua", ("return { names = %q }"):format(Names.mode))
end

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
  local assets = { stages = {} }
  for s = 0, 31 do
    assets.stages[s] = love.graphics.newImage(("generated/stage_%02d.png"):format(s))
  end
  assets.units = love.graphics.newImage("generated/units.png")
  assets.portraits = love.graphics.newImage("generated/portraits.png")
  assets.speakers = love.graphics.newImage("generated/speakers.png")
  campaign = Campaign.load(data)
  View.init(assets)
end

local enterStage

local function openWorld()
  world = World.new(data, campaign)
  world.onEnter = function(s)
    teamsel = TeamSelect.new(data, campaign, s)
    state = "team"
  end
  state = "world"
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
  if not f then return nil end
  local b = f:read("*a")
  f:close()
  return b
end

function enterStage(i, team)
  battle = Battle.new(data, i, campaign, team)
  if opts["cheat-move"] then                  -- só para testes: aliados andam muito
    for _, u in ipairs(battle.units) do if u.side == "ally" then u.move = 60 end end
  end
  battle:say("Sua vez. Selecione um Pokémon.")
  state = "battle"
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
  love.keypressed(tok)
  scriptWait = 2
end

---------------------------------------------------------------- callbacks
function love.load(args)
  love.graphics.setDefaultFilter("nearest", "nearest")
  loadOptions()
  parseArgs(args or {})
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
    if opts["new-save"] then love.filesystem.remove(Campaign.FILE) end
  end
  data = Importer.load()
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
  if opts.test ~= nil or hasFlag("--test") then
    if not data then
      local bytes = readFile(opts.rom or (love.filesystem.getSource() .. "/../rom/saphire.gbc"))
      assert(bytes, "ROM não encontrada")
      assert(Importer.run(bytes))
      data = Importer.load()
    end
    local ok = require("src.tests").run(data)
    love.event.quit(ok and 0 or 1)
    return
  end
  if data then
    loadAssets()
    if opts.cleared then for i = 1, tonumber(opts.cleared) do campaign.cleared[i] = true end end
    if opts.keys then for i = 0, tonumber(opts.keys) - 1 do campaign.keyItems[i] = 1 end end
    if opts.node then campaign.node = tonumber(opts.node) end
    openWorld()
    if opts.stage then enterStage(tonumber(opts.stage)) end
  else
    local path = opts.rom or (love.filesystem.getSource() .. "/../rom/saphire.gbc")
    local bytes = readFile(path)
    if bytes then startImport(bytes) else state = "needrom" end
  end
end

function love.filedropped(file)
  file:open("r")
  local bytes = file:read()
  file:close()
  startImport(bytes)
end

function love.update(dt)
  if quitSoon then
    quitSoon = quitSoon - 1
    if quitSoon <= 0 then love.event.quit() end
  end
  if state == "importing" then
    local ok, res, err = coroutine.resume(importCo)
    if not ok then
      importErr, state = tostring(res), "needrom"
    elseif coroutine.status(importCo) == "dead" then
      if res then
        data = Importer.load()
        loadAssets()
        openWorld()
        if opts.stage then enterStage(tonumber(opts.stage)) end
      else
        importErr, state = err, "needrom"
      end
    end
  elseif state == "battle" then
    battle:update(dt)
  elseif state == "world" then
    world:update(dt)
  end
  if #script > 0 or scriptWait > 0 or opts.shot then
    if state == "battle" or state == "world" or state == "team" then runScriptStep() end
  end
end

local KEY = {
  up = "up", w = "up", down = "down", s = "down", left = "left", a = "left", right = "right", d = "right",
  z = "a", ["return"] = "a", space = "a", kpenter = "a",
  x = "b", backspace = "b", escape = "start", tab = "select",
}

function love.keypressed(key)
  local k = KEY[key] or key
  if key == "n" then
    Names.cycle()
    saveOptions()
    if battle then battle:refreshNames() end
    return
  end
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
      if ts.onButton then ts.onButton = false else state = "world" end
    elseif k == "a" then
      local team = ts:confirm()
      if team then enterStage(ts.stage, team) end
    end
  elseif state == "battle" then
    local b = battle
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
      if k == "up" then b:menuMove(-1) elseif k == "down" then b:menuMove(1)
      elseif k == "a" then b:confirm() elseif k == "b" then b:cancel() end
      return
    end
    if b.phase ~= "player" then return end
    if k == "up" then b:moveCursor(0, -1)
    elseif k == "down" then b:moveCursor(0, 1)
    elseif k == "left" then b:moveCursor(-1, 0)
    elseif k == "right" then b:moveCursor(1, 0)
    elseif k == "a" then b:confirm()
    elseif k == "b" then b:cancel()
    elseif k == "start" then b:endPlayerTurn()
    end
  end
end

function love.mousepressed(mx, my, button)
  if state ~= "battle" or not battle.cam then return end
  local b = battle
  if b.result then campaign:save(); openWorld() return end
  if b.mode == "dialog" then
    local l = b.dialogLayout or { shown = 3, total = 1 }
    b:advanceDialog(l.shown, l.total)
    return
  end
  if button == 2 then b:cancel() return end
  if b.mode == "menu" or b.mode == "bonus" then b:confirm() return end
  local x, y = View.cellAt(b, mx, my)
  if b.mode == "target" then
    for i, t in ipairs(b.targets) do
      if t.x == x and t.y == y then b.targetIndex = i; b.cursor.x, b.cursor.y = x, y; b:confirm() end
    end
    return
  end
  if x >= 0 and y >= 0 and x < b.stage.cols and y < b.stage.rows then
    b.cursor.x, b.cursor.y = x, y
    b:confirm()
  end
end

function love.draw()
  local w, h = love.graphics.getDimensions()
  if state == "battle" then
    View.drawBattle(battle)
  elseif state == "world" then
    View.drawWorld(world, data, campaign)
  elseif state == "team" then
    View.drawTeam(teamsel, data)
  else
    love.graphics.clear(0.04, 0.06, 0.16)
    love.graphics.setColor(1, 1, 1)
    local msg
    if state == "importing" then
      msg = "Importando a ROM... " .. importMsg
    else
      msg = "Arraste aqui a sua ROM do Pocket Monster Saphire (versão Fixed, .gbc)."
      if importErr then msg = msg .. "\n\nErro: " .. importErr end
    end
    love.graphics.printf(msg, 40, h / 2 - 30, w - 80, "center")
  end
end
