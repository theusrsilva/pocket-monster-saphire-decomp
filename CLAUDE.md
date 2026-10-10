# Instruções para o Claude Code

Projeto: engenharia reversa do bootleg de GBC **Pocket Monster Saphire** (Sintax, 2003) e recriação
nativa em LÖVE2D no modelo do [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp). Converse com o
usuário em **português**.

## Antes de tudo

1. Leia `README.md`, `docs/FINDINGS.md` (tudo o que já foi descoberto da ROM) e `engine/README.md`.
2. A ROM **não está no repo**. Ela deve ficar em `rom/saphire.gbc`
   (SHA-1 `9fa7da61c61d684f39e43d6899a68309ba8607b3`). Se não estiver lá, peça ao usuário para anexar
   o arquivo `.gbc` (Pocket Monster Saphire, Unlicensed, English, [Fixed]).
3. `tools/setup.sh` baixa mgbdis + RGBDS e gera `disasm/` (remonta byte a byte idêntica).
4. LÖVE 11.x: `apt-get install -y love xvfb`. Sem tela, rode com `xvfb-run -a love engine ...`.
5. Pesquisa no jogo original: `pip install pyboy --break-system-packages`, depois `tools/play.py`.

## Rodar e testar

```sh
xvfb-run -a love engine --rom rom/saphire.gbc --test          # importa e roda os testes (devem passar todos)
xvfb-run -a love engine --stage 2 --script "wait20 z right*3 z" --shot out/x.png   # entradas + screenshot
#   --cheat-move 1 (movimento alto)   --cheat-win 1 (vence a fase ao entrar)
#   --cleared N / --keys N / --node N / --new-save 1 (campanha de teste, save_test.lua)
#   --launcher 1 (abre a tela de configuração mesmo com --script; cuidado: grava options.lua)
#   --build-rom out/x.gbc (gera a ROM traduzida; o .gbc gerado também não entra no git)
#   --attack-demo 1 [--enemy 1 | --skill 0C] --anims 1 (cena de ataque original ao entrar na fase)
#   --emu-snap DIR [--trace arq | --scene 1 --out DIR] (executor GBC a partir de snapshot do PyBoy)
#   --dual 1 (layout de duas telas do 3DS)   --noshader 1   --render-music out --ids "16"
```

O cache importado e o save ficam em `~/.local/share/love/saphire-recomp/`. Ao mudar o formato do
cache, suba `CACHE_VERSION` em `engine/src/import/importer.lua`. Em execução com `--script`/`--shot`
um erro encerra o processo (exit 1) em vez de travar.

## Regras do repositório

- **Nada derivado da ROM entra no git**: ROM, `disasm/`, imagens extraídas, screenshots (`out/`).
  Única exceção: os nomes transcritos em `engine/src/game/names.lua` (e falas traduzidas, quando
  houver, num arquivo de tradução equivalente).
- Toda regra de jogo implementada deve vir do código/tabelas do original e ficar documentada em
  `docs/FINDINGS.md` com o endereço; suposições ficam marcadas como **SUPOSIÇÃO** no código.
- Cada mecânica nova ganha teste em `engine/src/tests.lua` com valores observados no jogo original.
- Atualize `README.md` (checklist) e `engine/README.md` junto com o código.
- Commits em português, com autor `theusrsilva <theusrsilva@gmail.com>`, e push para `main`.
