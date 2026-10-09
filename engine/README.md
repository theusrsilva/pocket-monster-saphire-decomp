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
direito voltam · Esc encerra o turno.

## O que já funciona (protótipo)

- Importador em Lua: as 32 fases (mapa renderizado, terreno, inimigos, posições iniciais), as
  20 espécies, a tabela de custo de movimento, os sprites do mapa e os retratos
- Seleção de fase com prévia do mapa, inimigos e posições iniciais
- Batalha por turnos: os 6 Pokémon iniciais nas posições da fase, contra os inimigos da fase
- **Alcance de movimento idêntico ao original** (custo por espécie e terreno; coberto por teste)
- **Combate com as fórmulas do jogo original**: acerto, dano com vantagem de tipo, contra-ataque e EXP
- Prévia de ataque com dano, chance de acerto e contra-ataque (o original não mostrava)
- Desfazer movimento antes de agir, mostrar o alcance de qualquer unidade, suporte a mouse
- IA inimiga simples: ataca o alvo mais vulnerável ao seu alcance, senão avança

## Ainda não

Golpes especiais, itens, subida de nível e evolução, eventos e falas das fases, escolha do
time antes da luta, campanha e mapa-múndi, som, nomes reais de todas as espécies e a IA original.

## Estrutura

```
main.lua, conf.lua        ciclo do LÖVE, estados e entrada
src/import/importer.lua   ROM -> cache (formatos em docs/FINDINGS.md)
src/game/pathfind.lua     alcance de movimento (regra do original)
src/game/combat.lua       acerto, dano, contra-ataque e EXP (regra do original)
src/game/battle.lua       estado da batalha, turnos e IA
src/ui/view.lua           desenho do mapa, unidades (shader de paleta) e HUD
src/tests.lua             testes contra valores observados no jogo original
```
