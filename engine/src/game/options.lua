-- Opções do jogador (pasta de dados do LÖVE, options.lua), editadas na tela de configuração.
local serialize = require("src.util.serialize")

local Options = {
  FILE = "options.lua",
  values = {
    lang = "pt",            -- "pt" ou "en" (falas, menus, golpes, lugares, itens)
    names = "oficial",      -- nomes das espécies: "oficial" ou "original" (como no jogo)
    preview = true,         -- prévia de ataque (dano, acerto, contra-ataque)
    ai = "original",        -- IA dos inimigos: "original" ou "melhorada"
    fixHeal = true,         -- corrige o bug da autocura do inimigo passar do HP máximo
    undo = true,            -- desfazer o movimento antes de agir
    anims = true,           -- animações de batalha do jogo original (src/anim)
    enemySpeed = "normal",  -- "normal" ou "rapida"
    sound = true,
    music = true,           -- música (os efeitos continuam com a música desligada)
    log = false,            -- histórico da partida no canto (desligado: só o último aviso, por 3 s)
    volume = 0.5,
    fullscreen = false,
    launcher = true,        -- mostrar a configuração ao abrir (PC)
    romPath = "",
  },
  testRun = false,
}

function Options.get(k) return Options.values[k] end

function Options.set(k, v)
  Options.values[k] = v
end

function Options.load()
  local ok, t = pcall(function() return love.filesystem.load(Options.FILE)() end)
  if ok and type(t) == "table" then
    -- formato antigo: { names = "oficial"/"original", sound = bool }
    if t.names == "original" and t.lang == nil then t.lang = "en" end
    for k, v in pairs(t) do
      if Options.values[k] ~= nil and type(v) == type(Options.values[k]) then Options.values[k] = v end
    end
  end
  return Options.values
end

function Options.save()
  if Options.testRun then return end                  -- execuções de teste não mexem nas preferências
  love.filesystem.write(Options.FILE, serialize(Options.values))
end

-- Aplica nos módulos que dependem das opções.
function Options.apply()
  local v = Options.values
  require("src.game.i18n").lang = v.lang
  require("src.game.names").mode = v.names
  local Sound = require("src.audio.sound")
  Sound.enabled, Sound.volume = v.sound, v.volume
  if Sound.src then Sound.src:setVolume(v.sound and v.volume or 0) end
  Sound.setMusic(v.music)
end

return Options
