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
- **Animações de batalha originais**: a cena de ataque é o código do próprio jogo executado num
  pequeno emulador de GBC embutido, com o resultado calculado pelo motor.
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
| Turno inimigo | ritmo fixo | normal ou rápido |
| Tela | 160×144 | janela grande, tela cheia ou as duas telas do 3DS |
| Animações de batalha | — | as originais, que podem ser puladas (A, B ou START) |

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
   turno, X troca o idioma, Y liga/desliga o som. As animações de batalha ficam desligadas no
   console. Ainda não foi testado em hardware.

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

Teclado: setas movem, Z/Enter confirma, X volta, Esc encerra o turno, N troca o idioma, M liga/desliga
o som, F1 abre a configuração. Mais detalhes em [`engine/README.md`](engine/README.md).

## Para quem quer contribuir

- [`docs/PROJETO.md`](docs/PROJETO.md): estado técnico, checklist da engenharia reversa,
  ferramentas de pesquisa e como os releases são gerados.
- [`docs/FINDINGS.md`](docs/FINDINGS.md): tudo o que já foi descoberto sobre a ROM.
- [`engine/README.md`](engine/README.md): o motor (estrutura, opções, console).
