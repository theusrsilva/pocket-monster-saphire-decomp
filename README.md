# saphire-recomp

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
- [ ] Stats dos Pokémon, golpes, itens
- [ ] Metasprites das animações de batalha
- [ ] Formato dos mapas de fase e unidades
- [ ] Paletas CGB
- [ ] Fórmulas de batalha / IA
- [ ] Motor em LÖVE2D

Detalhes técnicos em [`docs/FINDINGS.md`](docs/FINDINGS.md).

## Uso

```sh
./tools/setup.sh                  # baixa mgbdis + RGBDS, gera disasm/ e confere o round-trip
python3 tools/extract_text.py rom/saphire.gbc out/script.json out/script.txt
python3 tools/dump_tiles.py   rom/saphire.gbc out/tiles
python3 tools/probe_layout.py rom/saphire.gbc <offset_hex> <ntiles> out/probe.png
```

SHA-1 esperado da ROM (versão Fixed do Handheld Underground):
`9fa7da61c61d684f39e43d6899a68309ba8607b3`
