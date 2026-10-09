# Pocket Monster Saphire: notas de engenharia reversa

Jogo: *Pocket Monster Saphire* (caixa: "Pokémon: Sapphire Version"), GBC, Sintax/BBD, 2003,
publicado por "New Game Color Advance". RPG de estratégia em grid. Motor herdado de um jogo
de robôs da própria Sintax (o cabeçalho ainda diz `ROBOT WAR v3.0`).

## ROM de referência

| Campo | Valor |
|---|---|
| Arquivo | `Pokemon Sapphire Version (Pocket Monster Saphire) (Unlicensed, English) [Fixed].gbc` |
| SHA-1 | `9fa7da61c61d684f39e43d6899a68309ba8607b3` |
| MD5 | `fc8900032c10f14a1b03e86814ac745f` |
| Tamanho | 4 MiB (0x400000) |
| Título interno | `ROBOT WAR  v3.0` em $0134; segunda string `POCKET SLG v3.0` em $01B4 |
| CGB flag | $80 (compatível GB/GBC) |
| Cartucho | $1B = MBC5 + RAM + bateria |
| RAM | 32 KiB (código $03) |
| Checksums | header e global corretos |

## Layout de bancos

* Só os bancos com **bit 1 zerado** têm dados: 00,01,04,05,08,09,…,FC,FD. São 128 bancos = **2 MiB reais**.
  Os bancos 02,03,06,07,… estão zerados. Isso é efeito da versão "Fixed", que remapeou a proteção
  da Sintax (o dump raw só roda no hhugboy).
* Todo banco guarda o próprio número no byte **$7FFF**. O código usa `ld a,[$7fff]` para
  salvar o banco atual antes de trocar (`ld [$2000],a`) e restaurar depois.

## Disassembly

* `mgbdis` + `RGBDS 0.9.1` → **remonta byte a byte idêntica** (MD5 confere).
* Rodar `tools/setup.sh` (baixa as ferramentas e gera `disasm/`).

## Texto / script de eventos

* Codificação **ASCII** para letras. Bytes **≥ $E0 são comandos** do interpretador.
* Tabela de comandos em **ROM0:$3427**: 32 entradas de 4 bytes `[handler lo, handler hi, tamanho, 00]`.

| Cmd | Tam. | Uso observado |
|---|---|---|
| E1 | 9 | ? (comando longo, provavelmente movimento/cena) |
| E5, EB | 3 | ? |
| EA xx | 2 | troca falante/retrato (xx = id do personagem) |
| EE 01 lo hi | 4 | dá item: seta flag em `$hilo` (ex.: `$C4E6` = Life Stone) |
| F0–FE | 1 | handler genérico $3A11 (provavelmente pausa/espera) |
| FF | 1 | fim da mensagem |

* Índice de mensagens: banco **$5D:$4000**: ponteiros de 2 bytes por script (`[$C2B0]`), e cada
  um aponta para uma lista de entradas de 4 bytes `[lo, hi, banco, 00]` indexada por `[$C2B1]`.
  Rotina leitora: `ROM0:$3296`; loop de exibição `ROM0:$3309`.
* Texto em dois bancos: **$5D** (tudo MAIÚSCULO, ~715 referências) e **$70** (caixa mista,
  ~344 referências). Total ≈ 328 mensagens / 20 mil caracteres.
* Extrator: `tools/extract_text.py`.

## Gráficos (2bpp, sem compressão até agora)

| Banco(s) | Conteúdo |
|---|---|
| 08, 39 | fontes (dígitos hex, alfabeto) |
| 14 | **sobra do jogo de robôs**: história em chinês pré-renderizada em tiles |
| 40, 41, 4C | UI de batalha/menus: números, HP/SP/EXP, palavras **pré-renderizadas** ("Attack", "Skill", "Goods", "State", "Load", "Save"…) |
| 74, 79, 7C | nomes de golpes, de lugares e de itens **como imagem** |
| 75, F5 | mais retratos/arte |
| 90–B1 | frames de animação de batalha: tiles **deduplicados**, montados por tabelas de metasprite (ainda não localizadas) |
| C0–F1 | dados de fase: tilesets do mapa (prédios, árvores, terreno) |
| **F4** | **retratos dos Pokémon, 4×4 tiles, row-major, sem compressão** ✅ |
| F9 | nomes dos Pokémon pré-renderizados (fundo cinza) |
| FC | sobra de outro jogo (BOOMERANG, GRENADE, MEDI-KIT, PAUSED…) |

**Impacto na tradução:** muitos textos de UI, nomes de Pokémon, golpes e lugares são **imagens**,
não strings. Para traduzir é preciso redesenhar esses tiles (ou, no remake, gerar com fonte).

## Próximos passos

1. Achar as tabelas de stats dos Pokémon (20 recrutáveis + inimigos): procurar sequências
   repetidas de registros de tamanho fixo perto dos nomes em F9.
2. Achar as tabelas de metasprite dos frames de batalha (90–B1): seguir no debugger a rotina que
   escreve na OAM ($FE00 / DMA) durante uma luta.
3. Formato dos mapas de fase (C0–F1): metatiles + mapa + lista de unidades/baús/casas.
4. Paletas CGB: localizar escritas em `rBCPS/rBCPD` ($FF68/$FF69) e `rOCPS/rOCPD`.
5. Fórmulas: dano, contra-ataque, alcance de movimento, XP. Breakpoints no Emulicious/SameBoy.
