# Motor (LÖVE2D)

Recriação nativa do Pocket Monster Saphire em Lua/LÖVE 11.x, no modelo do
[Gen1Recomp](https://github.com/bryanthaboi/gen1recomp): **nenhum dado do jogo vem junto**. Na
primeira execução o importador lê a ROM do jogador, confere o SHA-1, gera o cache na pasta de dados
do LÖVE (`~/.local/share/love/saphire-recomp/generated/` no Linux) e libera a ROM da memória.

## Tela de configuração

No PC o jogo abre numa tela de configuração (como o launcher do Gen1Recomp), que também abre com
**F1** no mapa-múndi:

- **ROM**: digite o caminho (Enter) ou arraste o `.gbc` na janela; ela é conferida (SHA-1) e
  importada para o cache.
- **Idioma**: português ou inglês (falas, menus, golpes, tipos, itens e lugares; em inglês as falas
  são as do jogo). A tecla N também troca.
- **Nomes dos Pokémon**: oficiais ou os do jogo (piku, BoBo...).
- **Prévia de ataque**, **desfazer movimento**: melhorias que o original não tinha.
- **IA dos inimigos**: a original (`$01:$6B95`) ou a melhorada (`src/game/ai_plus.lua`): usa o
  alcance real e os golpes, prioriza quem pode derrubar e pesa o contra-ataque, cura aliados.
- **Corrigir autocura do inimigo**: no original ela passa do HP máximo.
- **Turno inimigo** normal/rápido, **som** (volume), **tela cheia**, **mostrar esta tela ao abrir**.
- **Jogar** / **Gerar ROM traduzida** / **Sair**.

**Gerar ROM traduzida** cria, a partir da ROM configurada, `Pocket Monster Saphire (PT-BR).gbc` na
mesma pasta (ou na pasta de dados): falas em português com acentos e, se a opção estiver ligada, a
autocura do inimigo corrigida. Roda em qualquer emulador de GBC/GBA ou flashcart. Detalhes em
`docs/FINDINGS.md` ("Motor de texto e ROM traduzida"). Sem a tela: `love engine --build-rom saída.gbc`.

As opções ficam em `options.lua` na pasta de dados (`src/game/options.lua`).

## Rodar

```sh
love engine                         # procura ../rom/saphire.gbc; se não achar, arraste a ROM na janela
love engine --rom caminho/rom.gbc   # importa uma ROM específica
love engine --stage 26              # vai direto para uma fase (sem passar pelo mapa)
love engine --node 9 --cleared 8    # testes: cursor no nó 9, fases 1-8 vencidas (save_test.lua)
love engine --test                  # roda os testes automáticos e sai
love engine --stage 2 --script "wait20 z" --shot out.png   # entradas automáticas + screenshot
```

Controles: setas/WASD movem o cursor · Z/Enter/Espaço ou clique confirmam · X/Backspace ou botão
direito voltam · Esc encerra o turno · M liga/desliga o som · N alterna entre **PT** (falas traduzidas, nomes oficiais) e
**original** (falas e nomes como no jogo).

`src/game/names.lua` e `src/game/translation_pt.lua` são os únicos arquivos com conteúdo do jogo: os
nomes transcritos das imagens e a tradução das falas. O texto original em inglês não fica no
repositório; ele é lido da ROM. Para revisar a tradução, `love engine --dump-text out/falas.txt`
despeja as falas originais (fora do git), com a chave `banco:endereço` de cada trecho.

## Console (3DS/Switch via LÖVE Potion)

O motor já vem preparado para o [LÖVE Potion](https://lovebrew.org):

- **3DS (duas telas)**: o mapa fica na tela de cima (400×240) e os painéis, menus e falas na de
  baixo (320×240). Para ver esse layout no PC: `love engine --dual 1`.
- **Switch**: usa o layout normal (uma tela).
- Sem shaders (o LÖVE Potion não tem): os sprites indexados são coloridos por paleta em cache
  (`--noshader 1` força esse caminho no PC).
- Sem LuaJIT: `src/util/bit.lua` tem uma versão em Lua puro das operações de bits.
- Botões: A confirma, B volta, START encerra o turno/vai para "Lutar", X troca PT/original,
  Y liga/desliga o som, direcional move. No 3DS, tocar na tela de baixo confirma.
- ROM: coloque `saphire.gbc` na pasta de dados do jogo no cartão SD. Como a importação em Lua é
  lenta no 3DS, o melhor é importar no PC e copiar a pasta de dados
  (`~/.local/share/love/saphire-recomp/`, com `generated/`) para a pasta de dados no console.

Empacotar: `tools/package.sh` gera `dist/saphire-recomp.love` (roda em qualquer LÖVE 11). Passando
os executáveis do LÖVE Potion, ele também "funde" o jogo neles, que é como o LÖVE Potion 3 carrega um
jogo: `tools/package.sh lovepotion.3dsx lovepotion.nro` gera `dist/saphire-recomp.3dsx` e `.nro`.
A fusão foi conferida com o LÖVE do PC (o executável fundido passa nos testes).

- **Música no console**: o LÖVE Potion 3.x tem `newQueueableSource` no C++ mas não o registra no
  `love.audio`; sem isso o jogo roda mudo. Compile o LÖVE Potion com
  `tools/lovepotion-queueable.patch` (uma linha; `git apply` dentro do repositório do lovepotion).
- **Desempenho**: o LÖVE Potion usa Lua 5.1 sem JIT. Medido no PC com Lua 5.1 puro, o som custa
  ~0,9 ms por quadro a 22 kHz; no 3DS o padrão é 11 kHz (`--audio-rate` muda). No 3DS antigo
  (268 MHz) ainda pode pesar: se faltar quadro, desligue o som (Y).
- **Pasta de dados**: num jogo fundido o LÖVE usa a pasta do nome do jogo (`saphire-recomp`),
  não `love/saphire-recomp`. Importe a ROM no PC e copie essa pasta (com `generated/`) para a pasta
  de dados do LÖVE Potion no cartão SD.

**Não testado em hardware.**

## O que já funciona (protótipo)

- Importador em Lua: as 32 fases (mapa renderizado, terreno, inimigos, posições iniciais), as
  20 espécies, a tabela de custo de movimento, os sprites do mapa e os retratos
- **Mapa-múndi** (fase 0) com o grafo de nós do original (`$09:$6B7D`): o cursor anda de lugar em
  lugar, cada direção pode exigir uma fase vencida, fases vencidas não reabrem e as fases 9, 11, 16,
  19, 24 e 25 pedem o item-chave (com a fala condicional do original). Cidades com Palaestra (treino,
  repetível), Prefeito e Morador; Instituto do Doutor (dicas) e BabyAlliance (evolução com as insígnias)
- **Escolha do time** antes da luta, com a regra do original: até `min(recrutados, 10)` Pokémon,
  marcados com Z e confirmados em "Lutar" (Esc); entram nas posições iniciais na ordem do elenco
- Batalha por turnos: o time escolhido nas posições da fase, contra os inimigos da fase
- **Alcance de movimento idêntico ao original** (custo por espécie e terreno; coberto por teste)
- **Combate com as fórmulas do jogo original**: acerto (com o ajuste de tipo exato), sorteio, dano com
  vantagem de tipo, EXP e o **contra-ataque do original** (com golpe, se o alcance cobrir; senão só colado)
- Prévia de ataque com dano, chance de acerto e contra-ataque (o original não mostrava)
- Desfazer movimento antes de agir, mostrar o alcance de qualquer unidade, suporte a mouse
- **Subida de nível, ganho de status e bônus escolhido**, com as tabelas do original
- **Itens** com os efeitos do original (cura, vitaminas permanentes) e **evolução** pelas insígnias
  na BabyAlliance, com os bônus e o golpe aprendido de cada forma
- **Golpes especiais e de cura** (tabela de golpes do original), também usados pelos inimigos
- Chefes com MOV 0 ficam parados
- **Nomes e falas**: em português (nomes oficiais, golpes, tipos, itens e lugares traduzidos e
  **todas as falas da campanha traduzidas**, inclusive a introdução) ou como no jogo original,
  alternando com a tecla N (a escolha fica salva); retrato da unidade no painel, com a paleta do
  original (paleta 4 de BG)
- **Eventos das fases**: casas, baús e centro de cura disparam as falas originais, com o retrato de
  quem fala; itens dos baús vão para o inventário; casas e baús valem uma vez por entrada na fase e
  três casas especiais (fases 8, 18 e 21) ensinam um golpe a certas espécies
- O original não tem loja (verificado no código): os itens vêm só de baús, casas e recompensas
- **Campanha**: o time começa com os 6 iniciais; a vitória mostra a recompensa da fase e recruta os
  novos Pokémon; elenco, níveis, inventário e fases vencidas ficam salvos (`save.lua`; Delete na
  mapa-múndi recomeça)
- **IA inimiga do original** (`$01:$6B95`): da última vaga para a primeira, cada inimigo se cura se
  estiver com metade do HP, ataca quem está colado, anda até colar no primeiro aliado (na ordem do
  elenco) que consegue alcançar ou se aproxima até 4 casas; o chefe (vaga 0) não anda

## Ainda não

Animações de batalha (metasprites).

## Estrutura

```
main.lua, conf.lua        ciclo do LÖVE, estados e entrada
src/import/importer.lua   ROM -> cache (formatos em docs/FINDINGS.md)
src/game/pathfind.lua     alcance de movimento (regra do original)
src/game/combat.lua       acerto, dano, golpes, cura, contra-ataque e EXP (regra do original)
src/game/progress.lua     nível, ganho de status, bônus e evolução (regra do original)
src/game/campaign.lua     elenco, inventário, progresso e nó do mapa salvos (equivale à SRAM)
src/game/world.lua        mapa-múndi: grafo, travas, cidades, Instituto, BabyAlliance
src/game/teamselect.lua   escolha do time antes da luta
src/game/messages.lua     falas: resolve os desvios condicionais (comando E2) e escolhe PT/original
src/game/translation_pt.lua  tradução das falas (chave = banco:endereço do trecho na ROM)
src/util/sm83.lua         interpretador da CPU do Game Boy (roda o driver de som original)
src/audio/apu.lua         síntese do APU (2 pulsos, onda, ruído)
src/audio/sound.lua       som em tempo real (QueueableSource)
src/import/music.lua      máquina mínima do driver + exportação em WAV (--render-music)
src/ui/dual.lua           telas de baixo do modo de duas telas (3DS)
src/ui/launcher.lua       tela de configuração (ROM e opções)
src/game/options.lua      opções do jogador
src/game/i18n.lua         textos da interface em inglês
src/game/ai_plus.lua      IA melhorada (opcional)
src/util/bit.lua          operações de bits (LuaJIT ou Lua puro)
src/romhack/patcher.lua   conversor de ROM (ROM traduzida para GBC/GBA)
src/romhack/dialogs.lua   falas em PT na ROM: reapontamento, quebra por palavra, acentos
src/romhack/buffer.lua    cópia editável da ROM + checksum
src/game/items.lua        itens e efeitos
src/game/names.lua        nomes transcritos (oficiais/originais)
src/game/battle.lua       estado da batalha, eventos, turnos e IA do original
src/ui/view.lua           desenho do mapa, unidades (shader de paleta) e HUD
src/tests.lua             testes contra valores observados no jogo original
```
