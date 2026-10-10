# Pocket Monster Saphire — recomp

Uma recriação de **Pocket Monster Saphire** (Game Boy Color, Sintax, 2003), o RPG de estratégia
pirata com Pokémon, feita a partir da engenharia reversa do jogo original — no espírito do
[Gen1Recomp](https://github.com/bryanthaboi/gen1recomp). O jogo roda num motor novo (LÖVE2D) que lê
**a sua própria ROM**, com tradução para o português, correções e melhorias. A mesma ferramenta também
gera uma **ROM traduzida** para jogar no Game Boy Color/Advance.

> Este projeto não inclui a ROM nem nada extraído dela. Você precisa da sua cópia do jogo:
> *Pocket Monster Saphire (Unlicensed, English) [Fixed]*, SHA-1
> `9fa7da61c61d684f39e43d6899a68309ba8607b3`.

## O que foi feito

- **O jogo inteiro roda no motor novo**: campanha com as 25 fases e os 6 ginásios, mapa-múndi com
  as travas do original, cidades, Instituto e BabyAlliance (evolução), escolha do time, itens,
  eventos das fases, recrutamento, subida de nível, golpes especiais e save.
- **Regras tiradas do código original** e conferidas contra o jogo rodando em emulador: movimento,
  acerto, dano, contra-ataque, EXP, evolução e a IA dos inimigos (veja
  [`docs/FINDINGS.md`](docs/FINDINGS.md), com o endereço de cada regra).
- **Música e efeitos originais**: o driver de som da ROM roda ao vivo dentro do motor.
- **Animações de batalha originais**: a cena de ataque do jogo foi decodificada e refeita no motor
  (conferida quadro a quadro com o código original), com o resultado calculado pelo motor. Leve o
  bastante para rodar também no 3DS.
- **Tradução completa para o português** (falas, menus, golpes, lugares e itens); dá para trocar
  para o inglês original a qualquer momento.
- **Conversor de ROM**: gera uma ROM de GBC já traduzida para jogar no emulador ou no cartucho.

## O que tem de novo em relação ao original

| | Original | Recomp |
|---|---|---|
| Idioma | inglês "de bootleg" | português (com acentos) ou o inglês original, trocando com N |
| Nomes dos Pokémon | "piku", "BoBo", "Dollysheep"... | nomes oficiais (Pichu, Pidgey, Mareep...) ou os do jogo |
| Prévia do ataque | não tinha | dano, chance de acerto e contra-ataque antes de confirmar |
| Desfazer movimento | não tinha | volta a unidade antes de agir |
| IA dos inimigos | a original (só ataque normal, sem planejar) | original ou **melhorada** (usa golpes, foca quem pode derrubar, cura aliados) |
| Bug da autocura do inimigo | passa do HP máximo | corrigido (opcional) |
| Turno inimigo | ritmo fixo | normal (unidades andando como no original) ou rápido |
| Tela | 160×144 | janela grande, tela cheia ou as duas telas do 3DS |
| Animações de batalha | — | as originais, que podem ser puladas (A, B ou START) |
| Abertura e título | inglês | a abertura e o título do jogo, em português (pula com START) |
| Menus e falas | inglês | as telas do próprio jogo (painel, menu de ação, golpes, itens, Estado, bônus de nível, falas com retrato), em português, clicáveis |

Na **ROM traduzida** (para GBC/GBA) entram: todas as falas em português, os nomes em imagem
(golpes, Pokémon, lugares, itens, ginásios), os menus, a tela de título, as descrições de golpes e
itens e a correção da autocura. As outras melhorias dependem do motor novo e ficam só nos executáveis.

## Como jogar

Baixe o arquivo da sua plataforma na página de
[**Releases**](https://github.com/theusrsilva/pocket-monster-saphire-decomp/releases).

### Windows

1. Baixe `SaphireRecomp-<versão>-windows-x64.zip` e extraia a pasta.
2. Abra `SaphireRecomp.exe`. Se o Windows avisar ("O Windows protegeu o computador"), clique em
   **Mais informações → Executar assim mesmo** (o executável não é assinado).
3. Na tela de configuração, em **ROM**, aperte Enter e digite o caminho do `.gbc` — ou arraste o
   arquivo para a janela. A ROM é conferida e importada uma vez só.
4. Escolha as opções e **Jogar**.

### Linux

1. Baixe `SaphireRecomp-<versão>-linux-x86_64.AppImage`.
2. Dê permissão de execução e abra:
   ```sh
   chmod +x SaphireRecomp-*-linux-x86_64.AppImage
   ./SaphireRecomp-*-linux-x86_64.AppImage
   ```
3. Configure a ROM na tela de configuração (passos 3 e 4 do Windows).

### macOS

1. Baixe `SaphireRecomp-<versão>-macos.zip` e extraia o `SaphireRecomp.app`.
2. Como o app não é assinado, abra com **clique direito → Abrir** na primeira vez (ou rode
   `xattr -dr com.apple.quarantine SaphireRecomp.app` no Terminal).
3. Configure a ROM na tela de configuração (passos 3 e 4 do Windows).

### Nintendo 3DS

1. Baixe `SaphireRecomp-<versão>-3ds.3dsx` e copie para a pasta `/3ds/` do cartão SD (precisa do
   Homebrew Launcher).
2. A importação da ROM é lenta no console: importe primeiro no PC (abrindo a versão de PC uma vez
   com a sua ROM) e copie a pasta de dados `saphire-recomp` (com a subpasta `generated/`) para a
   pasta de dados do LÖVE Potion no cartão SD.
3. O mapa fica na tela de cima e os menus e falas na de baixo. A confirma, B volta, START encerra o
   turno, X troca o idioma, Y liga/desliga o som. Ainda não foi testado em hardware.

Pasta de dados no PC: `%APPDATA%\saphire-recomp` (Windows), `~/.local/share/saphire-recomp`
(Linux) e `~/Library/Application Support/saphire-recomp` (macOS).

### Game Boy Color / Game Boy Advance (ROM traduzida)

1. Abra a versão de PC, configure a sua ROM e escolha **Gerar ROM traduzida (GBC/GBA)**.
2. O arquivo `Pocket Monster Saphire (PT-BR).gbc` é criado ao lado da ROM original.
3. Jogue num emulador de Game Boy Color (ou de GBA que rode jogos de GBC) ou grave num flashcart de
   Game Boy. Ela foi conferida em emulador; ainda não em cartucho.

### Pelo código-fonte

Precisa do [LÖVE 11.x](https://love2d.org). Coloque a ROM em `rom/saphire.gbc` e rode:

```sh
love engine                      # abre a tela de configuração
love engine --test               # testes contra valores do jogo original
love engine --build-rom saida.gbc   # gera a ROM traduzida sem abrir a tela
```

O manual completo está em [Manual do jogo](#manual-do-jogo). Teclado ou mouse: setas (ou clique) movem, Z/Enter/clique confirma, X/botão direito volta, Esc encerra o
turno, N troca o idioma, M liga/desliga a música, F11 tela cheia, F1 abre a configuração. Os botões no
canto da tela também ligam a música, a tela cheia, minimizam e abrem a configuração. Mais detalhes em [`engine/README.md`](engine/README.md).

## Manual do jogo

### A história

A Gangue Rocket roubou a insígnia perdida e saqueou os Pokémon do mundo. O Ash (Xiaozhi) e os
amigos tentaram detê-los e foram presos. Cabe ao **Pikachu** e aos companheiros atravessar a região,
vencer as batalhas, encontrar os Pokémon espalhados e libertar os capturados.

### O objetivo

O jogo é uma campanha de **estratégia por turnos**: 25 fases no mapa-múndi, mais 6 ginásios nas
cidades. Cada fase se vence **derrotando todos os inimigos**; perde-se quando todos os seus Pokémon
caem (aí dá para tentar de novo). Vencer a fase 25 termina o jogo. O progresso é salvo sozinho ao
vencer e ao sair de cada lugar.

### Abertura e título

A abertura conta a história (START pula). No título, **NOVO JOGO** começa do zero (se já houver um
jogo salvo, o jogo pede confirmação) e **RECORDES** continua de onde parou.

### O mapa-múndi

O cursor anda de **lugar em lugar** pelas estradas (setas ou clique no lugar vizinho); A/Enter entra.

- **Fases (1 a 25)**: abrem em ordem. Uma fase vencida não se repete. As fases 9, 11, 16, 19, 24 e
  25 só abrem com um **item-chave** (Pedra da Lua, Passe, Flauta Milagrosa, Escama Vermelha, Dente de
  Dragão e Pena Arco-Íris), que se ganha em fases anteriores.
- **Cidades**: o **Ginásio** é uma luta de treino que pode ser repetida à vontade (bom para ganhar
  nível); o **Prefeito** e o **Morador** contam histórias e dão dicas.
- **Instituto do Doutor** (onde o jogo começa): explica as **vantagens de tipo** e dá dicas.
- **BabyAlliance**: explica as **condições de evolução** e é onde os Pokémon **evoluem** (veja abaixo).

### Antes da luta: o time

Ao entrar numa fase escolhe-se quem luta (até o número que a fase permite, no máximo 10). Marque com
A/clique e vá em **Lutar** (START/Esc leva direto ao botão). Os escolhidos entram nas posições
iniciais na ordem da lista.

### A batalha

Cada turno tem duas partes: **você move todos os seus Pokémon** e depois **os inimigos agem**.

1. Escolha um Pokémon seu (A ou clique). Aparece em azul até onde ele pode andar.
2. Escolha a casa de destino (ou a própria casa para não andar). Ele vai andando até lá.
3. No **menu de ação** (as cinco opções sempre aparecem; as que não dão para usar ficam apagadas):
   - **Atacar**: ataque normal num inimigo dentro do alcance.
   - **Golpe**: golpe especial (gasta SP; alguns curam um aliado). A caixa de baixo mostra o poder,
     o custo e o alcance.
   - **Itens**: de **recuperação** (Doce +200 HP, Suco +200 SP, Pão +500 HP, Leite +400 SP, Bolo HP
     cheio, Mel +600 SP) ou **especiais** (pedras que aumentam de vez: Vida HP máx. +10, Espírito SP
     máx. +5, Chamas ATK +2, Olho PRE +2, Fênix ESQ +2, Voo MOV +2 até 15).
   - **Estado**: todos os números do Pokémon e os golpes dele.
   - **Esperar**: termina a vez dele sem agir.
4. Quando todos tiverem agido, o turno passa sozinho. Para encerrar antes, aperte **Esc/START** (o
   jogo pergunta "Encerrar o turno?").

B/X ou botão direito volta um passo; com a opção **Desfazer movimento** ligada, dá para voltar o
Pokémon para onde estava antes de agir. Passar o cursor sobre qualquer unidade mostra o painel dela
embaixo (nível, EXP, HP, SP).

**Movimento.** Cada Pokémon tem pontos de **MOV**. Cada tipo de terreno custa um tanto, que muda
conforme a espécie: os voadores passam por cima de árvores e água, os terrestres andam pouco na
floresta. Não dá para atravessar inimigos.

**Combate.**

- **Chance de acerto** = 100 + PRE do atacante − ESQ do defensor, ajustada pelo tipo.
- **Dano** = ATK do atacante (+ o poder do golpe especial). Não existe defesa: o dano é inteiro.
- **Tipos**: Agilidade > Equilíbrio > Força > Superpoder > Defesa > Agilidade. Contra o tipo de que
  é forte, o dano vale 1,5× e acerta mais; contra o tipo de que é fraco, vale metade e acerta menos.
  O painel mostra o ícone do tipo; no Instituto o Doutor explica o ciclo.
- **Contra-ataque**: quem é atacado e sobrevive revida na hora. Com um golpe de ataque que alcance o
  atacante, revida com ele; senão, só revida com ataque normal se estiver colado (distância 1).
  Atacar de longe, com alcance maior que o do inimigo, evita o contra.
- A opção **Prévia de ataque** mostra, antes de confirmar, o dano, a chance de acerto e o contra.

**Casas e baús.** Parar numa casa ou baú pela primeira vez na fase dispara uma fala e, às vezes, um
item. O **centro de cura** (a casa com a cruz) enche HP e SP sempre que um Pokémon para nele.

**Experiência e nível.** Acertar dá EXP e derrubar dá mais; quanto maior o nível do alvo em relação
ao seu, mais EXP (alvo de nível menor dá só 1). Com **100 EXP** o Pokémon sobe de nível: HP e SP
sobem, ATK, PRE e ESQ podem subir, e na **tela de bônus** você escolhe um atributo para ganhar um
extra (HP, SP, ATK, PRE ou ESQ). HP e SP enchem ao subir. Cada forma tem um nível máximo (20, 40 ou
99); no máximo, só evoluindo.

**Recrutar.** Vencer certas fases traz novos Pokémon para o time (até 20 no elenco).

**Os inimigos.** Na IA original, o inimigo cura a si mesmo quando está com metade do HP (se tiver o
golpe de cura), ataca quem estiver colado e, se não houver ninguém, anda até o seu primeiro Pokémon
que conseguir alcançar; o chefe da fase não sai do lugar. A **IA melhorada** (opcional) usa golpes,
escolhe quem pode derrubar e foge do contra-ataque.

### Evolução

Cada fase vencida dá uma **insígnia** de um tipo. Na **BabyAlliance**, em "Evoluir", escolha um
Pokémon do mesmo tipo da insígnia para evoluí-lo: a espécie avança, os atributos ganham um bônus, HP
e SP enchem e as formas finais aprendem um golpe novo. A insígnia é gasta.

### Controles

| Ação | PC (teclado) | PC (mouse) | 3DS |
|---|---|---|---|
| Mover cursor / escolher | setas ou WASD | clique | direcional |
| Confirmar | Z, Enter ou Espaço | clique | A ou tocar na tela de baixo |
| Voltar / cancelar | X ou Backspace | botão direito | B |
| Encerrar o turno / pular cena | Esc | — | START |
| Trocar idioma (PT/EN) | N | — | X |
| Música liga/desliga | M | botão no canto | Y |
| Tela cheia | F11 | botão no canto | — |
| Configuração | F1 (no mapa) | botão no canto | — |

## Para quem quer contribuir

- [`docs/PROJETO.md`](docs/PROJETO.md): estado técnico, checklist da engenharia reversa,
  ferramentas de pesquisa e como os releases são gerados.
- [`docs/FINDINGS.md`](docs/FINDINGS.md): tudo o que já foi descoberto sobre a ROM.
- [`engine/README.md`](engine/README.md): o motor (estrutura, opções, console).
