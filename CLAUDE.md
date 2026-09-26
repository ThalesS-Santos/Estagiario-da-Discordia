# CLAUDE.md — O Paradoxo do Estagiário

Guia para qualquer sessão do Claude Code neste repositório. Registra o que o jogo é, como o código está organizado e, principalmente, **as decisões que já foram tomadas** (e por quê). Leia antes de mexer; se uma decisão precisar mudar, atualize este arquivo junto.

## 1. O projeto em um parágrafo

Jogo 2D top-down em pixel art moderno feito na **Godot 4.7** (renderer GL Compatibility, 1280x720, `canvas_items`). Tema da **Game Jam CIMATEC 2026.2: "Efeito Borboleta"**. Deadline **28/09/2026 23h59**, submissão no itch.io. O jogador é um estagiário de uma agência interdimensional (Agência Panóptico) numa vila medieval. Missão: derrubar o Rei Aldemar I em 3 dias **sem violência**, só movendo objetos e plantando boatos. Uma IA (Gemini) age como "Diretor de Cena": interpreta a ação e devolve como os NPCs reagem (medo, raiva, falas, para onde vão). O GDD completo está em `docs/GDD_Paradoxo_Estagiario_v2_COMPLETO.txt`.

## 2. Regras de trabalho com o usuário (importante)

- **Idioma:** conversar e escrever textos de jogo/UI/documentação em **português do Brasil**. Identificadores de código em inglês ou português já existente (siga o vizinho).
- **Não tente clicar em NPCs para testar.** Eles andam; nunca se acerta. Depois de alterar algo que exige conferência visual, **peça ao usuário para verificar**. Pode-se validar por `logs_read`, `get_ui_elements`, `get_node_info` e capturas de tela, mas sem ficar perseguindo NPCs.
- **Perguntar antes de baixar pacotes novos.** Exceção já autorizada: Kenney Tiny Dungeon (CC0) foi baixado a pedido do usuário.
- **Respostas curtas e diretas.** O usuário reage forte a coisas feias/quebradas: valide o visual (preview ampliado em PNG) antes de declarar pronto e seja honesto sobre o que não foi testado em jogo.
- **Vários agentes/pessoas editam os mesmos arquivos.** Arquivos mudam no disco durante a sessão (`world.gd`, `npc.gd`, `hud.gd`, etc.). Sempre releia antes de editar e não reverta mudanças alheias. Erros de parse vistos no editor podem ser de edição em andamento de outra pessoa.
- **Nunca commitar chaves.** Ver seção 9.

## 3. Regra de ouro visual

> **Tudo que o jogador vê deve ser PNG/spritesheet, nunca desenho procedural em `_draw()`.**

- Motivo: o procedural foi rejeitado como "desenho de criança"; o alvo é qualidade de Pokémon FireRed/Emerald, com escala correta (árvores mais altas que pessoas, castelo imponente).
- Toda arte é gerada por scripts Python em `tools/gen/` (Pillow) e gravada em `assets/gen/`. Rodar `python build_all.py` a partir de `tools/gen/` regenera tudo e escreve `assets/gen/map.json` (o layout da vila, lido pelo Godot).
- Paleta base = cores extraídas do **Kenney Tiny Town** + tons no mesmo espírito (`tools/gen/common.py`, dicionário `C`). Novos assets devem usá-la.
- Tolerado em código: feedback efêmero (texto de fala, anéis de narrativa). Mesmo assim, prefira textura.
- Depois de **criar arquivos PNG novos**, chamar `filesystem_manage(op="scan")` (MCP godot-ai) para o Godot importar; senão dá "No loader found for resource".
- Texture filter nearest em tudo (`textures/canvas_textures/default_texture_filter=0`).

## 4. Estrutura do repositório

```
main.tscn / scripts/main.gd     menu, abertura, briefing, telas de fim
scripts/world.gd                mundo: fases, jogador, NPCs, objetos, simulação, câmera
scripts/village.gd              cenário (chão, prédios, árvores, lago, luzes) a partir de map.json
scripts/village_navigation.gd   obstáculos (StaticBody2D camada 1) + NavigationRegion2D
scripts/npc.gd                  NPC (folha 4x3, fala, emote, IA de andar) — class_name NPC
scripts/player_intern.gd        jogador — class_name PlayerIntern (cena em scenes/)
scripts/world_object.gd         objetos pegáveis (grupo "grabbable")
scripts/hud.gd                  HUD inteiro (pixel-art, 9-slice, animações)
scripts/game.gd                 autoload Game: constantes, NPC_DEFS, VILLAGER_DEFS, OBJECTS, estado, save
scripts/gemini_director.gd      chamada direta ao Gemini (HTTPRequest)
scripts/director.gd, local_director.gd, ai_contract.gd   diretor antigo/utilidades e contrato de validação
scripts/sfx.gd, anim_sprite.gd, settings_panel.gd, menu_village.gd
scenes/player_intern.tscn       cena do Estagiário
tools/gen/*.py                  geradores de arte (ver seção 3)
assets/gen/                     saída dos geradores (versionada)
assets/kenney_tiny_town/        pacote base (CC0)
assets/kenney_tiny_dungeon/     pacote de personagens (CC0), usado na 1ª versão do jogador
tests/                          cenas de teste headless (Gemini, mundo, runtime)
docs/                           GDD, AI_BACKEND.md, GEMINI_DIRECT.md, exemplo de backend
addons/godot_ai/                ponte MCP do editor (só desenvolvimento)
```

Autoloads: `Game`, `Sfx`, `Director`, `_mcp_game_helper`.

## 5. Mundo, fases e loop de jogo

- Mapa 1280x960. 3 dias (`Game.MAX_DAYS`), 3 PA por dia (`AP_PER_DAY`). Barra de **Instabilidade Social** 0–100: chegar a 100 = vitória; fim dos 3 dias sem isso = derrota.
- Fases em `world.gd`: `ACTION` (jogador age), `TERMINAL` (digitando boato), `SIM` (NPCs reagem), `ENDED`.
- **Custos:** pegar objeto = 1 PA, soltar com boato = 1 PA (pegar+soltar = 2, exige ter 2 antes de pegar). Sussurrar para NPC = 1 PA.
- `Z` desfaz a última ação; `ESC` cancela o terminal; clique direito solta sem narrativa; `TAB` abre o painel de status.
- Luz/ambiente: `CanvasModulate` por horário, `PointLight2D` coloridas (fonte azul, forja laranja, templo dourado, tochas) com oscilação multi-frequência, `DirectionalLight2D` suave. **DirectionalLight2D no Godot 4 não tem `texture`** (usa `height`/`max_distance`).
- Y-sort: `village.ysort` é o container y-sorted de NPCs, aldeões e do jogador.

## 6. Personagens

### NPCs principais (`Game.NPC_DEFS`)
Aldemar I (Rei), João da Padaria, Gordo Marten (Ferreiro), Bram (Guarda), Mira (Sacerdotisa), Valdo (Mercador), Lila (Órfã). Atributos: medo, raiva, lealdade, credibilidade (0–100), mais memórias.

### Aldeões (`Game.VILLAGER_DEFS`)
Tobias (Fazendeiro), Helga (Camponesa), Ancião Osric, Pip (Menino), Dama Isolde (Nobre). **Decisão:** todo NPC do mapa tem nome, papel e atributos, abre o card, é alvo de sussurro e entra no estado do Gemini. Antes eram "decor" sem nome — o usuário reprovou. (`decor`/`wide_wander` só controlam a área de passeio.)

### Folha de sprites dos NPCs (padrão de todo personagem)
- **64x72 px**: 4 colunas (frames) x 3 linhas (frente `d`, costas `u`, perfil `s`), cada frame 16x24. Perfil olha para a **esquerda**; à direita usa `flip_h`. Ciclo de andar `[1,2,3,2]`. Escala 2 no jogo, pivô nos pés (`offset (-8,-23)`), sombra `chars/shadow.png`.
- Estilo: cabeça grande (~60% do corpo), olhos de 1 pixel, cores chapadas, **contorno escuro grosso**.
- Definidos em `tools/gen/chars.py` (`CHARS`, overlays ASCII, `base_pal`).

### O Estagiário (jogador)
- Cena `scenes/player_intern.tscn`, script `player_intern.gd`, nós: `CollisionShape2D`, `Sprite2D` (+ `HeadSprite`, `HairSprite`, `CloakTailSprite`, `EmotionBubble`), `AnimationPlayer`, `Camera2D`, `InteractionZone` (raio 40), `HandTarget`.
- **Histórico de arte (decisões):** 1) camadas desenhadas por código Python → "muito feio"; 2) recorte do Kenney Tiny Dungeon em camadas → melhorou; 3) **atual:** folha própria no padrão dos NPCs, `player_intern` em `chars.py` → "melhorou muuuito". O modo "camadas" continua no script como fallback, mas fica oculto.
- Visual: camisa branca + gravata vermelha + **paletó/manto marrom** (visto de frente, de lado e de costas de forma consistente) + calça escura. O perfil tem topete pequeno (o cabelo grande no perfil foi reprovado).
- **Agachado (Shift/STEALTH):** a folha tem 6 linhas (64x144): linhas 3–5 = frente/costas/perfil agachado (cabeça inteira, 1 linha de tronco e 2 de pernas removidas, joelhos abertos parado). O script conta linhas pela altura da textura; sem linhas agachadas, cai no achatamento (Scale Y 0.9). Um agachado que "só ficava menor e sem pernas" foi reprovado.
- Estados: `IDLE`, `WALK` (150), `STEALTH` (70, sem `footstep_made`), `INTERACT` (sussurro, congelado).
- Animação procedural: respiração senoidal, bobbing, molas para capa/inércia, salto de pânico e sussurro via `AnimationPlayer` (propriedades `fx_hop`, `fx_squash`, `fx_lean`).
- Emoções: `set_emotion("NEUTRAL"|"SUSPICIOUS"|"NERVOUS"|"PANIC"|"SMUG")` com balão (`assets/gen/player/emotes.png`), suor (`sweat.png`, CPUParticles2D), respiração 2x no nervoso, PANIC/SMUG voltam ao neutro sozinhos.
- Câmera: suavização 5.0 + espiada de até 50 px para o mouse. No `world.gd` a câmera do jogador vale em ACTION/TERMINAL; a câmera do mundo (segue NPCs) vale em SIM/cinemáticas.
- Interação: objetos e NPCs são achados por **grupos** (`grabbable`, `gossip_target`) + distância à `InteractionZone`, não por sobreposição de física. Sussurro só por trás ou ao lado do NPC (`behind_dot_limit`); pelo `world.gd` o jogador tem `grab_gate` (cobra PA) e `external_drop_control` (soltar abre o terminal). Movimento congelado quando `input_enabled` é falso (terminal/simulação) — necessário porque o `Input.get_vector` ignora o foco do `LineEdit`.
- Ações de Input (`move_*`, `stealth`, `interact`, `mouse_click`) são registradas pelo próprio script se faltarem no projeto.
- Colisão: jogador camada 2, máscara 1 (obstáculos da vila).
- `tools/gen/import_player_sheet.py` converte uma folha de IA (fundo magenta #FF00FF) em `chars/player_intern.png` (64x72).

## 7. HUD (decisões de design)

- **Todo o HUD é pixel art**: 9-slice (`NinePatchRect`) com PNGs de `assets/gen/ui/` (gerados por `tools/gen/ui_assets.py`): painel, tooltip, barras de status coloridas por atributo, ícones, gemas de PA (frames cheio/vazio via `AtlasTexture`), moldura/preenchimento da instabilidade, banner do dia, botões (3 estados), separador.
- Animações: fade/slide de painéis, barras que interpolam, gemas, toast, banner.
- **Contraste:** todo painel tem um fundo escuro quase opaco (`ColorRect` por trás, criado em `_9patch`) porque o texto era ilegível sobre o mapa. O painel do card/tooltip **precisa dimensionar ao conteúdo** (`get_combined_minimum_size`), senão o fundo fica de 16 px. Nomes de NPC sobre o mapa têm caixa escura com borda dourada.
- Armadilhas do Godot: `StyleBoxTexture` usa `texture_margin_*` (não `margin_*`); NinePatch com margens dobradas para escala 2.
- Terminal de narrativa: limite 80 caracteres, `ENTER` confirma, `ESC` cancela, texto ofensivo bloqueado (`Director.is_offensive`).

## 8. IA

- **Arquitetura final (decisão):** jogo -> **proxy serverless na Cloudflare Workers** (`backend/`) -> Gemini. A chave fica só como *secret* do Worker (`wrangler secret put GEMINI_API_KEY`); o jogo distribuído nunca a tem. Serverless = no ar 24/7 sem máquina, e o plano gratuito cobre o volume da jam. Motivo: a organização exige um executável que os jurados rodem, e o jogo precisa funcionar sem o jogador configurar nada.
- **Cliente:** `scripts/gemini_director.gd`. Modo BACKEND quando `game/ai/backend_url` (Project Settings) ou `PARADOXO_BACKEND_URL` estão definidos; senão modo DIRETO (dev, `GEMINI_API_KEY` do ambiente). Modo backend: timeout 25 s e 1 nova tentativa em falha de rede.
- **Servidor** (`backend/src`): dono do prompt (`prompt.js`), do dossiê de NPCs/locais (`world.js`) e da validação **tolerante** (`validate.js`: ajusta valores e descarta só o item ruim). Tenta `GEMINI_MODEL` e reservas em ordem; chave no header `x-goog-api-key` (nunca na URL); limite por IP; CORS aberto (build HTML5). `npm test` na pasta `backend/`.
- **Reserva local (decisão):** se a IA falhar por qualquer motivo, `world.gd` usa `LocalDirector.ai_result` (mesmo contrato do Gemini) e mostra "IA offline". O jogo nunca trava para o jurado. `world.ai_fallback_enabled = false` nos testes que exigem o erro.
- O prompt recebe contexto (dia, instabilidade, boatos), o dossiê dos 12 moradores e a calibragem do delta. Sussurro para NPC gera ação com `target_npc`.
- Retorno: `instability_delta` (-20..45) + `npc_updates` (fala, estado, destino, medo/raiva/lealdade), no máximo 12, um por NPC.
- Arquitetura antiga (FastAPI, `docs/AI_BACKEND.md`, `docs/backend/`) e o autoload `Director` ficam só como referência/utilidades.
- Deploy e cotas: `backend/README.md`. Modelos mudam: confirmar o nome com a chave antes da entrega.

## 9. Segurança e segredos

- **Nunca** colocar chave da API em arquivo, cena, commit ou log. Em produção a chave só existe no Worker; em desenvolvimento, `GEMINI_API_KEY` do ambiente (propositalmente sem `@export`). `.gitignore` já ignora `.env*`.
- Chave compartilhada num jogo público não é segura; para distribuir, usar chave do próprio jogador ou um serviço sob controle do dev.
- Uma chave chegou a ser enviada na conversa; deve ser considerada vazada e **revogada**.

## 10. Testes

Cenas headless em `tests/` (precisam do binário `godot` no PATH):

```bash
godot --headless --path . res://tests/runtime_tests.tscn
godot --headless --path . --log-file .godot/gemini_tests.log res://tests/gemini_director_tests.tscn
godot --headless --path . --log-file .godot/gemini_world_tests.log res://tests/gemini_world_tests.tscn
godot --headless --path . res://tests/ai_backend_tests.tscn
cd backend && npm test
```

Os testes do Gemini mockam só o HTTP. Sem `godot` no PATH, valide pelo MCP `godot-ai` (`filesystem_manage scan`, `logs_read source=editor`).

## 11. Dicas do MCP godot-ai (editor + jogo)

- `game_manage input_mouse` usa `event: "motion" | "button"`; para clicar, mande `motion` na posição e depois `button` pressed true/false. `get_ui_elements` só lista visíveis (use `include_hidden: true`).
- `node_get_properties` e `scene_*` operam na cena **editada**, não em nós criados em tempo de execução (use `game_manage get_node_info/get_scene_tree`).
- `editor_screenshot source=game` às vezes falha por transporte; repita.
- Com o jogo rodando o editor bloqueia escritas de cena (`project_manage stop` antes).
- Câmera: tela = `(mundo - câmera) * zoom + (640, 360)`; o zoom usual é ~0.93.

## 12. Créditos e licenças

Kenney Tiny Town e Tiny Dungeon — CC0 (kenney.nl). Arte gerada em `assets/gen/` é do projeto. Detalhes de licença nos `License.txt` dentro de cada pacote.

## 13. Pendências conhecidas

- Aldeões participam do estado do Gemini, mas a simulação local antiga trata só os NPCs principais.
- A folha do jogador vem do gerador; uma folha de IA pode substituí-la (script de importação pronto).
- Áudio/música: `sfx.gd` existe; conferir cobertura antes da entrega.
- Build/export para itch.io ainda não configurado.
