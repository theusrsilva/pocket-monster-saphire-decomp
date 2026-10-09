-- Nomes. No jogo original eles são IMAGENS (espécies: banco $F9, golpes: banco $79, carregador
-- ROM0:$300B). Aqui estão transcritos para permitir tradução:
--   en       = como aparece no jogo (a "tradução" original do bootleg, mantida como está)
--   official = nome oficial do Pokémon (só quando confirmado pelo retrato; igual em PT-BR).
--              Sem confirmação: $40, $43, $47, $48, $4A
--   pt       = tradução dos golpes para português
local Names = {}

Names.species = {
  [0x01] = { en = "piku", official = "Pichu" },
  [0x02] = { en = "pikachu", official = "Pikachu" },
  [0x03] = { en = "Leichu", official = "Raichu" },
  [0x04] = { en = "Dollysheep", official = "Mareep" },
  [0x05] = { en = "Mymy", official = "Flaaffy" },
  [0x06] = { en = "Thunderdragon", official = "Ampharos" },
  [0x07] = { en = "BoBo", official = "Pidgey" },
  [0x08] = { en = "Bibitortoise", official = "Pidgeotto" },
  [0x09] = { en = "Bydiao", official = "Pidgeot" },
  [0x0A] = { en = "Mini Dragon", official = "Dratini" },
  [0x0B] = { en = "Hakedragon", official = "Dragonair" },
  [0x0C] = { en = "Arrowdragon", official = "Dragonite" },
  [0x0D] = { en = "Sukalo", official = "Mudkip" },
  [0x0E] = { en = "Lumalo", official = "Marshtomp" },
  [0x0F] = { en = "Lagelo", official = "Swampert" },
  [0x10] = { en = "littlecrocodile", official = "Totodile" },
  [0x11] = { en = "Bluecrocodile", official = "Croconaw" },
  [0x12] = { en = "Strongbear", official = "Feraligatr" },
  [0x13] = { en = "Frogseed", official = "Bulbasaur" },
  [0x14] = { en = "Frog grass", official = "Ivysaur" },
  [0x15] = { en = "Frog flower", official = "Venusaur" },
  [0x16] = { en = "Mumleaf", official = "Chikorita" },
  [0x17] = { en = "Moondrug", official = "Bayleef" },
  [0x18] = { en = "Big mum", official = "Meganium" },
  [0x19] = { en = "Strongwrist", official = "Machop" },
  [0x1A] = { en = "Force", official = "Machoke" },
  [0x1B] = { en = "oddpower", official = "Machamp" },
  [0x1C] = { en = "Yacamo", official = "Torchic" },
  [0x1D] = { en = "Basamo", official = "Blaziken" },
  [0x1E] = { en = "littlefiredragon", official = "Charmander" },
  [0x1F] = { en = "Firedragon", official = "Charmeleon" },
  [0x20] = { en = "Firedragon", official = "Charizard" },
  [0x21] = { en = "Fireballrat", official = "Cyndaquil" },
  [0x22] = { en = "Flamesrat", official = "Quilava" },
  [0x23] = { en = "artilleryrat", official = "Typhlosion" },
  [0x24] = { en = "Kaicy", official = "Abra" },
  [0x25] = { en = "Yochila", official = "Kadabra" },
  [0x26] = { en = "Hudy", official = "Alakazam" },
  [0x27] = { en = "real baby", official = "Wynaut" },
  [0x28] = { en = "realFather", official = "Wobbuffet" },
  [0x29] = { en = "BaBy D", official = "Igglybuff" },
  [0x2A] = { en = "Fat D", official = "Jigglypuff" },
  [0x2B] = { en = "Butter D", official = "Wigglytuff" },
  [0x2C] = { en = "lucky egg", official = "Chansey" },
  [0x2D] = { en = "haapy egg", official = "Blissey" },
  [0x2E] = { en = "Big Rock", official = "Onix" },
  [0x2F] = { en = "Steeldragon", official = "Steelix" },
  [0x30] = { en = "amorrhinocer", official = "Rhyhorn" },
  [0x31] = { en = "armordigimon", official = "Rhydon" },
  [0x32] = { en = "Giststone", official = "Geodude" },
  [0x33] = { en = "LoLoRock", official = "Graveler" },
  [0x34] = { en = "LoLorock", official = "Golem" },
  [0x35] = { en = "Yukila", official = "Larvitar" },
  [0x36] = { en = "Sakola", official = "Pupitar" },
  [0x37] = { en = "Bankila", official = "Tyranitar" },
  [0x38] = { en = "Piliba", official = "Pelipper" },
  [0x39] = { en = "Latias", official = "Latias" },
  [0x3A] = { en = "Lokia", official = "Lugia" },
  [0x3B] = { en = "Lulili", official = "Azurill" },
  [0x3C] = { en = "Outstanding nuntortoise", official = "Squirtle" },
  [0x3D] = { en = "Darkwave", official = "Wooper" },
  [0x3E] = { en = "WaterGod", official = "Suicune" },
  [0x3F] = { en = "Mushroom moster", official = "Shroomish" },
  [0x40] = { en = "Qimoly" },
  [0x41] = { en = "Walkgrass", official = "Oddish" },
  [0x42] = { en = "Dailuby", official = "Houndour" },
  [0x43] = { en = "Baerla" },
  [0x44] = { en = "Monkey monster", official = "Mankey" },
  [0x45] = { en = "Firebomb monkey", official = "Primeape" },
  [0x46] = { en = "Phoenix", official = "Ho-Oh" },
  [0x47] = { en = "Yumawalu" },
  [0x48] = { en = "Shadow dragon" },
  [0x49] = { en = "Super dreamer", official = "Mewtwo" },
  [0x4A] = { en = "Buly" },
  [0x4B] = { en = "Changer monster", official = "Ditto" },
}

Names.skills = {
  [0x01] = { en = "Sing", pt = "Canto" },
  [0x02] = { en = "Kiss of angel", pt = "Beijo de Anjo" },
  [0x03] = { en = "Nutritionegg", pt = "Ovo Nutritivo" },
  [0x04] = { en = "Cradlesong", pt = "Canção de Ninar" },
  [0x05] = { en = "Tongue", pt = "Lambida" },
  [0x06] = { en = "Rescue song", pt = "Canção de Resgate" },
  [0x07] = { en = "Densefog", pt = "Névoa Densa" },
  [0x08] = { en = "White fog", pt = "Névoa Branca" },
  [0x09] = { en = "Phylactery", pt = "Amuleto" },
  [0x0A] = { en = "Selfrecover", pt = "Recuperação" },
  [0x0B] = { en = "Holy light", pt = "Luz Sagrada" },
  [0x0C] = { en = "Electromagnetic", pt = "Onda Eletromagnética" },
  [0x0D] = { en = "twinklingmove", pt = "Passo Cintilante" },
  [0x0E] = { en = "Whip", pt = "Chicote" },
  [0x0F] = { en = "Fallen leave Fly knife", pt = "Folha Navalha" },
  [0x10] = { en = "Death ray", pt = "Raio Mortal" },
  [0x11] = { en = "Spirit force", pt = "Força Espiritual" },
  [0x12] = { en = "Superspeedstar", pt = "Estrela Veloz" },
  [0x13] = { en = "Foam ray", pt = "Raio de Espuma" },
  [0x14] = { en = "Waterrifle", pt = "Rifle d'Água" },
  [0x15] = { en = "Quick knife", pt = "Lâmina Rápida" },
  [0x16] = { en = "Land split attack", pt = "Fenda na Terra" },
  [0x17] = { en = "Mirage light", pt = "Luz Miragem" },
  [0x18] = { en = "Pray rain", pt = "Prece da Chuva" },
  [0x19] = { en = "Watercannom", pt = "Canhão d'Água" },
  [0x1A] = { en = "Jet flame", pt = "Jato de Chamas" },
  [0x1B] = { en = "Sunlight", pt = "Raio Solar" },
  [0x1C] = { en = "Earthquake", pt = "Terremoto" },
  [0x1D] = { en = "lightningflash", pt = "Relâmpago" },
  [0x1E] = { en = "Mirrorflash", pt = "Clarão Espelhado" },
  [0x1F] = { en = "Egg bomb", pt = "Bomba de Ovo" },
  [0x20] = { en = "Floatspore", pt = "Esporos" },
  [0x21] = { en = "Pao Pao", pt = "Bolhas" },
  [0x22] = { en = "littlecyclonewind", pt = "Mini Ciclone" },
  [0x23] = { en = "WaterNeedle", pt = "Agulha d'Água" },
  [0x24] = { en = "Waterarrow", pt = "Flecha d'Água" },
  [0x25] = { en = "The dance of leaf", pt = "Dança das Folhas" },
  [0x26] = { en = "HotPower fieryball", pt = "Bola de Fogo" },
  [0x27] = { en = "Vigour rushwave", pt = "Onda Vigorosa" },
  [0x28] = { en = "Supersonicwave", pt = "Supersônico" },
  [0x29] = { en = "Freezeurgently light", pt = "Raio Congelante" },
  [0x2A] = { en = "Snowstorm", pt = "Nevasca" },
  [0x2B] = { en = "Mysterious phantom", pt = "Fantasma Misterioso" },
  [0x2C] = { en = "Strongstorm", pt = "Tempestade" },
  [0x2D] = { en = "Sacredflame", pt = "Chama Sagrada" },
  [0x2E] = { en = "Pound", pt = "Pancada" },
  [0x2F] = { en = "Spark", pt = "Faísca" },
  [0x30] = { en = "Anglebump against", pt = "Chifrada" },
  [0x31] = { en = "Roll stone", pt = "Rolar Pedras" },
  [0x32] = { en = "Bite", pt = "Mordida" },
  [0x33] = { en = "Counter boxing", pt = "Contragolpe" },
  [0x34] = { en = "Electric shock", pt = "Choque Elétrico" },
  [0x35] = { en = "Wag Tail", pt = "Abanar a Cauda" },
  [0x36] = { en = "Handknife", pt = "Golpe de Caratê" },
  [0x37] = { en = "Smallflame", pt = "Brasa" },
  [0x38] = { en = "Flames car", pt = "Roda de Fogo" },
  [0x39] = { en = "Last bump", pt = "Investida Final" },
  [0x3A] = { en = "Crazily and disorderly peck", pt = "Bicadas Frenéticas" },
  [0x3B] = { en = "Rockslide", pt = "Deslizamento" },
  [0x3C] = { en = "Tread on", pt = "Pisotear" },
  [0x3D] = { en = "Roll", pt = "Rolagem" },
  [0x3E] = { en = "Flysandfoot", pt = "Areia nos Olhos" },
  [0x3F] = { en = "Mirror overcoat", pt = "Manto Espelhado" },
  [0x40] = { en = "Interlink wreath palm", pt = "Palma Encadeada" },
  [0x41] = { en = "Thunder", pt = "Trovão" },
  [0x42] = { en = "Rage of dragon", pt = "Fúria do Dragão" },
  [0x43] = { en = "Smoothwall", pt = "Muralha Lisa" },
  [0x44] = { en = "Cross to stab", pt = "Estocada Cruzada" },
  [0x45] = { en = "Knockdozen", pt = "Socos em Série" },
  [0x46] = { en = "Wild attack", pt = "Ataque Selvagem" },
  [0x47] = { en = "Explode", pt = "Explosão" },
  [0x48] = { en = "Super speed pound", pt = "Pancada Veloz" },
  [0x49] = { en = "Counterattack", pt = "Contra-ataque" },
  [0x4A] = { en = "100000 Volt", pt = "100.000 Volts" },
  [0x4B] = { en = "Flame eddy", pt = "Redemoinho de Fogo" },
  [0x4C] = { en = "Sunlight strong flame", pt = "Chama Solar" },
  [0x4D] = { en = "Hell roll", pt = "Rolagem Infernal" },
  [0x4E] = { en = "Dash around madly", pt = "Disparada" },
  [0x4F] = { en = "Bite into bit", pt = "Mordida Dupla" },
  [0x50] = { en = "Olny angle diamond", pt = "Chifre de Diamante" },
  [0x51] = { en = "Sandstorm", pt = "Tempestade de Areia" },
  [0x52] = { en = "Countrary scale", pt = "Escama Reversa" },
  [0x53] = { en = "phantomskill", pt = "Técnica Fantasma" },
  [0x54] = { en = "Fiercebump against", pt = "Investida Feroz" },
  [0x55] = { en = "Chain fish", pt = "Corrente" },
  [0x56] = { en = "Changebody", pt = "Transformação" },
  [0x57] = { en = "Flame fist", pt = "Soco de Fogo" },
  [0x58] = { en = "Crossattack", pt = "Ataque Cruzado" },
}

-- Lugares do mapa-múndi (imagens 9x2 tiles em $7C:$4000; id da imagem = nó - 1, nó = terreno - $20)
Names.places = {
  [0x01] = { en = "ChangPanCity", pt = "Cidade ChangPan" },
  [0x02] = { en = "ChangPanWoods", pt = "Bosque ChangPan" },
  [0x03] = { en = "Niby City", pt = "Cidade Niby" },
  [0x04] = { en = "JiegengCity", pt = "Cidade Jiegeng" },
  [0x05] = { en = "MoonMountain", pt = "Monte da Lua" },
  [0x06] = { en = "WitheredleafCity", pt = "Cidade Folha Seca" },
  [0x07] = { en = "Astana relic", pt = "Ruínas de Astana" },
  [0x08] = { en = "The rathole", pt = "A Toca do Rato" },
  [0x09] = { en = "Capecabin", pt = "Cabana do Cabo" },
  [0x0A] = { en = "ThepinkCity", pt = "Cidade Rosa" },
  [0x0B] = { en = "RainbowCity", pt = "Cidade Arco-Íris" },
  [0x0C] = { en = "Gold City", pt = "Cidade Dourada" },
  [0x0D] = { en = "Flowerhole", pt = "Gruta das Flores" },
  [0x0E] = { en = "FlowerbasketCity", pt = "Cidade Cesta de Flores" },
  [0x0F] = { en = "Unmanpowerplant", pt = "Usina Abandonada" },
  [0x10] = { en = "Combustiontower", pt = "Torre da Combustão" },
  [0x11] = { en = "Quartzplateau", pt = "Planalto de Quartzo" },
  [0x12] = { en = "TheGeminiIsland", pt = "Ilha Gêmeos" },
  [0x13] = { en = "ThewindCity", pt = "Cidade do Vento" },
  [0x14] = { en = "TheRocktunnel", pt = "Túnel de Pedra" },
  [0x15] = { en = "redlotus island", pt = "Ilha Lótus Vermelho" },
  [0x16] = { en = "Thedragoncave", pt = "Caverna do Dragão" },
  [0x17] = { en = "Magicalbabytower", pt = "Torre dos Pokémon" },
  [0x18] = { en = "turbinationisland", pt = "Ilha do Redemoinho" },
  [0x19] = { en = "Thebelltower", pt = "Torre do Sino" },
  [0x1A] = { en = "Ifleaf town", pt = "Vila Ifleaf" },
  [0x1B] = { en = "Wild town", pt = "Vila Selvagem" },
  [0x1C] = { en = "Cypress town", pt = "Vila Cipreste" },
  [0x1D] = { en = "New town", pt = "Vila Nova" },
  [0x1E] = { en = "Red lotus town", pt = "Vila Lótus Vermelho" },
  [0x1F] = { en = "Clove town", pt = "Vila Cravo" },
  [0x20] = { en = "Doctorinstitute", pt = "Instituto do Doutor" },
  [0x21] = { en = "BabyAlliance", pt = "Aliança Pokémon" },
}

-- Itens-chave da história ($C4F1 + id; imagens 7x2 em $7C:$40A8)
Names.keyItems = {
  [0] = { en = "Moon Stone", pt = "Pedra da Lua" },
  [1] = { en = "The pass", pt = "Passe" },
  [2] = { en = "Miraculous flute", pt = "Flauta Milagrosa" },
  [3] = { en = "Red squama", pt = "Escama Vermelha" },
  [4] = { en = "Dragon tooth", pt = "Dente de Dragão" },
  [5] = { en = "Rainbow feather", pt = "Pena Arco-Íris" },
}

-- Modo de nomes: "oficial" (nomes oficiais + golpes em PT) ou "original" (como no jogo).
Names.mode = "oficial"
Names.MODES = { "oficial", "original" }

function Names.species_name(id)
  local n = Names.species[id]
  if not n then return ("#%02X"):format(id) end
  if Names.mode == "oficial" and n.official then return n.official end
  return n.en
end

function Names.skill_name(id)
  local n = Names.skills[id]
  if not n then return ("Golpe #%02X"):format(id) end
  return Names.mode == "oficial" and n.pt or n.en
end

function Names.place_name(node)
  local n = Names.places[node]
  if not n then return ("Lugar #%02X"):format(node) end
  return Names.mode == "oficial" and n.pt or n.en
end

function Names.key_item_name(id)
  local n = Names.keyItems[id]
  if not n then return ("Item-chave #%d"):format(id) end
  return Names.mode == "oficial" and n.pt or n.en
end

function Names.cycle()
  Names.mode = Names.mode == "oficial" and "original" or "oficial"
  return Names.mode
end

-- Compatibilidade: require("src.game.names")(id) devolve o nome da espécie.
return setmetatable(Names, { __call = function(_, id) return Names.species_name(id) end })
