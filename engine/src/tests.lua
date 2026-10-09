-- Testes automáticos: love engine --test   (precisa do cache importado)
-- Os valores esperados vêm de observações do jogo original rodando em emulador.
local Path = require("src.game.pathfind")
local Combat = require("src.game.combat")
local Campaign = require("src.game.campaign")

local T = { passed = 0, failed = 0 }

local function check(name, cond, detail)
  if cond then
    T.passed = T.passed + 1
    print("ok   " .. name)
  else
    T.failed = T.failed + 1
    print("FAIL " .. name .. (detail and (": " .. detail) or ""))
  end
end

function T.run(data, romBytes)
  -- 1) Espécie 0 (Piku) igual à RAM do jogo ($C900)
  local piku = data.species[1]
  check("piku stats", piku.species == 1 and piku.hp == 80 and piku.sp == 50 and piku.atk == 30
    and piku.acc == 20 and piku.eva == 25 and piku.move == 9)

  -- 2) Alcance de movimento na fase 26: Piku em (6,5) com BoBo (5,4) e Littlecrocodile (5,6).
  --    28 casas observadas no jogo original (inclui as casas ocupadas pelos aliados).
  local st = data.stages[26]
  local expected = {
    "4,3", "5,3", "6,3", "7,3", "8,3", "3,4", "4,4", "5,4", "6,4", "7,4", "8,4", "9,4",
    "4,5", "5,5", "6,5", "7,5", "8,5", "9,5", "10,5", "5,6", "6,6", "7,6", "8,6", "9,6",
    "5,7", "6,7", "7,7", "8,7",
  }
  local unit = { species = 1, move = 9, x = 6, y = 5 }
  local reach = Path.reach(st, data.costs, unit, function() return false end)
  local got = {}
  for k in pairs(reach) do got[(k % st.cols) .. "," .. math.floor(k / st.cols)] = true end
  local missing, extra = {}, {}
  local exp = {}
  for _, c in ipairs(expected) do exp[c] = true; if not got[c] then missing[#missing + 1] = c end end
  for c in pairs(got) do if not exp[c] then extra[#extra + 1] = c end end
  check("alcance do piku = jogo original", #missing == 0 and #extra == 0,
    ("faltando {%s} sobrando {%s}"):format(table.concat(missing, " "), table.concat(extra, " ")))

  -- 3) Inimigos da fase 26 iguais à SRAM do jogo ($B200)
  local e1 = st.enemies[1]
  check("inimigos fase 26", #st.enemies == 12 and e1.species == 0x1C and e1.level == 3 and e1.hp == 67
    and e1.x == 13 and e1.y == 2)
  check("posição inicial 1 da fase 26", st.starts[1].x == 6 and st.starts[1].y == 5)

  -- 4) Fórmulas de combate
  local a = { atk = 30, acc = 20, eva = 25, type = 1, strong = 2, weak = 5, level = 1 }
  local d = { atk = 18, acc = 12, eva = 11, type = 2, strong = 3, weak = 1, level = 2 }
  check("dano forte x1.5", Combat.damage(a, d) == 45)
  check("dano fraco x0.5", Combat.damage(d, a) == 9)
  check("acerto limitado a 100", Combat.hitChance(a, d) == 100)
  check("acerto com desvantagem", Combat.hitChance(d, a) == 100 + 12 - 25 - 20)
  check("exp derrubando nível maior", Combat.exp(a, d, true) == 32)
  check("exp acertando nível menor", Combat.exp(d, a, false) == 1)

  -- 5) Progressão (tabelas $1D:$5814, $01:$6935, $01:$6A4D, $01:$6A5D, $19:$5C14, $19:$5EDA)
  local Progress = require("src.game.progress")
  local P = data.prog
  check("nível máximo por forma", P.maxLevel[1] == 20 and P.maxLevel[2] == 40 and P.maxLevel[3] == 99)
  check("ganho do piku", P.gains[1][1] == 8 and P.gains[1][2] == 5 and P.gains[1][3] == 60)
  local saved = Progress.random
  Progress.random = function() return 1 end           -- 1 < limiar, índice 1 -> ganho da tabela
  local u = { side = "ally", species = 1, level = 1, exp = 90, hp = 10, maxhp = 80, sp = 0, maxsp = 50,
    atk = 30, acc = 20, eva = 25, move = 9, skills = {} }
  local ups = Progress.gainExp(u, 16, P)
  check("subir de nível", #ups == 1 and u.level == 2 and u.exp == 6 and u.maxhp == 88 and u.maxsp == 55
    and u.atk == 31 and u.acc == 21 and u.eva == 26 and u.hp == 88 and u.sp == 55,
    ("nv %d exp %d hp %d/%d sp %d atk %d"):format(u.level, u.exp, u.hp, u.maxhp, u.maxsp, u.atk))
  Progress.random = saved
  local opts = Progress.bonusOptions(P, u)
  check("bônus de nível (estágio 1)", opts[1].amount == 3 and opts[2].amount == 2 and opts[3].amount == 1)
  u.level = 20
  Progress.gainExp(u, 50, P)
  check("nível máximo zera EXP", u.exp == 0 and u.level == 20)
  u.maxhp, u.maxsp, u.atk, u.acc, u.eva = 80, 50, 30, 20, 25
  local learned = Progress.evolve(u, P)
  check("evolução 1->2", u.species == 2 and u.maxhp == 130 and u.maxsp == 100 and u.atk == 50
    and u.acc == 35 and u.eva == 50 and u.move == 11 and learned == nil)
  learned = Progress.evolve(u, P)
  check("evolução 2->3 aprende golpe $4A", u.species == 3 and learned == 0x4A and u.skills[1] == 0x4A)
  check("forma final não evolui", not Progress.canEvolve(u, P))

  -- 6) Golpes ($09:$4D5B)
  local s1, s0c = P.skills[1], P.skills[0x0C]
  check("golpe $01 é cura", s1.heal and s1.power == 150 and s1.cost == 30 and s1.rmax == 2)
  check("golpe $0C", not s0c.heal and s0c.power == 60 and s0c.cost == 30 and s0c.rmin == 1 and s0c.rmax == 2)
  local n = { atk = 30, type = 1, strong = 2, weak = 5 }
  check("dano com golpe = ATK + poder", Combat.damage(n, { type = 3 }, 60) == 90)

  -- 7) Nomes (imagens dos bancos $F9 e $79, transcritas)
  local Names = require("src.game.names")
  local m = Names.mode
  local I18nT = require("src.game.i18n")
  Names.mode = "original"; I18nT.lang = "en"
  check("nome original", Names.species_name(0x10) == "littlecrocodile" and Names.skill_name(0x4A) == "100000 Volt")
  Names.mode = "oficial"; I18nT.lang = "pt"
  check("nome oficial", Names.species_name(0x10) == "Totodile" and Names.skill_name(0x4A) == "100.000 Volts")
  check("sem oficial cai no original", Names.species_name(0x40) == "Qimoly")
  Names.mode = m

  -- 8) Itens ($01:$4ECB)
  local Items = require("src.game.items")
  local w = { hp = 10, maxhp = 80, sp = 0, maxsp = 50, atk = 30, acc = 20, eva = 25, move = 14, type = 1,
    species = 1, side = "ally" }
  Items.list[0x00].use(w)
  check("doce cura até o máximo", w.hp == 80)
  Items.list[0x0B].use(w)
  check("pedra do voo limitada a 15", w.move == 15)
  Items.list[0x06].use(w)
  check("pedra da vida: HP máx +10", w.maxhp == 90 and w.hp == 90)
  check("insígnia do tipo certo evolui", Items.usable(0x0C, w, P) and not Items.usable(0x0D, w, P))

  -- 9) Falas das fases (índice em $5D:$4000, script = fase + $20)
  local M = data.messages
  local heal = M[1][15]
  check("fase 1: centro de cura com a enfermeira", heal and heal.pages[1].speaker == 0x0A
    and heal.pages[1].text:find("CURE") ~= nil)
  local chest = M[1][23]
  check("fase 1: baú dá doce", chest and chest.effects[1] and chest.effects[1].item == 0x00)
  local clear = M[2][33]
  local rec = {}
  for _, e in ipairs(clear and clear.effects or {}) do if e.recruit then rec[#rec + 1] = e.recruit end end
  check("fase 2: vitória dá insígnia e recruta vagas 10 e 6", clear and clear.effects[1].item == 0x0E
    and rec[1] == 10 and rec[2] == 6 and #clear.pages == 3)

  -- 10) Campanha: elenco inicial, recrutamento e serialização (tabelas esparsas)
  local c = Campaign.new(data)
  check("elenco inicial = 6 iniciais", #c:recruited() == 6)
  c:recruit(10)
  c.cleared[2] = true
  local back = loadstring(require("src.util.serialize")(c))()
  check("save ida e volta", back.roster[10].recruited == true and back.cleared[2] == true
    and back.cleared[1] == nil and back.roster[0].species == c.roster[0].species)


  -- 11) Mapa-múndi ($09:$6B7D, $09:$69D8, $01:$547D), conferido no PyBoy:
  --     da Vila Ifleaf ($3A) cima -> ChangPanCity ($21), esquerda -> ChangPanWoods ($22),
  --     direita -> BabyAlliance ($41), baixo -> Instituto ($40); de $21 para cima só com $C4F7 ligado.
  local World = require("src.game.world")
  local W = data.world
  local n26 = W.nodes[26]
  check("mapa: vizinhos da Vila Ifleaf", n26.nb[1] == 1 and n26.nb[2] == 32 and n26.nb[3] == 2 and n26.nb[4] == 33
    and n26.x == 5 and n26.y == 26)
  check("mapa: nó = terreno - $20", data.stages[0].terrain[22 * 32 + 5 + 1] == 0x21
    and W.nodes[1].x == 5 and W.nodes[1].y == 22)
  local cw = Campaign.new(data)
  local wIntro = World.new(data, cw)
  check("jogo novo mostra a introdução (script $20)", wIntro.mode == "dialog" and #wIntro.dialog.pages == 5)
  local wd = World.new(data, cw)
  check("mapa: jogo novo começa no Instituto", cw.node == 32)
  wd:move(World.UP); wd:move(World.UP)
  local blocked = not wd:move(World.UP)
  cw.cleared[1] = true
  check("mapa: sair da fase 1 para cima exige a fase 1 vencida", blocked and wd:move(World.UP) and cw.node == 3)
  check("mapa: fase 9 trancada sem a Pedra da Lua", wd:stageStatus(9) == "trancada" and wd:stageStatus(2) == "aberta"
    and wd:stageStatus(1) == "vencida")
  check("mapa: retratos do prefeito/morador de Ifleaf", W.townSpeakers[26][1] == 0x0D and W.townSpeakers[26][2] == 0x11)
  -- fala $22 da fase 9: E2 testa $C4F1 (Pedra da Lua) e escolhe o ramo
  local Messages = require("src.game.messages")
  local gate = data.messages[9][0x22]
  local NamesE = require("src.game.names")
  local me = NamesE.mode
  require("src.game.i18n").lang = "en"
  local without = Messages.resolve(gate, cw)
  cw.keyItems[0] = 1
  local with = Messages.resolve(gate, cw)
  require("src.game.i18n").lang = "pt"
  check("fala com desvio E2 (item-chave)", gate.cond and gate.cond.addr == 0xC4F1
    and without.pages[1].text:find("MOONSTONE") ~= nil and with.pages[1].text ~= without.pages[1].text)
  check("peek: fase vencida grava o número da fase", cw:peek(0xC4F7) == 1 and cw:peek(0xC4F8) == 0)
  local Names2 = require("src.game.names")
  local m2 = Names2.mode
  require("src.game.i18n").lang = "en"
  check("nome do lugar", Names2.place_name(1) == "ChangPanCity" and Names2.place_name(33) == "BabyAlliance")
  require("src.game.i18n").lang = "pt"
  -- evolução só na BabyAlliance, gastando a insígnia do tipo
  local pk = cw.roster[0]
  cw.inventory[World.badgeFor(pk)] = 1
  local ev, okType, hasPk = wd:evolvable(), true, false
  for _, u in ipairs(ev) do okType = okType and u.type == pk.type; hasPk = hasPk or u == pk end
  check("BabyAlliance: só quem tem a insígnia do tipo pode evoluir", #ev >= 1 and okType and hasPk)


  -- 12) Escolha do time ($10:$42C8, $01:$75C4), conferido no PyBoy na fase 1 (6 recrutados -> 00/06)
  local TeamSelect = require("src.game.teamselect")
  local ct = Campaign.new(data)
  local ts = TeamSelect.new(data, ct, 1)
  check("time: máximo = recrutados (até 10)", ts.max == 6 and ts:count() == 0)
  ts:start()
  check("time: botão sem ninguém marcado não começa", ts:confirm() == nil)
  ts.onButton = false
  ts.cursor = 2; ts:confirm()                      -- marca o BoBo primeiro
  ts.cursor = 1; ts:confirm()                      -- depois o Piku
  ts:start()
  local team = ts:confirm()
  check("time: ordem das vagas, não da marcação", team and #team == 2 and team[1].slot == 0 and team[2] == ts.list[2])
  for i = 1, 20 do ct:recruit(i - 1) end
  local big = TeamSelect.new(data, ct, 1)
  for i = 1, 12 do big:toggle(i) end
  check("time: no máximo 10 com elenco cheio", big.max == 10 and big:count() == 10)
  local Battle = require("src.game.battle")
  local bt = Battle.new(data, 1, ct, team)
  local allies = bt:alive("ally")
  check("time: luta usa só as escolhidas nas posições iniciais", #allies == 2
    and allies[1].x == data.stages[1].starts[1].x and allies[1].y == data.stages[1].starts[1].y)


  -- 13) Eventos do terreno ($01:$4D37) e golpe ensinado pelo terreno $1B ($09:$4C12)
  local b21 = Battle.new(data, 21, Campaign.new(data), {})
  local learner = { side = "ally", species = 0x1C, name = "x", skills = { 0x0C }, x = 27, y = 4, hp = 1, maxhp = 1 }
  b21:triggerEvent(learner)
  check("terreno $1B na fase 21 ensina o golpe $57", learner.skills[2] == 0x57)
  local other = { side = "ally", species = 0x01, name = "y", skills = {}, x = 27, y = 4, hp = 1, maxhp = 1 }
  b21:triggerEvent(other)
  check("terreno $1B não ensina a outras espécies", #other.skills == 0)
  local b1 = Battle.new(data, 1, Campaign.new(data), {})
  local walker = { side = "ally", species = 1, name = "z", skills = {}, x = 3, y = 6, hp = 1, maxhp = 1 }
  check("terreno 16/17 não dispara evento", b1:triggerEvent(walker) == false)


  -- 14) Tradução: todo trecho de fala da campanha tem tradução com o mesmo número de páginas
  local Msg = require("src.game.messages")
  local missing, wrong = {}, {}
  for _, seg in ipairs(Msg.segments(data)) do
    if #seg.pages > 0 then
      local t = Msg.PT[seg.key]
      if not t then missing[#missing + 1] = seg.key
      elseif #t ~= #seg.pages then wrong[#wrong + 1] = ("%s(%d/%d)"):format(seg.key, #t, #seg.pages) end
    end
  end
  check("tradução cobre todas as falas", #missing == 0 and #wrong == 0,
    ("faltando {%s} páginas erradas {%s}"):format(table.concat(missing, " "), table.concat(wrong, " ")))
  local NamesT = require("src.game.names")
  local mt = NamesT.mode
  local I18nM = require("src.game.i18n")
  I18nM.lang = "pt"
  local ptHeal = Msg.resolve(data.messages[1][15], Campaign.new(data))
  I18nM.lang = "en"
  local enHeal = Msg.resolve(data.messages[1][15], Campaign.new(data))
  I18nM.lang = "pt"
  check("idioma alterna fala PT/original", ptHeal.pages[1].text:find("cuidar") ~= nil and enHeal.pages[1].text:find("CURE") ~= nil)


  -- 15) IA original ($01:$6B95), conferida no PyBoy na fase 1: Piku (vaga 0) em (26,11) e BoBo
  --     (vaga 2) em (26,6), fim do turno -> o inimigo 11 vai de (21,13) para (22,11) e o 9 de
  --     (21,12) para (23,12) (anel de raio 4 em volta do Piku); os outros ficam parados.
  local ca = Campaign.new(data)
  local ba = Battle.new(data, 1, ca, { ca.roster[0], ca.roster[2] })
  local before = {}
  for _, u in ipairs(ba.units) do
    if u.side == "ally" then
      if u.slot == 0 then u.x, u.y = 26, 11 else u.x, u.y = 26, 6 end
    else before[u.enemySlot] = { u.x, u.y } end
  end
  ba:endPlayerTurn()
  for _, e in ipairs(ba.queue) do ba:enemyAct(e) end
  local moved, okRest = {}, true
  for _, u in ipairs(ba.units) do
    if u.side == "enemy" then
      if u.enemySlot == 11 or u.enemySlot == 9 then moved[u.enemySlot] = { u.x, u.y }
      elseif u.x ~= before[u.enemySlot][1] or u.y ~= before[u.enemySlot][2] then okRest = false end
    end
  end
  check("IA: inimigos 11 e 9 se aproximam como no original", moved[11] and moved[11][1] == 22 and moved[11][2] == 11
    and moved[9] and moved[9][1] == 23 and moved[9][2] == 12 and okRest,
    ("11=(%s) 9=(%s)"):format(moved[11] and table.concat(moved[11], ",") or "-", moved[9] and table.concat(moved[9], ",") or "-"))
  -- ataque de quem está colado e chefe (vaga 0) parado
  local cb = Campaign.new(data)
  local bb = Battle.new(data, 1, cb, { cb.roster[0] })
  local hero = bb:alive("ally")[1]
  local boss
  for _, u in ipairs(bb.units) do if u.enemySlot == 0 then boss = u end end
  hero.x, hero.y = boss.x + 1, boss.y
  hero.level = 99                                   -- sem subir de nível no contra-ataque
  local savedRandom = Combat.random
  Combat.random = function() return 99 end
  local hp0 = hero.hp
  local bx, by = boss.x, boss.y
  bb:enemyAct(boss)
  Combat.random = savedRandom
  check("IA: chefe ataca quem está colado e não anda", hero.hp < hp0 and boss.x == bx and boss.y == by,
    ("hp %d->%d boss %d,%d hero %d,%d skill %s"):format(hp0, hero.hp, boss.x, boss.y, hero.x, hero.y, tostring(boss.skills[1])))
  check("IA: anel de raio 1 = cima, direita, esquerda, baixo", data.ai.rings[1][1].dy == -1 and data.ai.rings[1][2].dx == 1
    and data.ai.rings[1][3].dx == -1 and data.ai.rings[1][4].dy == 1)


  -- 16) Acerto, sorteio e contra-ataque exatos ($01:$6542/$65AC/$6616, $38:$73C4, $09:$6842)
  local weakA = { acc = 30, eva = 0, type = 1, strong = 2, weak = 3 }
  check("acerto: fraco com base acima de 100 fica 100", Combat.hitChance(weakA, { eva = 10, type = 3 }) == 100)
  check("acerto: fraco com base < 32 vira 0", Combat.hitChance(weakA, { eva = 105, type = 3 }) == 0)
  check("acerto: forte com base >= 80 vira 100", Combat.hitChance(weakA, { eva = 45, type = 2 }) == 100)
  local sr = Combat.random
  local neutral = { acc = 0, type = 1, strong = 9, weak = 9 }
  Combat.random = function() return 30 end
  local h30 = Combat.rollHit(neutral, { eva = 30, type = 1 })
  Combat.random = function() return 31 end
  local h31 = Combat.rollHit(neutral, { eva = 30, type = 1 })
  Combat.random = function() return 0 end
  local h19 = Combat.rollHit(neutral, { eva = 19, type = 1 })
  Combat.random = sr
  check("sorteio: acerta só com aleatório maior que o erro; erro < 20 sempre acerta", h30 == false and h31 == true and h19 == true)
  Combat.skills = data.prog.skills
  local atk1 = { x = 0, y = 0, rmin = 1, rmax = 1, hp = 10 }
  local withSkill = { x = 1, y = 0, hp = 10, skills = { 0x0C } }          -- $0C: alcance 1-2
  local plain = { x = 2, y = 0, hp = 10, skills = {} }
  local c1 = Combat.counterFor(atk1, withSkill, nil)
  check("contra: defensor usa golpe de ataque que cobre o alcance do atacante", type(c1) == "table" and c1.id == 0x0C)
  local far = { x = 0, y = 0, rmin = 2, rmax = 3, hp = 10 }
  check("contra: sem golpe, só a distância 1", Combat.counterFor(far, plain, nil) == nil
    and Combat.counterFor(atk1, { x = 1, y = 0, hp = 5, skills = {} }, nil) == "normal")
  check("contra: golpe que não cobre o alcance do atacante não serve", Combat.counterFor(far, { x = 2, y = 0, hp = 5, skills = { 0x0C } }, nil) == nil)
  check("contra: ataque da IA sempre recebe contra normal", Combat.counterFor(far, withSkill, nil, true) == "normal")


  -- 17) Paleta dos retratos = paleta 4 de BG da fase (lida no PyBoy: ff7f df02 3a01 2804)
  local pp = data.stages[1].portraitPal
  check("paleta dos retratos", pp and pp[1][1] == 1 and pp[2][1] == 1 and math.abs(pp[2][2] - 22 / 31) < 1e-6
    and pp[2][3] == 0 and math.abs(pp[4][1] - 8 / 31) < 1e-6)


  -- 18) Som: o driver original ($2C) roda a partir do cache (bancos $00 e $2C) e toca a música
  --     da abertura ($0B, a mesma que o jogo toca no quadro 86 no PyBoy)
  local SoundT = require("src.audio.sound")
  local MusicT = require("src.import.music")
  local bin = love.filesystem.read("generated/sound.bin")
  local okSnd, mm = pcall(MusicT.machine, SoundT.shim(bin or ""), 22050)
  local L, R = {}, {}
  if okSnd then
    mm.mem[0xFFF7] = 0x0B
    for _ = 1, 240 do MusicT.frame(mm); mm.apu:render(369, L, R) end
  end
  local peak = 0
  for i = 1, #L do peak = math.max(peak, math.abs(L[i])) end
  check("som: driver original ao vivo toca a abertura", okSnd and mm.writes > 50 and peak > 0.05,
    okSnd and ("%d escritas, pico %.2f"):format(mm.writes, peak) or tostring(mm))
  check("música de cada fase ($00:$2C85)", data.music.stage[0] == 0x16 and data.music.stage[1] == 0x17)


  -- 19) Idioma da interface e IA melhorada (opções da tela de configuração)
  local I18nU = require("src.game.i18n")
  I18nU.lang = "en"
  local enOk = I18nU.T("Atacar") == "Attack" and I18nU.T("Sua vez") == "Your turn"
  I18nU.lang = "pt"
  check("interface em inglês", enOk and I18nU.T("Atacar") == "Atacar")
  local OptionsT = require("src.game.options")
  local savedAi = OptionsT.get("ai")
  OptionsT.set("ai", "melhorada")
  local cp = Campaign.new(data)
  local bp = Battle.new(data, 1, cp, { cp.roster[0], cp.roster[2] })
  local weakA, strongA = bp:alive("ally")[1], bp:alive("ally")[2]
  local foe
  for _, u in ipairs(bp.units) do if u.enemySlot == 11 then foe = u end end
  weakA.x, weakA.y, weakA.hp = foe.x + 2, foe.y, 1      -- alcançável e com 1 de HP
  strongA.x, strongA.y = foe.x - 2, foe.y
  local sr2 = Combat.random
  Combat.random = function() return 99 end
  bp:enemyAct(foe)
  Combat.random = sr2
  OptionsT.set("ai", savedAi)
  check("IA melhorada derruba o alvo que pode derrubar", weakA.hp == 0)


  -- 20) Conversor de ROM (src/romhack): falas em PT, acentos, cura limitada, checksum
  if romBytes then
    local Dialogs = require("src.romhack.dialogs")
    local Patcher = require("src.romhack.patcher")
    local Buffer = require("src.romhack.buffer")
    local w = Dialogs.wrap(Dialogs.encode("Você ganhou Pão de mel!"), 12)
    local str = string.char(unpack(w))
    check("quebra por palavra na caixa de 12 colunas", str == "VOCf GANHOU PdO DE MEL!", str)
    local out, rep = Patcher.build(romBytes, {})
    local R = Buffer.new(out)
    check("ROM: nomes em imagem redesenhados (golpes, espécies, lugares, itens, ginásios)",
      #rep.images.falhas == 0 and rep.images.golpes == 88 and rep.images["espécies"] == 75
      and rep.images.lugares == 33, table.concat(rep.images.falhas, "; "))
    check("ROM: palavras dos menus redesenhadas (batalha, mapa, time, cidades)", rep.menus and #rep.menus == #require("src.romhack.menus").SCREENS)
    check("ROM: título (NOVO JOGO/RECORDES, CARREGAR/SAIR) redesenhado", rep.title == 4)
    local lay = require("src.romhack.images").layout("Canção de Ninar", 56, 16)
    check("nome longo vai em duas linhas de versalete", lay and #lay == 2 and lay[1].font == "small")
    local sum = 0
    for i = 1, #out, 4096 do
      for _, v in ipairs({ out:byte(i, math.min(i + 4095, #out)) }) do sum = sum + v end
    end
    sum = (sum - out:byte(0x14F) - out:byte(0x150)) % 0x10000
    check("checksum global da ROM convertida", sum == R:u16(0x14E) % 256 * 256 + math.floor(R:u16(0x14E) / 256))
    -- fase 1, mensagem 18 (script $21): fala do menino que dá o Pão, reapontada para um banco novo
    local e = Buffer.at(0x5D, R:u16(Buffer.at(0x5D, 0x4000) + 0x21 * 2)) + 18 * 4
    local bank, addr = R:u8(e + 2), R:u16(e)
    local txt = {}
    for i = 0, 40 do
      local c = R:u8(Buffer.at(bank, addr) + i)
      if c < 0xE0 then txt[#txt + 1] = string.char(c) end
    end
    txt = table.concat(txt)
    check("fala da fase 1 em português na ROM", bank ~= 0x5D and txt:find("A MAMdE +ACABOU DE ME") ~= nil, txt)
    -- cura do inimigo: HP += $18:$697B[golpe] limitado ao HP máx (antes passava do máximo)
    local CPU = require("src.util.sm83")
    local ram = {}
    local cpu = CPU.new(function(a)
      if a < 0x4000 then return R:u8(a) end
      if a < 0x8000 then return R:u8(Buffer.at(0x18, a)) end
      return ram[a] or 0
    end, function(a, v) ram[a] = v end)
    local function heal(hp, max, add)
      ram[0xC98E], ram[0xC98F], ram[0xC992], ram[0xC993] = hp % 256, math.floor(hp / 256), max % 256, math.floor(max / 256)
      cpu.h, cpu.l, cpu.b, cpu.c = math.floor(hp / 256), hp % 256, math.floor(add / 256), add % 256
      cpu:call(R:u16(Buffer.at(0x18, 0x6969)))
      return ram[0xC98E] + ram[0xC98F] * 256
    end
    local table697B = R:u16(Buffer.at(0x18, 0x697B) + 2 * 2)
    check("ROM: autocura limitada ao HP máximo", R:u8(Buffer.at(0x18, 0x6968)) == 0xCD and table697B == 300
      and heal(100, 1000, 300) == 400 and heal(900, 1000, 300) == 1000 and heal(1000, 1000, 150) == 1000
      and heal(250, 260, 800) == 260)
  end

  print(("\n%d ok, %d falhas"):format(T.passed, T.failed))
  return T.failed == 0
end

return T
