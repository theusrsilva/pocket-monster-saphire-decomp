# saphire-recomp — estado técnico do projeto

Visão geral para quem quer jogar: [`README.md`](../README.md). Esta página é o histórico técnico
(checklist da engenharia reversa, ferramentas de pesquisa e releases).

Projeto de engenharia reversa e recriação de **Pocket Monster Saphire** (GBC, Sintax, 2003), um
RPG de estratégia com Pokémon. A ideia segue o modelo do
[Gen1Recomp](https://github.com/bryanthaboi/gen1recomp): entender os formatos de dados e as regras
do jogo, extrair tudo da ROM **do próprio jogador** e reimplementar o motor (LÖVE2D) com tradução,
correção de bugs e melhorias de usabilidade.

> Este repositório não contém a ROM nem dados extraídos dela. Coloque a sua cópia em `rom/saphire.gbc`.

## Estado

- [x] Cabeçalho, mapper e layout de bancos documentados
- [x] Disassembly que remonta byte a byte idêntica (mgbdis + RGBDS)
- [x] Codificação do texto + tabela de comandos do script
- [x] Extrator de texto (`tools/extract_text.py`)
- [x] Dump de tiles de todos os bancos; retratos (banco F4) decodificados
- [x] Tabela das 20 espécies recrutáveis (`tools/extract_species.py`)
- [x] Jogo rodando headless (PyBoy) com controle por script e dump de RAM
- [x] Mapa parcial da WRAM (unidades, status, buffers do mapa)
- [x] Inimigos de cada fase (stats completos)
- [x] Golpes (nomes/efeitos), itens, eventos das fases
- [x] Animações de batalha: cena de ataque decodificada e reimplementada em Lua (`engine/src/anim`),
  conferida quadro a quadro contra o código original no executor de GBC (`engine/src/emu`); roda no 3DS
- [x] Layout de duas telas (3DS) e empacotamento para LÖVE Potion (`tools/package.sh` funde o jogo nos executáveis do LÖVE Potion; patch de uma linha para a música; não testado em hardware)
- [x] Música e efeitos: o driver de som original roda ao vivo no motor (interpretador SM83 + APU)
- [x] Formato das fases: 32 mapas renderizados da ROM, inimigos e posições iniciais (`tools/extract_stages.py`)
- [x] Mapa da SRAM (elenco e inimigos, 64 bytes por unidade)
- [x] Paletas CGB das fases e dos retratos
- [x] Regra de movimento (custo por espécie × terreno), validada contra o jogo
- [x] Fórmulas de acerto, dano e EXP tiradas do código original
- [x] **Protótipo jogável em LÖVE2D** (`engine/`): importador em Lua, batalha por turnos, IA simples
- [x] Subida de nível, evolução e golpes especiais/cura (tabelas do original, no motor)
- [x] Nomes das espécies e dos golpes (transcritos das imagens), com nomes oficiais e tradução PT
- [x] Itens e seus efeitos (inventário `$C4E0`), insígnias = pedras de evolução
- [x] Loja: verificado que **não existe** no original (sem dinheiro no save; itens só de baús, casas e recompensas)
- [x] Eventos e falas das fases (casas, baús, centro de cura), recompensas e recrutamento, campanha salva
- [x] Mapa-múndi: grafo de nós do original, travas por fase vencida e por item-chave, cidades, Instituto e BabyAlliance (evolução)
- [x] Escolha do time antes da luta (máximo = recrutados até 10, ordem das vagas)
- [x] Tradução de todas as falas da campanha para o português (tecla N alterna PT/original)
- [x] Tela de configuração no PC: ROM, idioma PT/EN (inclusive a interface), nomes, prévia, IA original/melhorada, correções
- [x] IA original dos inimigos (`$01:$6B95`), conferida contra o jogo
- [x] Conversor de ROM (tela de configuração): gera uma ROM de GBC/GBA com as falas em português
  (acentos na fonte do jogo), nomes de golpes/espécies/lugares/itens redesenhados e a autocura do
  inimigo corrigida
- [x] Conversor de ROM: menus da unidade, do mapa, escolha do time, Instituto, BabyAlliance, cidades,
  listas de itens, tipos, objetivo, avisos de turno e descrições de golpes/itens
- [x] Conversor de ROM: tela de título, salvar/carregar; evolução e vitória conferidas (sem texto além dos nomes)

Detalhes técnicos em [`FINDINGS.md`](FINDINGS.md).

## Downloads e releases

Cada tag `v*` (por exemplo `git tag v0.1.0 && git push origin v0.1.0`) dispara
`.github/workflows/release.yml`, que gera e publica no release:

- Windows (`.zip` com `SaphireRecomp.exe`), Linux (`.AppImage`), macOS (`.app` em `.zip`, sem
  assinatura) e `saphire-recomp.love`: `tools/build_desktop.sh`, que funde o jogo nos binários
  oficiais do LÖVE 11.5;
- Nintendo 3DS (`.3dsx`): compila o `lovebrew/lovepotion` (commit fixado) com
  `tools/lovepotion-queueable.patch` e funde o jogo; se esse passo falhar, o release sai sem ele;
- notas do release a partir dos commits desde a tag anterior (`tools/release_notes.sh`).

Nenhum arquivo contém a ROM: o jogador escolhe a própria ROM na tela de configuração. Para jogar
no Game Boy Color/Advance (emulador ou flashcart), a mesma tela tem **Gerar ROM traduzida**, que
cria `Pocket Monster Saphire (PT-BR).gbc` ao lado da ROM original.
"Run workflow" na aba Actions faz o build sem publicar; preenchendo o campo **tag** (ex.: `v1.00.00`),
o workflow publica o release e o próprio GitHub cria a tag no commit.

## Jogar o protótipo

Precisa do [LÖVE 11.x](https://love2d.org). Coloque a ROM em `rom/saphire.gbc` e rode `love engine`
(ou arraste a ROM na janela). Detalhes em [`engine/README.md`](../engine/README.md).

## Ferramentas de pesquisa

```sh
./tools/setup.sh                  # baixa mgbdis + RGBDS, gera disasm/ e confere o round-trip
python3 tools/extract_text.py rom/saphire.gbc out/script.json out/script.txt
python3 tools/dump_tiles.py   rom/saphire.gbc out/tiles
python3 tools/extract_species.py rom/saphire.gbc out/species.json
python3 tools/render_stage.py  rom/saphire.gbc all out/stages
python3 tools/extract_stages.py rom/saphire.gbc out/stages.json out/stages
python3 tools/probe_layout.py rom/saphire.gbc <offset_hex> <ntiles> out/probe.png
```

SHA-1 esperado da ROM (versão Fixed do Handheld Underground):
`9fa7da61c61d684f39e43d6899a68309ba8607b3`
