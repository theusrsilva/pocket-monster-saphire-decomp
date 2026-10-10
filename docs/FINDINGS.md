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
| E2 | 9 | desvio: `E2 a16 v16 pIgual pDif`: se `byte[a16] == v16` segue em `pIgual`, senão em `pDif` (handler `ROM0:$355C`). Usado nas portas das fases com item-chave |
| E5, EB | 3 | ? |
| EA xx | 2 | troca falante/retrato (xx = id do personagem) |
| EE 01 lo hi | 4 | dá item: +1 em `$hilo` (`$C4E0 + id`, ex.: `$C4E6` = Life Stone) |
| EE 02 lo hi | 4 | recruta: liga `$hilo` = `$AA00 + vaga*64 + $1D` |
| EE 03 lo hi v16 | 6 | item-chave: grava `v16` em `$hilo` (`$C4F1+`) |
| F0–FE | 1 | handler genérico $3A11 (provavelmente pausa/espera) |
| FF | 1 | fim da mensagem |

* Índice de mensagens: banco **$5D:$4000**: ponteiros de 2 bytes por script (`[$C2B0]`), e cada
  um aponta para uma lista de entradas de 4 bytes `[lo, hi, banco, 00]` indexada por `[$C2B1]`.
  Rotina leitora: `ROM0:$3296`; loop de exibição `ROM0:$3309`.
* Texto em dois bancos: **$5D** (tudo MAIÚSCULO, ~715 referências) e **$70** (caixa mista,
  ~344 referências). Total ≈ 328 mensagens / 20 mil caracteres.
* Extrator: `tools/extract_text.py`.
* Scripts por número (`[$C2B0]`): **`$20`** = introdução da história (mensagens 1–5); **`$21`–`$39`** =
  fases 1–25; **`$3A`–`$3F`** = cidades; **`$40`** = Instituto; **`$41`** = BabyAlliance. As tabelas de
  ponteiros dos scripts se sobrepõem (a mensagem 35+ de um script é a 0+ do seguinte), por isso as
  mensagens se repetem entre scripts: a fala da Equipe Rocket é a mensagem 0 da fase 25 e a 35 da 24.
* Tradução: o motor identifica cada trecho de fala pelo endereço na ROM (`banco:endereço`, e cada ramo
  de um `E2` é um trecho próprio). São 228 trechos distintos nas falas da campanha.

## Gráficos (2bpp, sem compressão até agora)

| Banco(s) | Conteúdo |
|---|---|
| 08, 39 | fontes (dígitos hex, alfabeto) |
| 14 | **sobra do jogo de robôs**: história em chinês pré-renderizada em tiles |
| 40, 41, 4C | UI de batalha/menus: números, HP/SP/EXP, palavras **pré-renderizadas** ("Attack", "Skill", "Goods", "State", "Load", "Save"…) |
| 74, 79, 7C | nomes de golpes, de lugares e de itens **como imagem** |
| 75, F5 | mais retratos/arte |
| 90–B1 | tiles dos quadros da animação de batalha (ver **Animação de batalha**: scripts por `$04:$4000`, quadros por `$80:$4400`) |
| C0–F1, 64–6D | dados de fase: mapa, metatiles, tiles e paletas (ver **Fases**) |
| FD | sprites 16×16 das unidades no mapa: `$FD:$4000 + espécie*64`, tiles TL TR BL BR |
| **F4/F5** | **retratos dos Pokémon**, 4×4 tiles, row-major; tabela de ponteiros por espécie no início de F4 (ver **Texto em imagem**) |
| F9 | nomes das espécies como imagem, 7×2 tiles (ver **Texto em imagem**) |
| FC | sobra de outro jogo (BOOMERANG, GRENADE, MEDI-KIT, PAUSED…) |

**Impacto na tradução:** muitos textos de UI, nomes de Pokémon, golpes e lugares são **imagens**,
não strings. Para traduzir é preciso redesenhar esses tiles (ou, no remake, gerar com fonte).

## Texto em imagem (nomes, golpes, retratos)

Carregador genérico em `ROM0:$300B`: no início do banco há uma tabela `[banco, 00, ptr u16]` por id
(`BANCO:$4000 + id*4`), e a imagem é copiada por HDMA com tamanho fixo.

| Banco | Conteúdo | Tamanho |
|---|---|---|
| `$F9` | nomes das espécies, id = espécie ($01–$4B) | 7×2 tiles (HDMA `$0D`) |
| `$79` | nomes dos golpes, id = golpe ($01–$58) | 7×2 tiles |
| `$F4` (→ `$F5`) | retratos, id = espécie ($01–$4B) | 4×4 tiles (HDMA `$0F`) |
| `$7C:$4000` | nomes dos lugares ($00 ChangPanCity … $20 BabyAlliance) | 9×2 tiles (`$11`) |
| `$7C:$4088` / `$40A0` | ícones dos 5 tipos | 2×2 tiles (`$03`) |
| `$7C:$40A8` | itens-chave da história (Moon Stone, The pass, Miraculous flute, Red squama, Dragon tooth, Rainbow feather) | 7×2 (`$0D`) |
| `$7C:$40C4` | nomes dos 6 Palaestras | 7×2 (`$0D`) |
| `$7C:$40DC` | texto do objetivo da fase ("Defeat all of the enemies") | 36 tiles (`$23`) |
| `$7C:$4108` | retratos dos personagens dos diálogos (falante do comando `EA`) | 16 tiles (`$0F`) |

Ferramenta: `tools/dump_textimages.py ROM banco largura altura primeiro último saída.png`.
Os nomes foram transcritos em `engine/src/game/names.lua`, junto com o nome oficial do Pokémon
(confirmado pelo retrato) e a tradução dos golpes para PT-BR.

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

A unidade gasta **menos que MOV** pontos (Dijkstra): `ROM0:$1A00` grava em `$C059` o MOV que sobra
depois de entrar na casa (`[$C058] − custo`) e a BFS (`$09:$5945`) só aceita a casa se a sobra for
**maior que zero** (sobra 0 é recusada pelo `cp b / ret nc` contra o valor da casa em `$A400`). Com
MOV ímpar dá na mesma que "até MOV"; com MOV par tira um passo. Conferido no PyBoy: Geodude
(espécie `$32`, MOV 6, chão custo 2) no Palaestra de Ifleaf (fase 26) em (7,3) só chega a 2 casas de
distância. O MOV entra limitado a 16 (`$01:$5C80`). Há 76 linhas, uma por espécie: a família do BoBo
(voadores, linhas 7–12 e 56–58) paga 2 em tudo; os aquáticos (13–18, 59, 61, 62) atravessam o
terreno 11 (água) com custo 3. No Palaestra de Ifleaf, o alcance previsto do Piku (MOV 9, chão
custo 2) bateu com as 28 casas azuis mostradas pelo jogo. Esse caso virou teste automático do motor.

## Combate (rotinas `$01:$6526` → `$6542`, `$65AC`, `$664E`, `$66EE`, `$677A`)

O bloco do atacante é copiado para `$C900` e o do defensor para `$C980`, no formato da SRAM.

| Etapa | Fórmula |
|---|---|
| Acerto% (`$6542`/`$65AC`/`$6616`) | `a = max(0, 100 + PRE(atacante) − ESQ(defensor))`; o ajuste de tipo olha só o **byte baixo**: forte → 100 se `a ≥ 80`, senão `a + 20`; fraco → 0 se `a < 32`, senão `a − 20`; **só no fim** limita a 100. Erro% = 100 − acerto% |
| Sorteio (`$38:$73C4` ataque, `$741B` contra) | erro ≥ 90: sempre erra; erro **< 20**: sempre acerta; no meio acerta se o byte aleatório `[$C035]` (0–99) for **maior** que o erro |
| Dano | `ATK (+ poder do golpe especial)` × 1,5 se forte (`a + a>>1`), × 0,5 se fraco (`a>>1`) |
| Aplicação (`$09:$695F`) | HP −= dano. **Não existe redução por defesa.** |
| Golpe especial | SP −= custo (`[$CD14]`), ATK += poder (`[$CD01]`) |
| EXP (`$1D:$5860`) | derrubou: 16 × 2^dif, acertou: 8 × 2^dif (dif = nível do alvo − nível próprio, 1..9; dif 0 → ×2), máx. 100; alvo de nível menor dá 1; errar dá 0; nível 99 não ganha |

O contra-ataque usa as mesmas contas com os papéis trocados (`$CD45`/`$CD03`). **Quem contra-ataca**
(`$09:$6842`, chamado quando um aliado ataca): o defensor percorre os seus golpes do 4º espaço para
o 1º e usa o primeiro **golpe de ataque** (id ≥ `$0C`) cujo **alcance máximo** seja ≥ o alcance
máximo da ação do atacante (`[$C93F]`): soma o poder ao ATK (`$CD40/$CD41`) e **gasta o SP sem
conferir se tem**. Sem golpe assim, contra-ataca com ataque normal **só se a distância for 1**
(`[$C012]`, o anel do alvo); senão não há contra. Quando é o inimigo que ataca (`$01:$6AA9`), o contra
do aliado é sempre o ataque normal. Quem caiu (`[$C066]`) não contra-ataca.

## IA dos inimigos (`$01:$6B95`)

O turno inimigo percorre os registros da SRAM **da última vaga para a primeira** (`$B6C0` → `$B200`,
só os ativos com o bit 0 de `+1` ligado). Mapa de ocupação `$A000` (32×32): aliados = `$81 + vaga`,
inimigos = `$A1 + vaga`; `$A400` é uma cópia só com os aliados (valores ≥ `$A1` zerados) ou, depois do
cálculo de alcance, as casas alcançáveis. Para cada inimigo (copiado para `$C980`):

1. Grava `[$C9BE] = [$C9BF] = 1`: **a busca de alvo usa sempre raio 1**, qualquer que seja o alcance
   de ataque da unidade (os Super Power também chegam colados).
2. **Cura**: se o 1º golpe (`+$24`) é de cura (`$01–$0B`) e `HP ≤ HP máx >> 1`, chama `$18:$6934`:
   com SP ≥ custo (`+$26`), SP −= custo e **HP += `$18:$697B[golpe]`** (150, 300, 400, 800, 150, 300,
   600, 700, 700, 800, 1000) **sem limitar ao HP máximo** (bug do original; o motor limita). Com ou
   sem SP, o turno desse inimigo acaba aí.
3. **Alvo colado** (`$09:$4F74` em volta da própria posição, raio 1, ordem **cima, direita,
   esquerda, baixo**): ataca o primeiro aliado achado, sem andar.
4. A **vaga 0** (`$B200`, o chefe) nunca anda.
5. **Andar e atacar**: alcance com MOV limitado a 16 (`$0EB8` → BFS `$09:$583E`, mesma tabela de
   custo; só casas com id ≥ `$A1` em `$A000` bloqueiam, então **o inimigo atravessa os aliados**, mas
   não para em cima deles). `$01:$7133` percorre os aliados vivos **na ordem das vagas do elenco** e,
   em volta de cada um (raio 1), procura a primeira casa alcançável e vazia. Achando, anda até lá e
   procura de novo o aliado colado (cima, direita, esquerda, baixo) para atacar.
6. **Aproximar**: senão, repete o passo 5 com **raio 4** (`[$C016] = 1` soma 3 ao raio) e só anda,
   sem atacar. Sem casa possível, fica parado.

O ataque é sempre o normal (`$01:$6AA9` zera `$CD00/$CD01`), com contra-ataque; os golpes de ataque
dos inimigos nunca são usados.

**Listas de casas por raio** (`$09:$5088`, ponteiros u16 no banco `$09`): registros de 6 bytes
`[dx px s16, dy px s16, distância, 0]`, do anel mais distante para o mais próximo, cada anel numa ordem
fixa (`(−d,0) (0,d) (0,−d) (d,0) (−1,d−1) (1,−(d−1)) …`); `$EE` separa os anéis ≥ 2 do anel 1 (a busca
só passa dele se o alcance mínimo for 1) e `$FF` termina.

Conferido no PyBoy, fase 1: com o Piku (vaga 0) em (26,11) e o BoBo (vaga 2) em (26,6), ao fim do
turno o inimigo 11 vai de (21,13) para (22,11) e o 9 de (21,12) para (23,12) (primeiras casas do raio
4 em volta do Piku que eles alcançam); todos os outros ficam parados porque não alcançam nenhuma.

**Animação do turno inimigo** (medida no PyBoy, fase 1): a câmera vai até o inimigo (~6 quadros),
ele anda **casa a casa a 4 px por quadro com um quadro parado a cada três (~6 quadros por casa)**,
com sprites de andar (tiles `$7C/$7E`), e há ~27 quadros de pausa antes da próxima ação. O registro
na SRAM só muda no fim do trajeto. O motor anda pelo menor caminho do mesmo alcance
(**SUPOSIÇÃO**: o desempate entre caminhos iguais não foi conferido) e usa o mesmo ritmo para os
aliados. Alcance de movimento conferido de novo contra o mapa `$A400` do original (BoBo e Pichu na
fase 1): igual; o Geodude (MOV par) mostrou a regra do "menor que MOV" (ver **Movimento**).

## Itens (inventário em `$C4E0 + id`, 1 byte por item; efeitos em `$01:$4ECB`)

| id | Item | Efeito |
|---|---|---|
| $00 | Candy | HP +200 |
| $01 | Juice | SP +200 |
| $02 | Bread | HP +500 |
| $03 | Milk | SP +400 |
| $04 | Cake | HP cheio |
| $05 | Honey | SP +600 |
| $06 | Life stone | HP máx +10 |
| $07 | Spirit stone | SP máx +5 |
| $08 | Flames stone | ATK +2 |
| $09 | Eye stone | PRE +2 |
| $0A | Phoenix stone | ESQ +2 |
| $0B | Flight stone | MOV +2 (máx. 15) |
| $0C–$10 | Celerity / Equilibrium / Strength / Exceed / Defense badge | evolução (ver abaixo) |

Os itens são dados pelo script de falas (`{GIVE 01 lo hi}` = soma 1 em `$hilo`): "Acquire the bread!!".
As "badges" são as pedras de evolução que o código de evolução consome (`$C4EC + índice`).

## Nível e evolução

**Espécies em linhas de 3 ids** (ex.: `$01→$02→$03` é a linha do Piku; algumas linhas têm 2 formas).
Os 20 registros de `$09:$4000` são os 20 Pokémon recrutáveis na forma e no nível em que entram no time.

| Tabela | Conteúdo |
|---|---|
| `$1D:$5814` [espécie] | nível máximo da forma (20 / 40 / 99). No máximo, a EXP zera até evoluir |
| `$01:$6935` [espécie] × 5 | `[HP+, SP+, chance ATK, chance PRE, chance ESQ]` por nível |
| `$01:$6A71` [espécie] | estágio da evolução (1–3) = classe de crescimento |
| `$01:$6A4D` [estágio] × 4 | ganho sorteado: `valor[rand & 3]` (estágio 1: 0,1,2,1; 2: 0,2,3,2; 3: 0,3,4,3) |
| `$01:$6A5D` [estágio] × 5 | **bônus escolhido pelo jogador** após subir: HP, SP, ATK, PRE ou ESQ (estágio 1: 3/2/1/1/1) |
| `$01:$56FF` [espécie] | 1 = forma final |
| `$19:$5C14` [espécie nova] × 6 | bônus ao evoluir: `[SP+, HP+, ATK+, PRE+, ESQ+, MOV+]` |
| `$19:$5EDA` [espécie nova] | golpe aprendido ao evoluir (só nas formas finais) |
| `$01:$56C7` [espécie] | vaga do elenco (0–19) dessa linha |

**Subir de nível** (`$1D:$5620`): com EXP ≥ 100 e abaixo do máximo da forma, nível +1 e EXP −100.
HP e SP sobem o valor fixo. ATK, PRE e ESQ sobem só se o sorteio 0–99 ficar abaixo da chance, e aí
o ganho é `valor[sorteio & 3]`. Depois o jogador escolhe um bônus extra (`$01:$5370`) e **HP/SP são
restaurados ao máximo**.

**Evoluir** (`$01:$5630` → `$19:$5B52`/`$5F82`): consome uma pedra de evolução do inventário
(`$C4EC + índice`), a espécie vira `espécie+1`, os status ganham o bônus da nova forma, HP/SP
enchem e o golpe da forma é aprendido no primeiro espaço livre. O código não exige nível máximo.

**RNG** (`ROM0:$0D7A`): `[$C035] = ([$C035] + 1 + ([$C037] & $3F)) mod 100`, ou seja, 0–99.

## Golpes (`$09:$4D5B`, 6 bytes por id, ids $01–$57)

`[tipo, poder u16, custo SP, alcance mín, alcance máx]`. Tipo 1 = **cura** (ids $01–$0B, recupera
"poder" de HP: 150 a 1000); tipo 0 = ataque (dano = ATK + poder). Na unidade, cada golpe ocupa 5 bytes
`[id, poder, custo, mín, máx]` a partir de `+$24` (até 4), recalculados por `$09:$4D3C`.
Nos inimigos o golpe é só o id (byte +20 do registro). 352 dos 593 inimigos têm um golpe.
Inimigos com **MOV 0** não se movem (os chefes de cada fase).

## Eventos e falas das fases

* O script de uma fase de campanha `s` (1–25) é o **`s + $20`** no índice de `$5D:$4000`.
* Rotina `$01:$4D37`, ao terminar o movimento: terreno **15** = cura (repete); **16–17** = nada (toda
  fase tem uma casa 16/17); **18–32** = mensagem de mesmo número, **uma vez por entrada na fase**
  (flags `$C518 + t − 18`, zeradas ao entrar); **27 (`$1B`)** = sem mensagem, ensina golpe
  (`$09:$4C12`): na fase 21 as espécies `$1C/$1D` aprendem `$57`, na fase 18 `$27/$28` aprendem `$1E`,
  na fase 8 `$2E/$2F` aprendem `$45`, gravando no 4º espaço de golpe (`[$C933]`) só se ele estiver vazio.
* Ao terminar o movimento numa casa de terreno com id **15–32** (3º byte da tabela +2C da fase), o
  jogo mostra a mensagem de **mesmo índice** desse script:
  * **15**: centro de cura ("Please let me help you to cure"), pode repetir;
  * **18/19/20/28**: casas (falas, às vezes um item); **23/24/25**: baús (`EE 01`).
* **Mensagem 33** (`$C2B1 = $21`) é a da vitória: recompensa (insígnia) e os Pokémon que entram no
  time (`EE 02`). Ex.: fase 2 dá a Strength badge e recruta as vagas 10 e 6.
* Vencer a fase liga `$C4F7 + fase − 1`. A fase 25 termina o jogo (`$18:$4D43`).
* Retratos dos falantes (`EA xx`): tabela de texto-em-imagem `$7C:$4108`, 4×4 tiles cada.

## Desenho das unidades

As unidades **não são sprites**: viram tiles do BG. Os 4 tiles da espécie (`$FD:$4000 + espécie*64`)
são copiados para a VRAM em `$89C0 + slot*64` (`$10:$420F`). Aliados usam a paleta de BG 7 e
inimigos a 6, ambas vindas da própria fase. Só o cursor usa OAM.

## Mapa-múndi (fase 0)

O mapa-múndi é a fase 0 (mapa 32×32). O cursor não anda casa a casa: ele pula de **nó em nó** por um
grafo. Rotina de movimento: `$09:$69D8`. Grafo em **`$09:$6B7D`**, 24 bytes por nó, indexado por
`[$C529]` (nó atual), copiado para `$C530`:

| Off | Conteúdo |
|---|---|
| +0 | id do nó (u16) |
| +2 / +4 | x / y em px (u16; ÷16 = casa) |
| +6 / +8 / +10 / +12 | vizinho para **cima / baixo / esquerda / direita** (bits `$04/$08/$02/$01` de `[$FFCC]`) |
| +14 / +16 / +18 / +20 | endereço da flag exigida para andar na direção. O código faz `ld a,[bc] / or a`: 0 = livre (lê ROM `$0000` = `$FA`). Todas as travas são flags de fase vencida `$C4F7 + fase − 1` |
| +22 | ? (com o botão `$10` e o campo ≠ 0 a rotina não anda) |

* **Nó n = terreno `$20 + n`** no mapa da fase 0. Nós 1–25 = fases, 26–31 = cidades com Palaestra
  (`$3A`–`$3F`), 32 = Instituto do Doutor (`$40`), 33 = BabyAlliance (`$41`). O nó 0 é um registro
  vazio.
* Nome do lugar: texto-em-imagem `$7C:$4000`, **id = nó − 1** (transcritos em `names.lua`).
* Jogo novo: `[$C529] = [$C00C] + 1 = $20` (Instituto), lido em `$00:$03F3`.
* Exemplo conferido no PyBoy: de ChangPanCity (nó 1) para cima só anda com `$C4F7` ligado (fase 1
  vencida); ligando o byte na RAM o cursor vai para o nó 3.

**Apertar A num nó** (`$01:$547D`, valor `[$C217]` = terreno do nó):

* **Fase (`$21`–`$39`)**: se `$C4F7 + fase − 1` ≠ 0 (já vencida), **não faz nada** (fase não se
  repete). As fases **9, 11, 16, 19, 24 e 25** testam o item-chave `$C4F1`–`$C4F6` (Moon Stone, The
  pass, Miraculous flute, Red squama, Dragon tooth, Rainbow feather) e mostram a mensagem **`$22`** do
  script da fase, que tem um `E2` com a fala de "não pode entrar" e a de "pode entrar". Sem o item a
  rotina volta; com o item entra. Antes da fase 25 o jogo mostra também a mensagem 0. Entrar:
  `[$C007] = terreno − $20`, zera os eventos da fase (`$C518`, 15 bytes) e vai para a escolha do time.
* **Cidade (`$3A`–`$3F`)**: menu (`$01:$55A8`, janela `$17`) com **Palaestra**, **Prefeito** e
  **Morador**. Palaestra entra na fase `terreno − $20` (26–31), sem trava e **pode repetir** (treino).
  Prefeito e Morador mostram as mensagens 0 e 1 do script da cidade (`$3A`+), com o retrato de
  `$01:$52C8 + cidade*2` (`[prefeito, morador]`).
* **Instituto (`$40`)**, janela `$18`, retrato 3: "Surmount" = mensagem 8 (ciclo de tipos); "Raise
  information" = mensagens 0–5 (dicas).
* **BabyAlliance (`$41`)**, janela `$19`, retrato 4: "Evolve Condition" = mensagens 0–3; "Role evolve" =
  tela do time por tipo, onde a **evolução** acontece (`$01:$5630`, consome a insígnia
  `$C4EC + tipo − 1`). As insígnias **não são usadas dentro da luta**: a própria dica do jogo diz que é
  preciso ir à BabyAlliance.

**Vencer** (`$00:$0928`): grava o **número da fase** em `$C4F7 + fase − 1` (também nas Palaestras,
`$C510`+, que nenhuma trava usa), mostra a mensagem `$21` só se fase < `$1A`, e volta ao mapa
(`[$C007] = 0`). A fase 25 termina o jogo (`$18:$4D43`).

## Loja: não existe

Procurei a loja e **o jogo não tem loja nem dinheiro**:

* O save (`$01:$78C6`) grava só `$C000–$C00E` e `$C4E0–$C55E` (inventário, itens-chave, fases
  vencidas, eventos e posição no mapa). Não há contador de dinheiro nesse bloco.
* O inventário `$C4E0+` só muda em três lugares: o comando `EE 01` das falas (baús, casas e
  recompensas), o uso de item (`$01:$4EC8`) e a evolução (`$01:$5626`, consome a insígnia).
* Nenhuma fala fala em comprar, vender, preço ou dinheiro ("Yuan ... points" nas falas `$41` 5+ é a
  descrição dos golpes de cura). Os menus dos lugares (cidade, Instituto, BabyAlliance) não têm loja.
* O terreno `$1B` dentro das fases, que parecia candidato, é o evento de ensinar golpe (acima).

## Escolha do time ("One can attack NN/MM")

Ao entrar numa fase (`$10:$4000`) o jogo monta a lista (`$10:$42C8`) com o elenco recrutado
(`$AA00 + vaga*64`, byte `+$1D`) **na ordem das vagas**, 4 por página (`[$C0DD]` = última página).

* **Máximo** `[$C0DE]` = número de recrutados, limitado a **10** (as 10 posições iniciais de cada
  fase). Fase 1 com os 6 iniciais: "00/06".
* **A** (`$01:$75C4`) liga/desliga a unidade sob o cursor (byte +5 da entrada; `$31` = travada, não
  muda). Não liga além do máximo (`[$C0DF]` = marcadas).
* **START** leva o cursor ao botão "attack"; **A** nele só começa com pelo menos 1 unidade marcada
  (com 0 o jogo fica na tela).
* As marcadas ocupam as posições iniciais (`$10:$450E`) **na ordem das vagas**, não na ordem em que
  foram marcadas. Conferido no PyBoy: marcando BoBo e depois Piku, o Piku fica na posição 1 (x 26,
  y 7) e o BoBo na 2; marcando Piku e Littlecrocodile, este fica na posição 2.

## Som e música (banco `$2C`)

* **Driver** no banco `$2C`: inicialização `$2C:$4000`; atualização `$2C:$406C`, chamada uma vez por
  quadro pelo VBlank via `$00:$2CE2`. Estado em `$C380–$C3FF`. Só lê o próprio banco (e o banco 0).
* **Música**: `$00:$2CB9` grava o número em `[$FFF7]`; o driver o consome no quadro seguinte.
  Números `$01–$1F` são músicas (`$4566`); `$20+` são comandos (`$21` = silêncio).
* **Efeito sonoro**: `$00:$2CB5` grava em `[$FFF8]` (`$4609`). O jogo só usa o `$1B` (cursor dos
  menus, `$01:$59E3` e vizinhos); comandos dos scripts de animação (`$00:$2284`/`$228D`) também tocam
  música/efeito com um byte embutido.
* **Quem toca o quê**: música de cada fase em `$00:$2C85 + fase` (fase 0 = mapa-múndi `$16`, fase 1
  = `$17`…); abertura `$0B` (quadro 86, depois de `$09`); escolha do time e menus das cidades `$0D`;
  animação de ataque `$06` (toca uma vez, ~16 s); vitória `$14`; final `$15`.
* Um ciclo de música termina quando o estado `$C380–$C3FF` se repete: `$0B` repete a cada 34,3 s,
  `$16` a cada 42,9 s, `$14` tem 8,6 s de introdução e depois repete.
* O motor **roda esse driver ao vivo** num interpretador SM83 (`engine/src/util/sm83.lua`) e
  sintetiza o APU (`engine/src/audio/apu.lua`). Conferido contra o áudio do PyBoy: na abertura,
  86% das notas (janelas de 50 ms) coincidem, já alinhadas no tempo.

## Motor de texto e ROM traduzida (`engine/src/romhack/`)

**Exibição das falas** (`ROM0:$3296` liga `[$C280]` e chama `$39:$4000`):

* `$39:$4000` (Text_Init) escolhe a caixa pelo script: `$39:$407D[script]` → configuração de 8 bytes
  em `$39:$40ED` = `[VRAM lo, hi, largura, ?, linhas, ?, velocidade, ?]`. Intro (`$20`) = 16 colunas
  sem retrato (`$9C22`); fases `$21–$39` = 12 colunas ao lado do retrato (`$9C26`), exceto as
  mensagens `$17–$1B`, forçadas para 16 colunas em `$9C22`; cidades, Instituto e BabyAlliance
  (`$3A–$41`) = 12 colunas (`$9C86`). Todas com 4 linhas.
* `$39:$4125` (Text_Char): byte → tile pela tabela `$39:$4226` (128 entradas; `A–Z` = `$C0–$D9`,
  `a–z` = `$DA–$F3`, `0–9` = `$01–$0A`, `. , : ; ! ? -` em `$F4–$FA`, espaço `$FC`, `'`/`` ` `` = `$FD`)
  e grava o tile direto no mapa (atributo `$0E`: banco 1 da VRAM, paleta 6). Quebra de linha **só pela
  coluna** (no meio da palavra); com a caixa cheia espera o botão e rola uma linha (`$39:$41C5`).
* Fonte: 64 tiles em `$39:$4365`, copiados para o banco 1 da VRAM em `$8C00` (`$39:$42A6`); fundo
  cor 2, letra cor 0. Ela só é usada pelo motor de texto.
* Comandos: `E8 xx` grava a velocidade do texto `[$C2B7]` (`ROM0:$36B5`); `EA xx` troca o falante
  (`ROM0:$370B`). `EE 03` tem 6 bytes (`EE 03 a16 v16`), apesar de a tabela dizer 4.
* Índice: `$5D:$4000` tem um u16 por script (75 scripts; os vazios apontam para `$4096`), cada um
  uma lista de entradas `[lo, hi, banco, 00]` (1786 entradas, 680 trechos distintos alcançáveis).

**Bancos livres:** o jogo só usa bancos com o bit 1 desligado; todos os outros (`$02, $03, $06, $07,
… $42, $43 …`) são zerados. O fim do banco 0 (`$3F6B–$3FFF`) também é zerado (último código em
`$3F6A`).

**Conversão** (`Patcher.build`, botão "Gerar ROM traduzida" ou `love engine --build-rom saída.gbc`):

1. Falas: cada trecho alcançável pelo índice é regravado nos bancos livres a partir de `$42`
   (um grupo ligado por desvios `E2` fica no mesmo banco, porque os ponteiros do `E2` são do
   banco atual) e o índice é reapontado. Páginas traduzidas (`translation_pt.lua`) vão em
   MAIÚSCULAS e quebradas por palavra para a largura da caixa (espaços até o fim da linha); os
   comandos antes do texto da página continuam antes, os demais (EE) vão depois. O texto não traduzido
   é copiado em maiúsculas. Ocupa ~22 KB.
2. Acentos: como nada mais usa minúsculas, os glifos `a–m` viram `Á À Â Ã É Ê Í Ó Ô Õ Ú Ç Ü`,
   desenhados a partir da maiúscula da própria fonte (corpo em 5 linhas + acento em 2; Ç com cedilha
   na linha 8; Í com serifas, senão parecia "1").
3. Autocura do inimigo (`$18:$6968`): `ld de,$C98E / call $2B12` vira `call $3F80`, rotina nova
   que soma a cura e limita a `[$C992]` (HP máx da cópia da unidade em `$C980`).
4. Nomes em imagem (tabela da seção "Texto em imagem"): golpes (`$79`), espécies (`$F9`, nome
   oficial), lugares (`$7C:$4000`), itens-chave (`$7C:$40A8`, id da imagem = item + 1), ginásios
   (`$7C:$40C4`) e objetivo da fase (`$7C:$40DC`, 18×2 tiles; os 2 primeiros são o ícone e ficam) são
   redesenhados no mesmo lugar com a fonte própria do projeto (`src/romhack/pixelfont.lua`), nas
   cores da imagem original (fundo = cor mais comum, letra = a segunda). Ordem de tentativa: uma linha
   na fonte normal (7 px), duas linhas em versalete de 5 px, uma linha em versalete, depois sem
   espaço entre letras; "Onda Eletromagnética" vira "Onda Eletromag.".
5. Palavras dos menus (ver "Menus" abaixo): achadas automaticamente na região (faixas de tinta),
   apagadas e reescritas na mesma linha de base; os tiles da região são refeitos (célula vazia →
   tile vazio, célula igual a um tile da moldura → moldura, resto → ids que só aparecem dentro da
   região, deduplicados) e o espelhamento das células regravadas é zerado.
6. Checksum global recalculado (`$14E–$14F`); o cabeçalho não muda.

**Menus** (mapas de tela no banco `$BD`: ids de tile `w×h` seguidos dos atributos `w×h`; atributo
`$0E/$0F` = banco 1 da VRAM + paleta, bit 5/6 = espelho — o original deduplica tiles espelhando).
Ids `< $20` = moldura comum (`$40:$4000 + id*16`); ids `≥ $20` vêm do bloco de cada menu:

| Tela | Mapa | Bloco (id → base + id*16) | Palavras |
|---|---|---|---|
| menu da unidade | `$BD:$40F0` 6×12 | `$40:$4340` | Attack, Skill, Goods, State, Rest |
| menu do mapa | `$BD:$4C18` 9×12 | `$40:$5E10` | Team show, Save, Load, Win Condition, End (tela `$09` do script `$BC`: janela em wy `$30`, cursor y `$38..$78` de 16 em 16, x `$5C`; aberto com A numa casa vazia; Win Condition = tela `$0F`, 20×8) |
| escolha do time | `$BD:$63E8` 20×18 | `$41:$5770` | One can attack; attack, Change ←→ Page (números escritos em tempo de execução) |
| Instituto | `$BD:$5E48` 20×9 | `$41:$4AC0` | Surmount, Raise information |
| BabyAlliance | `$BD:$5FB0` 20×9 | `$41:$4AC0` | Evolve Condition, Role evolve |
| cidade | `$BD:$5CE0` 20×9 | `$41:$4AC0` | (nome do Palaestra = imagem `$7C:$40C4`), Mayor, Resident |
| submenu de itens | `$BD:$4180` 6×6 | `$40:$4340` | Recover goods, Special |
| itens de cura | `$BD:$43A8` 20×18 | `$40:$49B0` | cabeçalho + 6 nomes (o "×" e os dígitos têm contorno preto e ficam) |
| pedras | `$BD:$4678` 20×18 | `$40:$5160` | cabeçalho + 6 nomes |
| tipos (Team show) | `$BD:$4CF0` 20×18 | `$40:$6440` | Player Team show, Celerity, Defence, Balance, Super power, Strength |
| objetivo | `$BD:$5470` 20×8 | `$40:$7AD0` | Win Condition (o texto do objetivo é a imagem `$7C:$40DC`) |
| aviso de turno | `$BD:$55B0` / `$BD:$5600` 10×4 | `$48:$4000` | Enemy action / Player action |

| salvar / carregar | `$BD:$6DB8` / `$BD:$7088` 20×18 | `$41:$74F0` | SELECT SAVE FILE / SELECT LOAD FILE (letra branca com contorno preto; os dois mapas dividem os tiles, por isso o grupo é processado junto) |

**Título** (depois de uma derrota): mapa `$19:$5022` (letras Unown, sem texto) e opções em sprites 8×16
(LCDC `$C7`). "LOAD"/"EXIT": 7 sprites (56×16) cada, tiles seguidos cima/baixo em `$85:$5510` e
`$85:$56C0`, com um segundo quadro de animação em `$85:$55F0` e `$85:$57A0` (preenchimento cor 1,
contorno cor 2, sombra cor 3). Botões "NEW GAME"/"RECORDS": 10 sprites (80×16) em `$8C:$5310` e
`$8C:$5460`, letra cor 3 de 6 linhas nas linhas 5–10. A vitória não tem tela própria (vai direto à fala
da recompensa) e a evolução só mostra nomes em imagem e rótulos de status.

O número de tiles livres limita o tamanho do texto novo (por isso "Objetivo" e não "Condição de
vitória"). O status da unidade (LV, EXP, HP, SP, ATK, AGI, HIT, MOV) fica como está.

**Descrições** de golpes e itens: script `$46` (golpes, 1 a `$58`) cuja lista continua na dos
scripts `$47` em diante (itens, pedras, itens-chave, insígnias) — as listas do índice se sobrepõem,
então o conversor lê cada lista até uma entrada inválida ou o começo do texto (`$5D:$50DC`) e
atribui cada entrada à lista que começa mais perto. As traduções seguem modelos com os números do
próprio texto (`src/romhack/descriptions.lua`). A caixa das descrições usa outra tabela de
caracteres (minúsculas viram maiúsculas), então nela os acentos aparecem sem acento.

## Animação de batalha (`ApplyAttack`, `$09:$62EC`)

A cena de ataque foi **decodificada e reimplementada em Lua** (`engine/src/anim/attack.lua`): cada
rotina abaixo foi transliterada com as variáveis nos mesmos endereços da WRAM, e uma corrotina faz o
papel da espera de VBlank. Os dados (scripts, quadros, tiles, cenários) vêm de um recorte da ROM do
jogador gravado no cache (`generated/attack.bin`, ~470 KB, `engine/src/anim/slice.lua`). O código
original continua rodando no executor de GBC (`engine/src/emu/`) só como referência: os testes
comparam objetos, OAM e VRAM **quadro a quadro** entre os dois (turno do aliado, do inimigo, erro,
golpe especial, desmaio, chefe, vários terrenos: iguais), e o desenho em LÖVE é comparado pixel a
pixel com o do executor.

* **Entradas**. `$C900` = registro do **aliado** e `$C980` = do **inimigo** (cópias de 128 bytes no
  formato da SRAM; `+$0C` SP, `+$0E` HP, `+$10/+$12` máximos, `+$46` HP mostrado), nos dois turnos
  (`$01:$4368` aliado ataca, `$01:$6B0E` IA). `$C1D0`/`$C1D3` = `$7C` + espécie do aliado/inimigo.
  `$C1D1` = ação do aliado, `$C1D4` = ação do inimigo (2 = ataque normal; golpe = tabela
  `$09:$6F4D[espécie]` → 4 pares `[golpe, animação]`, sem par igual vale o último; 1 = não age).
  `$C1D2/$CD03` = reação/dano no aliado, `$C1D5/$CD43` = no inimigo (`$0C` acertou, `$10` errou;
  sorteios `$38:$73C4`/`$741B`). `$C008` = 1 no turno inimigo. `$C220` = terreno.
* **Fluxo** (`$01:$63B9`): cenário `[$C080] = $38:$7139[terreno] + $2F` carregado por `$00:$2CEB`;
  depois `$09:$62EC` (aliado ataca) ou `$09:$64C7` (inimigo ataca). Cada ação tem duas fases:
  animação `n` (aproximação, câmera em X=`$90`) e `n+1` (golpe, câmera em 0) com o alvo reagindo
  com `$C1D5`/`$C1D2`; depois o dano (`$09:$695F`/`$6993`, mínimo 0 por `$00:$3ED9`), a barra de HP
  (`$08:$4BEC`), o desmaio (`$09:$66AA`: animação `$12` por 200 quadros e fim) e o contra-ataque
  com os papéis trocados. Música da cena: `$01:$64AB` (`$01:$64DF[espécie]`, chefes `$15`/`$38`).
  Entre as fases, 20 quadros de espera (`$00:$2A12`). No turno inimigo, escrever `IF = 3`
  (`$09:$654D`) dispara um VBlank extra na hora.
* **Objetos** (`$00:$1D7E`): 12 em `$DB00 + $40*n`. 0 = esquerda (`X=$20`, inimigo), 1 = direita
  (`X=$B0`, aliado, virado), montados em `$09:$676A`; 2–11 = efeitos. Campos: `+$00` ativo, `+$01/+$03`
  Y/X (16 bits), `+$05` quadro, `+$06/+$07/+$09` atributo OR / base do tile / soma no atributo,
  `+$0A` espera, `+$0F` personagem, `+$10` animação (0 = parado, não atualiza), `+$12` virado,
  `+$13–$24` caixas, `+$26` já acertou, `+$27–$29` banco/ponteiro do script, `+$2A–$2C` tiles do
  quadro a carregar, `+$2D/+$2E` destino na VRAM, `+$2F–$31` último carregado, `+$33` banco da VRAM.
  Script: `$04:$4000 + personagem*4` → `[lista, banco]`, lista de ponteiros por animação; passos de
  4 bytes `[dy, dx, quadro, espera]` (dx negado se virado; `$FF $FF` desativa o objeto). Comandos
  depois de um passo (`$00:$20AC`, tabela `$20C1`), usados pelas animações: `$80 n` vai para a
  animação n; `$81` vira; `$85 c dy dx dxv ? anim ?` cria o efeito c (8 bytes); `$8C` espera o sinal
  (`[$C255]`, repete o passo anterior); `$8E` dá o sinal.
* **Criação** (`$00:$3B22`): modelo de 16 bytes em `$1C:$4000 + personagem*16` (personagem,
  animação, virado, …, atributo, base do tile, destino VRAM, …, caixa, banco VRAM) na posição
  `$C208/$C20A`, no primeiro objeto livre.
* **Caixas e colisão**: `$2D:$423F` calcula a cada passo duas caixas a partir de
  `$2D:$43ED[personagem]` (10 bytes por quadro): golpe (`+$13–$1A`) e corpo (`+$1D–$24`). Na fase do
  golpe (`[$C439]` = 1 alvo objeto 0, = 2 alvo objeto 1; `$2D:$4BE9`/`$4DCB`), um efeito que encosta
  no corpo do alvo muda a reação do alvo para `$0D`/`$0F` (sorteio `[$C035]`), consulta
  `$2D:$4FA7[personagem][animação]` e cria a faísca `$79`.
* **Quadros**: metasprite `$80:$4000 + personagem*4` → `[ptr, X base, banco]`, lista por quadro com
  `[n, ?]` e n entradas `[dy, dx, dx virado, tile, atributo]` (`$00:$1BD4`; tile + `+$07`, atributo
  `| +$06` `+ +$09`, bit 5 trocado se virado; objeto fora de -32..`$B0`/`$C0` não aparece; `+$1C`
  pisca). A ordem dos objetos na OAM alterna a cada quadro (`$1A8E`/`$1AA8`). Tiles:
  `$80:$4400 + personagem*4` → `[banco, ?, ptr]`, quadro*4 → `[banco, ?, ptr]` dos dados (16 bytes de
  cabeçalho, tamanho big-endian nos 2 primeiros), copiados por HDMA no VBlank (`$00:$2572`).
  Paletas de sprite 0/1 = espécie do aliado/inimigo (`$38:$716B`, `$38:$71BC[espécie]`, 8 bytes).
* **Cenário** (`$00:$2D35`, scripts no banco `$BC`, `$BC:$4000[id]`): lista de comandos `[rotina,
  parâmetros]`: `$2DA0` escreve na memória (`[endereço, valor, flag]`, até `$FF`), `$2DDB` HDMA
  (12 bytes), `$2E3B` paleta, `$2EB0` bloco do mapa (linhas×colunas), `$BC:$5940` desvio, `$322B`
  número (`$BC:$5EFF` + `$B5:$402E`, dígitos do estilo `$BC:$60A2`; zero à esquerda usa o mesmo tile
  do zero), `$BC:$5D49` barra (tile cheio `$13`, parcial `$0B + n`). Cenários `$2F–$37`: paletas do
  banco `$49`, tiles do `$4C`, mapa 20×18 na janela (`$9C00`); painel com HP/SP em `$BC:$546C`
  (redesenhado por `$BC:$54BE`/`$54E8`). Escritas que esperam o LCD (`$00:$2B3A`) fazem ~640 por
  quadro.
* **Fim** (`$00:$086A`): a cena acaba 100 quadros depois que os objetos 0 e 1 estão parados
  (animação < 2 ou inativos). Algumas combinações artificiais nunca terminam (no original também);
  o motor corta em 1 minuto.
* O motor monta essas entradas com o resultado que já calculou, roda a cena a 60 quadros/s
  (~0,1 ms por quadro no PC) e só depois anuncia dano e EXP; START/A/B pulam. O desenho
  (`engine/src/anim/render.lua`) usa uma imagem para o cenário (atualizada por célula) e atlas de
  tiles por banco/paleta para os sprites, com o limite de 10 sprites por linha do hardware.

## Abertura e título

**Abertura** (rotina `$11:$4000`, cena em `[$C1CC]`, 5 cenas): tiles `$11:$40AC + n*4` =
`[tamanho, ptr]` (copiados para `$9000` e continuando em `$8800`), mapa `$11:$40C4 + n*2` e atributos
`$11:$40D0 + n*2` (20×12, em `$9800`), paletas de BG `$19:$40F7 + (n-1)*64`. Embaixo, a caixa de texto
(20×6, janela em `WY=$60`) escreve o trecho n do script `$20` letra a letra (~16 letras/s no PyBoy) e
rola linha a linha; terminada a cena, passa para a próxima. Depois vem o título.

**Título**: tiles `$38:$490F` (`$9000`), `$38:$510F` (`$8800`), `$38:$590F` (banco 1, `$9000`), mapa
`$38:$45FF` e atributos `$38:$4767` (20×18), paletas de BG `$38:$48CF`. Botões NEW GAME / RECORDS =
10 sprites 8×16 cada em `$8C:$5310` / `$8C:$5460` (paletas de OBJ `$38:$5B9F`: 0 = escolhido, 1 = não),
em (8, 72) e (0, 88); o escolhido anda 8 px para a direita.

O motor importa as 5 cenas e o título como imagens (`generated/intro_N.png`, `title.png`, botões em
português da ROM traduzida) e mostra a abertura antes do título (`engine/src/ui/opening.lua`);
NOVO JOGO começa uma campanha nova (pede confirmação se houver jogo salvo) e RECORDES continua.

## Telas de interface (scripts do banco `$BC`)

Todas as telas de interface do campo são **scripts do mesmo interpretador do cenário da batalha**
(`$00:$2D35`; tabela `$BC:$4000[id]`): gravam variáveis (`$2DA0`: posição da janela em
`$C242/$C243`, número de opções em `$C090`, **posições do cursor** em `$C0B2 + 2i` = y e
`$C0B3 + 2i` = x + 8, coordenadas de tela; a pokébola do cursor tem 16×16, conferido na OAM do
PyBoy), carregam o bloco de tiles (`$2DDB`), copiam o mapa do banco `$BD` para a janela (`$2EB0`),
escrevem números (`$322B`) e barras (`$5D49`) lidos da WRAM e carregam nomes e retratos em imagem
por id (`$2F25–$2FF4` → `$00:$300B`: tabela `[banco, 0, ptr]`, cópia para o banco 1 da VRAM):

| id | tela | lê |
|---|---|---|
| `$01` | painel da unidade (20×6, embaixo) | `$C905` espécie (retrato `$F4`, nome `$F9`), `$C906` tipo, `$C902` nível, `$C903` EXP, `$C90E` HP, `$C90C` SP, `$C274` P/C |
| `$02` | menu de ação (Attack, Skill, Goods, State, Rest) | — |
| `$03` / `$1D` | submenu de itens | — |
| `$04` | golpes (4 vagas em 2 colunas) | `$C924 + 5i` |
| `$05` / `$06` | itens de cura / pedras | contagens `$C4E0–$C4EB` |
| `$07` | Estado da unidade | registro `$C900` (o sprite grande é um objeto) |
| `$09` / `$1C` | menu do mapa | — |
| `$0A` / `$0B` | Team show (tipos / lista) | — |
| `$13` | caixa de fala com retrato `$C270` (tabela `$7C:$4108`); o motor usa a moldura da `$0E` para falas sem retrato | — |
| `$0F` | objetivo da fase | `$C274` |
| `$10` / `$11` | avisos "Enemy action" / "Player action" | — |
| `$0D` | "Are you sure to end this turn? Yes / No" (cursor em `$C0B2`: x `$28`/`$58`) | — |
| `$0E` | "Quit without save? Yes / No" | — |
| `$12` | variante da `$0D` que carrega o bloco `$40:$7A60` em `$9000` por cima dos ids `$00–$07` (o Yes/No sai quebrado) | — |
| `$15` | **bônus de nível**: LV, HP, SP, ATK, HIT, AGI, MOV com "+n" e Points | registro `$C900`, bônus `$CD0A–$CD0E`, pontos `$CD14`, golpe aprendido `$C1DD` |
| `$16` | HP/SP dos dois lados | `$C90E/$C98E`... |
| `$17–$19` | cidade, Instituto, BabyAlliance | `$C274`, `$C270` |
| `$1B` | escolha do time | `$DF82 + $10i` |
| `$1E` / `$1F` | itens-chave / insígnias | `$C4F1–`, contagens |
| `$20` | nome do lugar | `$C27D` |
| `$21` / `$22` | salvar / carregar | `$C0F0–` |
| `$2F–$37` | cenários da batalha | — |

**Conversor e a `$0D`**: o bloco `$40:$7260` vai inteiro para `$9000` (ids `$00–$7F`, sem a moldura
comum) e `$40:$7A60` para `$8800` (ids `$80–$87`); as três telas `$0D/$0E/$12` dividem os tiles das
letras, então o texto novo ("Encerrar o turno?", "Sim", "Não") usa os ids do bloco que nenhum dos
três mapas usa e fica numa linha de tiles só. Não achei onde o original abre a `$0D` (o "End" do menu
do mapa encerra direto); o motor a mostra ao encerrar o turno com Pokémon que ainda não agiram.

O motor desenha essas telas pelo próprio interpretador (`engine/src/ui/gbui.lua`, HUD em
`engine/src/ui/gbhud.lua`), com o registro da unidade escrito em `$C900` e as paletas de BG da fase;
em português, os dados vêm da ROM traduzida pelo conversor. Texto das falas com a fonte `$39:$4365`
(tabela `$39:$4226`).

## Emulação para pesquisa

`tools/run_headless.py` + `tools/play.py` rodam a ROM no **PyBoy** sem janela
(`pip install pyboy`). O `play.py` carrega um save state, aplica uma sequência de botões
(`"up*2 wait60 a"`), salva o novo state, um screenshot e o dump da WRAM. Rota até a 1ª batalha:
intro (≈40×A) → menu do Doctor Institute (B×6) → `up` (Ifleaf town) → A → "If leaf Palaestra" →
escolher unidades com A/↓ → START.

## Próximos passos

1. ~~Stats das espécies~~ ✅ ~~Inimigos e posições por fase~~ ✅. ~~Golpes, itens, eventos e falas~~ ✅.
   ~~Mapa-múndi~~ ✅. ~~Loja~~: não existe no original (ver **Loja**).
2. ~~Animações de batalha~~ ✅: executadas do código original (ver **Animação de batalha**).
3. ~~Formato dos mapas~~ ✅. Falta: confirmar a tabela de terreno (+2C) e a paleta de cada sprite de unidade.
4. ~~Paletas de BG das fases~~ ✅ (rotinas `ROM0:$2C56`/`$2C42`). ~~Retratos~~ ✅: as paletas de BG
   4–7 de toda fase são as da interface; os retratos (luta e diálogos) usam a **paleta 4**
   (`ff7f df02 3a01 2804`, branco/amarelo/laranja/marrom), a mesma para todas as espécies.
5. ~~Fórmulas de dano, acerto, EXP, movimento, nível, evolução e golpes~~ ✅ ~~IA original~~ ✅.
   ~~Regra exata do contra-ataque~~ ✅.
6. ~~Som~~ ✅ (driver `$2C` rodando ao vivo no motor).
