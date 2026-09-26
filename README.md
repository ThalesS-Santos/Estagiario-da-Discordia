# O Paradoxo do Estagiário

> *Pequenas ações, grandes consequências.*

Um jogo 2D em pixel art onde você é um **estagiário de uma agência de viagens temporais**, disfarçado com um manto medieval sobre a camisa social, mandado a uma vila com uma missão impossível: **derrubar o Rei tirano em 3 dias, sem violência**. Suas únicas armas são objetos fora do lugar e boatos bem plantados. Uma IA faz o resto e os moradores reagem em tempo real.

Feito na **Game Jam CIMATEC 2026.2** (tema: *Efeito Borboleta*) com **Godot 4.7**.

## Como se joga

1. **Ande** pela vila com `WASD`. Segure `Shift` para se agachar e andar em silêncio.
2. **Pegue um objeto** (clique nele quando estiver perto) e **solte** em outro lugar. Isso custa Pontos de Ação.
3. **Escreva o boato** que conecta o objeto ao caos, ou **sussurre** para um NPC apertando `E` por trás dele.
4. A IA interpreta sua ação e a vila reage: medo, raiva, fofoca, correria.
5. Chegue a **100% de Instabilidade Social** antes do fim do terceiro dia.

| Tecla | Ação |
|---|---|
| `W A S D` | Andar |
| `Shift` | Agachar (furtivo, sem som de passos) |
| Clique esquerdo | Pegar / soltar objeto próximo |
| Clique direito | Soltar sem boato |
| `E` | Sussurrar para um NPC (por trás ou ao lado) |
| `Z` | Desfazer |
| `Tab` | Painel de status |
| `Esc` | Cancelar / pausa |
| Roda do mouse | Zoom |

Passe o mouse sobre qualquer morador para ver **medo, raiva, lealdade e credibilidade** e o que ele lembra.

## Rodando o projeto

**Requisitos:** [Godot 4.7](https://godotengine.org/) (GL Compatibility) e, para a IA, uma chave da API do Gemini.

```bash
git clone <url-do-repositorio>
cd estagiario-da-discordia
# abra a pasta no Godot e aperte F5
```

### A IA (Gemini) e o backend

O jogo conversa com um pequeno servidor (Cloudflare Workers) que guarda a chave do Gemini, então **quem joga não configura nada**. Para publicar o seu, siga [`backend/README.md`](backend/README.md) e cole a URL em *Project Settings -> `game/ai/backend_url`* antes de exportar. Se o servidor ficar indisponível, o jogo continua no modo local.

Para desenvolver sem servidor, defina `GEMINI_API_KEY` (e, se quiser, `GEMINI_MODEL`) no ambiente antes de abrir o Godot. Mais detalhes em [`docs/GEMINI_DIRECT.md`](docs/GEMINI_DIRECT.md).

## A arte

Todo visual é PNG gerado por scripts Python, com a paleta do **Kenney Tiny Town**, para manter o estilo unificado.

```bash
cd tools/gen
pip install pillow
python build_all.py     # regenera assets/gen/ e o mapa (map.json)
```

- Personagens: folhas 64x72 (4 colunas x 3 linhas: frente, costas, perfil) em `tools/gen/chars.py`; o jogador tem 3 linhas extras de agachado.
- Interface: 9-slice, barras, gemas e botões em `tools/gen/ui_assets.py`.
- Vila: terreno, prédios, árvores, lago e adereços em `tools/gen/*.py`.

## Testes

Com o `godot` no PATH:

```bash
godot --headless --path . res://tests/runtime_tests.tscn
godot --headless --path . res://tests/gemini_director_tests.tscn
godot --headless --path . res://tests/gemini_world_tests.tscn
godot --headless --path . res://tests/ai_backend_tests.tscn
cd backend && npm test
```

Os testes do Gemini não fazem chamadas de rede reais.

## Estrutura

```
scripts/     código do jogo (mundo, HUD, NPCs, jogador, IA)
scenes/      cena do Estagiário
tools/gen/   geradores de pixel art (Python + Pillow)
assets/      arte gerada + pacotes Kenney (CC0)
docs/        GDD, integração com IA
tests/       cenas de teste headless
addons/      ponte MCP do editor (só desenvolvimento)
```

Para o histórico de decisões de design e técnica, veja [`CLAUDE.md`](CLAUDE.md).

## Créditos

- Arte-base: [Kenney](https://kenney.nl) — *Tiny Town* e *Tiny Dungeon* (CC0).
- Demais sprites, interface e mapa: gerados para este projeto.
- IA: Google Gemini.

## Licença

Código e arte gerada do projeto: defina a licença antes de publicar (sugestão: MIT para o código). Pacotes Kenney: CC0.
