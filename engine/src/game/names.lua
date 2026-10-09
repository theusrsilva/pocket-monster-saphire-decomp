-- Nomes das espécies. No jogo original os nomes são IMAGENS (banco $F9), não texto;
-- por enquanto só os nomes já vistos rodando o jogo estão aqui. O resto vira "#id".
local known = {
  [0x01] = "Piku",
  [0x07] = "BoBo",
  [0x10] = "Littlecrocodile",
  [0x16] = "Mumleaf",
}

return function(species)
  return known[species] or ("#%02X"):format(species)
end
