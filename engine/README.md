# Motor (LÖVE2D)

Recriação nativa do Pocket Monster Saphire em Lua/LÖVE 11.x, no modelo do
[Gen1Recomp](https://github.com/bryanthaboi/gen1recomp): **nenhum dado do jogo vem junto**. Na
primeira execução o importador lê a ROM do jogador, confere o SHA-1, gera o cache na pasta de dados
do LÖVE (`~/.local/share/love/saphire-recomp/generated/` no Linux) e libera a ROM da memória.

## Rodar

```sh
love engine                         # procura ../rom/saphire.gbc; se não achar, arraste a ROM na janela
love engine --rom caminho/rom.gbc   # importa uma ROM específica
love engine --stage 26              # vai direto para uma fase
love engine --test                  # roda os testes automáticos e sai
```

Controles: setas/WASD movem o cursor · Z/Enter/Espaço ou clique confirmam · X/Backspace ou botão
direito voltam · Esc encerra o turno · N alterna nomes oficiais/originais.

`src/game/names.lua` é o único arquivo com conteúdo do jogo: os nomes transcritos das imagens
(necessários para a tradução).

## O que já funciona (protótipo)

- Importador em Lua: as 32 fases (mapa renderizado, terreno, inimigos, posições iniciais), as
  20 espécies, a tabela de custo de movimento, os sprites do mapa e os retratos
- Seleção de fase com prévia do mapa, inimigos e posições iniciais
- Batalha por turnos: os 6 Pokémon iniciais nas posições da fase, contra os inimigos da fase
- **Alcance de movimento idêntico ao original** (custo por espécie e terreno; coberto por teste)
- **Combate com as fórmulas do jogo original**: acerto, dano com vantagem de tipo, contra-ataque e EXP
- Prévia de ataque com dano, chance de acerto e contra-ataque (o original não mostrava)
- Desfazer movimento antes de agir, mostrar o alcance de qualquer unidade, suporte a mouse
- **Subida de nível, ganho de status e bônus escolhido**, com as tabelas do original
- **Itens** com os efeitos do original (cura, vitaminas permanentes) e **evolução** pelas insígnias,
  com os bônus e o golpe aprendido de cada forma (inventário de teste por batalha, provisório)
- **Golpes especiais e de cura** (tabela de golpes do original), também usados pelos inimigos
- Chefes com MOV 0 ficam parados
- **Nomes**: oficiais (com golpes em português) ou os originais do jogo, alternando com a tecla N
  (a escolha fica salva); retrato da unidade no painel
- IA inimiga simples: escolhe entre ataque e golpe o que mais tira HP, cura aliados, senão avança

## Ainda não

Loja, eventos e falas das fases (de onde vêm os itens), escolha do time antes da luta, campanha e mapa-múndi, som, paletas dos retratos e a IA original.

## Estrutura

```
main.lua, conf.lua        ciclo do LÖVE, estados e entrada
src/import/importer.lua   ROM -> cache (formatos em docs/FINDINGS.md)
src/game/pathfind.lua     alcance de movimento (regra do original)
src/game/combat.lua       acerto, dano, golpes, cura, contra-ataque e EXP (regra do original)
src/game/progress.lua     nível, ganho de status, bônus e evolução (regra do original)
src/game/battle.lua       estado da batalha, turnos e IA
src/ui/view.lua           desenho do mapa, unidades (shader de paleta) e HUD
src/tests.lua             testes contra valores observados no jogo original
```
