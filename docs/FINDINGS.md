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
| 90–B1 | frames de animação de batalha: tiles **deduplicados**, montados por tabelas de metasprite (provável índice em `$04:$4000`, entradas `[lo, hi, banco, 00]` apontando para os bancos 05/0C/0D/20/21/28/29) |
| C0–F1, 64–6D | dados de fase: mapa, metatiles, tiles e paletas (ver **Fases**) |
| FD | sprites 16×16 das unidades no mapa: `$FD:$4000 + espécie*64`, tiles TL TR BL BR |
| **F4** | **retratos dos Pokémon, 4×4 tiles, row-major, sem compressão** ✅ |
| F9 | nomes dos Pokémon pré-renderizados (fundo cinza) |
| FC | sobra de outro jogo (BOOMERANG, GRENADE, MEDI-KIT, PAUSED…) |

**Impacto na tradução:** muitos textos de UI, nomes de Pokémon, golpes e lugares são **imagens**,
não strings. Para traduzir é preciso redesenhar esses tiles (ou, no remake, gerar com fonte).

## Espécies recrutáveis (banco $09:$4000)

20 registros de **20 bytes**, 4 por tipo (bate com "recrute até 20, quatro de cada tipo").
Extrator: `tools/extract_species.py`. Confirmado contra a RAM do jogo rodando.

| Off | Campo |
|---|---|
| +0 | nível da forma (1 = inicial; 5–35 = forma evoluída) |
| +1 | id gráfico da espécie |
| +2 | tipo: 1 Celerity, 2 Equilibrium, 3 Strength, 4 Super Power, 5 Defense |
| +3 | SP (u16) |
| +5 | HP (u16) |
| +7/+8/+9 | ATK / **PRE** (precisão) / **ESQ** (esquiva): ver **Combate** |
| +10 | MOV: pontos de movimento (ver **Movimento**) |
| +11 | tipo contra o qual é forte; **ciclo 1>2>3>4>5>1** (igual ao tutorial do jogo) |
| +12 | tipo contra o qual é fraco |
| +13 | 1 = já vem no time inicial (6 espécies) |
| +14/+15 | alcance de ataque mín/máx (Super Power: 2–3 ou 2–4) |
| +16/+17 | ids de golpes especiais |

Logo depois (`$09:$4190`) vem a **tabela de custo de movimento** (ver **Movimento**).

## Mapa da WRAM (confirmado rodando o jogo)

| Endereço | Conteúdo |
|---|---|
| `$C800–$C83F` | paletas CGB do BG (BGR555) |
| `$C900–$C91F` | bloco de status da unidade em foco: nível, espécie, HP/HPmax, SP/SPmax, ATK, DEF, SPD, MOV… |
| `$D000–$D3FF` | buffer 32×32 de **atributos CGB** do mapa de batalha (paleta + flip) |
| `$D400–$D7FF` | buffer 32×32 de **ids de tile** do mapa de batalha |
| `$DE00–$DF7F` | elenco recrutado: até 24 registros de 16 bytes `[?, ?, nível, 0, espécie, tipo, SP u16, HP u16, …]` (os 2 primeiros bytes crescem de forma irregular: ponteiro/offset ainda não identificado) |
| `$DF80–$DFDF` | time escalado para a luta: registros de 16 bytes `[nível, 0, espécie, tipo, SP u16, HP u16, …]` |
| `$C2B0/$C2B1` | script e mensagem atuais do sistema de texto |
| `$C007` | **número da fase atual** (0 = mapa-múndi, 1–25 campanha, 26–31 Palaestras) |
| `$C300–$C33F` | cópia do cabeçalho da fase atual |

## SRAM (32 KiB, só o banco 0 é usado)

| Endereço | Conteúdo |
|---|---|
| `$AA00–$B1FF` | **elenco do jogador**: 20 vagas × 64 bytes (uma por espécie recrutável) |
| `$B200–$B9FF` | **inimigos da fase**: 20 vagas × 64 bytes |
| `$BDC0–$BFFF` | paletas pré-calculadas para fade |

Registro de unidade (64 bytes, SRAM): `+0` ativo, `+2` nível, `+5` espécie, `+6` tipo,
`+7` y (px u16), `+9` x (px u16), `+11` slot gráfico, `+12` SP, `+14` HP, `+16` SP máx,
`+18` HP máx, `+20` ATK, `+22` PRE, `+24` ESQ (u16 cada), `+3` EXP (u16), `+26` MOV, `+27` forte contra,
`+28` fraco contra, `+29` inicial, `+34/+35` alcance, `+36..` até 4 golpes de 5 bytes
`[id, poder, custo SP, alcance mín, alcance máx]` (hipótese para os 3 últimos).

## Fases

32 fases: **0** = mapa-múndi, **1–25** = campanha, **26–31** = os 6 Palaestras.
Extratores: `tools/render_stage.py` (só o mapa) e `tools/extract_stages.py` (JSON + mapa anotado
com inimigos e posições iniciais).

**Cabeçalho** em `$7D:$4000 + fase*64`, copiado para `$C300`. Entradas `[banco, 00, ptr u16]`:

| Off | Conteúdo |
|---|---|
| +00 | paletas de BG (64 bytes, 8 × 4 cores BGR555) |
| +04 | paletas de OBJ (todas as fases usam `$7D:$4854`) |
| +08/+0C/+10 | blocos de tiles `[destino u16][tamanho u16] + dados` (passando de $9800 volta para $8800) |
| +14..+20 | tilemaps extras para $9800/$9C00 (nulos nas fases) |
| +24 | **mapa**: ids de metatile u16, (+38)/2 colunas × (+3A) linhas, célula 16×16 |
| +28 | **metatiles**: 8 bytes = tiles TL TR BL BR + 4 atributos CGB |
| +2C | 4 bytes por metatile; o **3º byte é o tipo de terreno** (ver **Movimento**) |
| +30 | 32 bytes, ainda não identificado |
| +34/+36 | scroll máximo X/Y (u16) |
| +38/+3A/+3C | bytes por linha, linhas, tamanho do mapa |

LCDC = `$E7`: fundo com endereçamento com sinal (tile 0 em `$9000`).

**Inimigos:** `$30:$40E6` tem 32 ponteiros u16 (banco $30), um por fase. Cada lista tem registros
de **24 bytes**, terminada quando o nível é `$FF` (máximo 20). Copiados para a SRAM `$B200`.

| Off | Campo |
|---|---|
| +0 | nível |
| +1 | espécie (inclui ids só de inimigo, ex.: $38, $3C, $3F) |
| +2 | tipo |
| +3/+5 | y / x em px (u16; ÷16 = célula) |
| +7 | slot gráfico (grupos do mesmo tipo de inimigo compartilham o slot) |
| +8/+10 | SP / HP (u16) |
| +12/+13/+14 | ATK / PRE / ESQ |
| +15 | MOV |
| +16/+17 | forte / fraco contra |
| +18/+19 | alcance mín / máx |
| +20..+23 | golpe `[id, poder, custo, ?]` (0 = sem golpe) |

**Posições iniciais dos aliados:** `$10:$450E` tem 32 ponteiros u16 (banco $10), com registros de
6 bytes `[00 00, y u16, x u16]`, 10 por fase, terminados por `$FFFF`. Conferido: a vaga 1 da fase 26
é `(6,5)`, exatamente onde o piku aparece na SRAM ao entrar na luta.

## Movimento (confirmado casa a casa contra o jogo)

Rotina em `ROM0:$1A00`. Custo para entrar numa casa:

```
custo = byte[$09:$4190 + espécie*33 + terreno]      ($63 = 99 = intransitável)
terreno = 3º byte de (+2C da fase)[metatile*4]
```

A unidade gasta até **MOV** pontos (Dijkstra). Há 76 linhas, uma por espécie: a família do BoBo
(voadores, linhas 7–12 e 56–58) paga 2 em tudo; os aquáticos (13–18, 59, 61, 62) atravessam o
terreno 11 (água) com custo 3. No Palaestra de Ifleaf, o alcance previsto do Piku (MOV 9, chão
custo 2) bateu com as 28 casas azuis mostradas pelo jogo. Esse caso virou teste automático do motor.

## Combate (rotinas `$01:$6526` → `$6542`, `$65AC`, `$664E`, `$66EE`, `$677A`)

O bloco do atacante é copiado para `$C900` e o do defensor para `$C980`, no formato da SRAM.

| Etapa | Fórmula |
|---|---|
| Acerto% | `clamp(100 + PRE(atacante) − ESQ(defensor), 0, 100)`, +20 se forte, −20 se fraco |
| Sorteio (`$38:$73C0`) | erro% ≥ 90: sempre erra; < 10: sempre acerta; senão compara com o byte aleatório `[$C035]` |
| Dano | `ATK (+ poder do golpe especial)` × 1,5 se forte (`a + a>>1`), × 0,5 se fraco (`a>>1`) |
| Aplicação (`$09:$695F`) | HP −= dano. **Não existe redução por defesa.** |
| Golpe especial | SP −= custo (`[$CD14]`), ATK += poder (`[$CD01]`) |
| EXP (`$1D:$5860`) | derrubou: 16 × 2^dif, acertou: 8 × 2^dif (dif = nível do alvo − nível próprio, 1..9; dif 0 → ×2), máx. 100; alvo de nível menor dá 1; errar dá 0; nível 99 não ganha |

O contra-ataque usa as mesmas contas com os papéis trocados (`$CD45`/`$CD03`).

## Desenho das unidades

As unidades **não são sprites**: viram tiles do BG. Os 4 tiles da espécie (`$FD:$4000 + espécie*64`)
são copiados para a VRAM em `$89C0 + slot*64` (`$10:$420F`). Aliados usam a paleta de BG 7 e
inimigos a 6, ambas vindas da própria fase. Só o cursor usa OAM.

## Emulação para pesquisa

`tools/run_headless.py` + `tools/play.py` rodam a ROM no **PyBoy** sem janela
(`pip install pyboy`). O `play.py` carrega um save state, aplica uma sequência de botões
(`"up*2 wait60 a"`), salva o novo state, um screenshot e o dump da WRAM. Rota até a 1ª batalha:
intro (≈40×A) → menu do Doctor Institute (B×6) → `up` (Ifleaf town) → A → "If leaf Palaestra" →
escolher unidades com A/↓ → START.

## Próximos passos

1. ~~Stats das espécies~~ ✅ ~~Inimigos e posições por fase~~ ✅. Falta: tabela de golpes (nome/efeito),
   itens, eventos de cada fase (casas, baús, falas: provavelmente ligados ao script `$5D`).
2. Achar as tabelas de metasprite dos frames de batalha (90–B1): seguir no debugger a rotina que
   escreve na OAM ($FE00 / DMA) durante uma luta.
3. ~~Formato dos mapas~~ ✅. Falta: confirmar a tabela de terreno (+2C) e a paleta de cada sprite de unidade.
4. ~~Paletas de BG das fases~~ ✅ (rotinas `ROM0:$2C56`/`$2C42`). Falta: paletas da UI e dos retratos.
5. ~~Fórmulas de dano, acerto, EXP e movimento~~ ✅. Falta: regra exata do contra-ataque, subida de
   nível (limite de EXP e ganho de status), evolução, IA original dos inimigos, efeitos dos golpes.
