-- Testes automáticos: love engine --test   (precisa do cache importado)
-- Os valores esperados vêm de observações do jogo original rodando em emulador.
local Path = require("src.game.pathfind")
local Combat = require("src.game.combat")

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

function T.run(data)
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

  print(("\n%d ok, %d falhas"):format(T.passed, T.failed))
  return T.failed == 0
end

return T
