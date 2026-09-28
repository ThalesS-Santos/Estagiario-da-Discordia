# 🦋 O Paradoxo do Estagiário

> *"O bater de asas de uma borboleta pode provocar um tufão no outro lado do mundo."*

[![Godot Engine](https://img.shields.io/badge/Godot-4.7_GL_Compatibility-478CBF?logo=godotengine&logoColor=white)](https://godotengine.org/)
[![Google Gemini](https://img.shields.io/badge/AI-Gemini_2.5_Flash-8E75B2?logo=google&logoColor=white)](https://aistudio.google.com/)
[![Cloudflare Workers](https://img.shields.io/badge/Backend-Cloudflare_Workers-F38020?logo=cloudflare&logoColor=white)](https://workers.cloudflare.com/)
[![Game Jam](https://img.shields.io/badge/Game_Jam-CIMATEC_2026.2-FF4B4B)](#sobre-o-projeto)
[![Visual Style](https://img.shields.io/badge/Art-Modern_Pixel_Art_2D-34A853)](#arte-e-estética)

Um jogo sandbox narrativo 2D em pixel art onde você assume o papel de um **estagiário da Agência Panóptico (Central de Viagens Interdimensionais)**, disfarçado com um manto medieval por cima da camisa social e gravata. Enviado à Linha Temporal Alfa-3 (Coordenada 14.7-F), sua missão é aparentemente impossível: **derrubar o tirano Rei Aldemar I em 3 dias, sem desferir um único golpe físico**.

Suas únicas ferramentas são manipular objetos fora de lugar, sussurrar boatos calculados e deixar que a **Inteligência Artificial (Google Gemini)** atue como o Diretor de Cena que calcula o caos social em tempo real.

Desenvolvido para a **Game Jam CIMATEC 2026.2** sob o tema **"Efeito Borboleta"**.

---

## 📑 Sumário

- [Visão Geral e Narrativa](#-visão-geral-e-narrativa)
- [Mecânicas e Gameplay](#-mecânicas-e-gameplay)
- [Controles do Jogo](#-controles-do-jogo)
- [Os 12 Habitantes e Facções](#-os-12-habitantes-e-facções)
- [A Missão do Portão do Castelo](#-a-missão-do-portão-do-castelo)
- [Arquitetura de Inteligência Artificial](#-arquitetura-de-inteligência-artificial)
- [Arte e Pipeline de Geração](#-arte-e-pipeline-de-geração)
- [Como Rodar o Projeto](#-como-rodar-o-projeto)
- [Testes Automatizados](#-testes-automatizados)
- [Estrutura do Repositório](#-estrutura-do-repositório)
- [Créditos](#-créditos)

---

## 🌌 Visão Geral e Narrativa

As projeções da Agência Panóptico são categóricas: em **3 dias**, o Rei Aldemar I declarará guerra a todos os reinos vizinhos, devastando toda a região. Como estagiário recém-alocado em campo, suas diretrizes são restritas:

1. **Protocolo Sem Violência:** Proibido combate armado direto ou derramamento de sangue pelas suas mãos.
2. **Invisibilidade Causal:** O povo da vila deve acreditar que suas próprias suspeitas e conflitos internos levaram à queda do trono.
3. **Limite Temporal:** Você dispõe de exatamente **3 dias** e **3 Pontos de Ação (PA) por dia**.
4. **Meta Crítica:** Elevar a **Instabilidade Social da vila a 100%** para incitar uma Revolta Popular completa que deponha o monarca, ou infiltrar-se no castelo desguarnecido.

A experiência inicia com uma **abertura em primeira pessoa** no laboratório da Agência:
- Registro tátil de ID de Operador via console holográfico cibernético.
- Briefing diegético diretamente no **Visor de Pulso (smartwatch temporal)**.
- Transição cinematográfica via **Portal Dimensional** direto para o centro do vilarejo medieval.

---

## 🎮 Mecânicas e Gameplay

O ciclo de jogo divide-se em fases contínuas controladas pelo motor:

```
[ Abertura / Briefing ] ➔ [ FASE DE AÇÃO (Exploração & PA) ] ➔ [ TERMINAL DE NARRATIVA ]
                                   ▲                                      │
                                   │                                      ▼
                        [ NOVO DIA / CONFRONTOS ] ◄─────── [ FASE DE SIMULAÇÃO (IA) ]
```

### 1. Furtividade e Movimentação Fina
- Ande livremente em 8 direções.
- Pressione ou segure `Shift` para assumir a postura **Agachada (Stealth)**: reduz a velocidade pela metade, amortece ruídos de passos e diminui o raio de detecção por guardas e sentinelas.
- O Estagiário conta com física de animação secundária (mola na capa, respiração, *squash & stretch* e reações emocionais expressas em balões e partículas de suor).

### 2. Manipulação de Objetos (1 PA)
- Pelo mapa há dezenas de itens com tags semânticas (`comida`, `veneno`, `sagrado`, `real`, `arma`, `escrito`, `pesado`, `pequeno`).
- Aproxime-se de um item para iluminar seu contorno e pegá-lo (`Botão Esquerdo`).
- Carregue o item até um novo local e solte-o para abrir o **Terminal de Narrativa**.

### 3. O Terminal de Boatos (1 PA)
- Ao soltar um item ou sussurrar para um morador por trás (`E`), o terminal holográfico surge na tela.
- Digite uma justificativa ou mentira relacionando o item à discórdia local (ex: *"Coloquei a adaga real na sacola de farinha do padeiro para incriminar o guarda"*).
- Filtro de moderação integrado contra ofensas e limite ergonômico de 80 caracteres.

### 4. O Efeito Borboleta (Simulação em Tempo Real)
- O **Diretor de Cena (Gemini IA)** recebe o estado completo da vila, os perfis dos habitantes e a ação do jogador.
- A IA responde com a variação da **Instabilidade Social** (-20% a +45%) e ações individuais: falas com balões dinâmicos, mudança nos sentimentos dos NPCs e deslocamento físico pelo vilarejo.

### 5. Mecânica de Suspeita e Modo de Perseguição (*Pursuit*)
- Ficar muito tempo perto de áreas restritas (como o Portão do Castelo sob os olhos do Ancião Osric) eleva a **Barra de Suspeita**.
- Se a suspeita atingir 100%, os guardas iniciam o modo **PURSUIT**:
  - A tela ganha uma **vinheta de tensão avermelhada**.
  - O áudio entra em loop acelerado de alerta.
  - O jogador deve fugir e se esconder até o medidor decair. Três capturas resultam em fracasso imediato da missão.

---

## ⌨️ Controles do Jogo

| Tecla / Comando | Função |
| :--- | :--- |
| `W`, `A`, `S`, `D` / Setas | Movimentar o Estagiário pelo vilarejo (8 direções) |
| `Shift` (Segurar) | **Modo Furtivo / Agachado** (passos silenciosos, menor detecção) |
| `Clique Esquerdo` | Interagir / Pegar objeto próximo / Soltar com boato |
| `Clique Direito` | Soltar objeto carregado rapidamente (sem criar boato) |
| `E` | **Sussurrar boato** para um NPC (pelas costas ou lateral) |
| `Z` | Desfazer última ação de posicionamento |
| `Tab` | Alternar exibição do **Painel de Status da Vila** |
| `Esc` | Fechar terminal / Cancelar ação / Menu de Pausa |
| `Roda do Mouse` | Controle de Zoom da Câmera (aproximação/visão panorâmica) |
| `Enter` | Confirmar texto no terminal de boatos |

---

## 👥 Os 12 Habitantes e Facções

Ao passar o mouse sobre qualquer habitante ou pressionar `Tab`, você consulta sua ficha em tempo real com **4 atributos fundamentais (0 a 100)**:
- **Medo:** Disposição a fugir, trancar portas ou espalhar pânico.
- **Raiva:** Propensão a brigas públicas, motins e agressividade contra a coroa.
- **Lealdade:** Submissão ao Rei Aldemar I. Reduzi-la quebra a autoridade real.
- **Credibilidade:** Peso de sua palavra ao repassar fofocas aos demais moradores.

### Figuras Principais
- 👑 **Aldemar I (O Rei):** Tirano paranoico e belicoso, isolado na sala do trono.
- 🥖 **João da Padaria (Padeiro):** Trabalhador influente que guarda rancor por dívidas não pagas da coroa.
- 🔨 **Gordo Marten (Ferreiro):** Forjador de armas, pragmático e propenso a explosões de fúria.
- 🛡️ **Bram (Guarda do Portão):** Sentinela inabalável do castelo que não tolera baderna na praça.
- ⚔️ **Renato (Guarda da Patrulha):** Faz rondas ativas pela vila e investiga tumultos.
- 🕊️ **Mira (Sacerdotisa):** Líder espiritual do templo, guardiã dos ritos e defensora da paz.
- 💰 **Valdo (Mercador):** Negociante oportunista com lealdade voltada estritamente ao lucro.
- 👧 **Lila (A Órfã):** Pequena moradora que perambula pelo lago; possui alta credibilidade infantil.

### Aldeões da Vila
- 🌾 **Tobias (Fazendeiro):** Cuida das plantações ao sul; sensível à escassez de suprimentos.
- 🧺 **Helga (Camponesa):** Circula pelo centro colhendo e espalhando fofocas rapidamente.
- 📜 **Ancião Osric:** Sentinela moral da vila; observa o portão de longe e denuncia intrusos.
- 👦 **Pip (Menino):** Menino curioso que corre pela vila e encontra itens fora do lugar.
- 💎 **Dama Isolde (Nobre):** Aristocrata de hábitos refinados que desdenha dos plebeus.

### As 5 Facções de Reputação
Suas escolhas influenciam diretamente a reputação (`-100 a +100`) com cada estrato social:
1. **Plebeus:** A massa popular de camponeses e trabalhadores.
2. **Guarda Real:** Responsáveis pela ordem e aplicação dos decretos.
3. **Clero:** A autoridade moral e religiosa do vilarejo.
4. **Mercadores:** A burguesia comercial que controla mantimentos e moedas.
5. **Realeza:** O círculo íntimo do rei e simpatizantes da coroa.

---

## 🏰 A Missão do Portão do Castelo

O ápice da campanha consiste em neutralizar a segurança do castelo. O portão é fisicamente bloqueado enquanto o guarda Bram estiver em seu posto e vigiado à distância pelo Ancião Osric.

```
                    ┌────────────────────────────┐
                    │    Missão: Portão Aberto   │
                    └─────────────┬──────────────┘
                                  │
         ┌────────────────────────┴────────────────────────┐
         ▼                                                 ▼
[ Estratégia de Infiltração ]                   [ Estratégia de Revolta ]
• Descobrir pistas causais (Bram, Osric, João)  • Elevar Instabilidade a 100%
• Forjar tumulto na praça ou na ferraria        • Motim popular generalizado
• Bram abandona o posto para conter briga       • Guarda foge permanentemente
• Esgueirar-se fora da visão de Osric           • Portão arrombado pelo povo
• Cruzar o portão antes do tempo esgotar        • Deposição definitiva do Rei
```

### Investigação e Pistas Causais
- **Pistas Passivas:** Observar Bram por 5 segundos revela seu padrão de abandonar o posto diante de brigas graves; observar Osric revela seu cone de visão.
- **Pistas Ativas:** Interagir com cartas de convocação, forjar moedas reais ou incitar desavenças entre João da Padaria e os soldados.

---

## 🧠 Arquitetura de Inteligência Artificial

Para garantir máxima segurança, performance e compatibilidade com navegadores e executáveis de Game Jam, o jogo utiliza uma **arquitetura híbrida de IA**:

```
┌─────────────────────────────────┐
│     Cliente Godot 4.7 Engine    │
│  (Desktop Windows/Linux/HTML5)  │
└────────────────┬────────────────┘
                 │ HTTP POST /simulate
                 ▼
┌─────────────────────────────────┐
│    Cloudflare Workers Backend   │ ◄─── Guarda a chave secreta (Secret)
│   (Zero-Maintenance Serverless) │ ◄─── Sanitização de dados e CORS
└────────────────┬────────────────┘
                 │ REST API (Header: x-goog-api-key)
                 ▼
┌─────────────────────────────────┐
│        Google Gemini API        │ ◄─── Modelo Primário: gemini-2.5-flash
│   (Geração Estruturada JSON)    │ ◄─── Fallbacks: gemini-2.0-flash / lite
└─────────────────────────────────┘
```

### Características Técnicas:
1. **Zero Configuração para Jurados:** O jogo já vem configurado para se comunicar com o Worker serverless. O jogador não precisa criar contas, assinar nada nem colar chaves de API.
2. **Modo Direto de Desenvolvimento:** Desenvolvedores podem definir `GEMINI_API_KEY` diretamente nas variáveis de ambiente para testar sem passar pelo Worker (instruções em [`docs/GEMINI_DIRECT.md`](docs/GEMINI_DIRECT.md)).
3. **Contingência Local 100% Garantida (`LocalDirector`):** Caso ocorra queda de conexão, esgotamento de quota da API ou lentidão de rede, o motor aciona instantaneamente o Diretor Heurístico Local. **O jogo nunca trava nem interrompe a experiência.**
4. **Validação Tolerante de Esquema:** O backend valida e normaliza deltas de instabilidade, descarta campos maliciosos e garante cumprimento estrito do contrato JSON.

---

## 🎨 Arte e Pipeline de Geração

Seguindo uma estrita **regra de ouro visual**, nenhum elemento do jogo é desenhado proceduramente por código em runtime (`_draw()` foi banido para estética final). Todo o universo gráfico é composto por texturas e spritesheets em pixel art 2D com paleta unificada harmonizada com os clássicos pacotes CC0 da **Kenney**.

### Geração Procedural em Tempo de Desenvolvimento (`tools/gen/`)
Todos os assets foram construídos por geradores Python utilizando a biblioteca **Pillow**, permitindo controle absoluto sobre anatomia, paleta, iluminação e bordas:

```bash
cd tools/gen
pip install pillow
python build_all.py     # Reconstrói todos os PNGs e o layout map.json
```

- **Personagens (`chars.py`):** Folhas de sprites 64x72 px (4 colunas de animação x 3 linhas de direção: frente, costas, perfil). O Estagiário possui folha expandida de 6 linhas (64x144 px) contemplando animações exclusivas de agachamento/furtividade.
- **Interface e HUD (`ui_assets.py`):** Painéis 9-slice, molduras ornamentadas, gemas de Pontos de Ação, barras de progresso facetadas e ícones temáticos.
- **Vila e Cenário (`buildings.py`, `terrain.py`, `props.py`, `env.py`):** Castelo com versões danificadas/rachadas, casas com telhados de telha e palha, fontes, lago com margens orgânicas, tochas animadas e árvores em escala imponente.
- **Layout Causal (`layout.py`):** Gera o arquivo `assets/gen/map.json` que dita as coordenadas físicas, zonas de colisões e posições de rotina de cada habitante.

---

## 🚀 Como Rodar o Projeto

### Pré-requisitos
- [Godot Engine 4.7](https://godotengine.org/) (com suporte ao renderizador **GL Compatibility**).
- Git instalado.

### Passo a Passo
```bash
# 1. Clone o repositório
git clone https://github.com/ThalesS-Santos/Estagiario-da-Discordia.git
cd Estagiario-da-Discordia

# 2. Abra a pasta no Godot Engine 4.7
# Importe o arquivo project.godot e pressione F5 (ou clique no botão Play)
```

### Configurando o Backend Próprio (Opcional)
Se desejar hospedar sua própria instância do backend de IA na Cloudflare:
```bash
cd backend
npm install
npx wrangler login
npx wrangler secret put GEMINI_API_KEY   # Cole sua chave do Google AI Studio
npx wrangler deploy
```
Em seguida, configure a URL gerada nas configurações do projeto Godot:
`Project Settings -> General -> Game -> Ai -> Backend Url`.

---

## 🧪 Testes Automatizados

O projeto conta com baterias completas de testes unitários e de integração que rodam de forma autônoma (headless) sem necessidade de interface aberta:

```bash
# Testes de Runtime e Mecânicas do Jogo (Godot Headless)
godot --headless --path . res://tests/runtime_tests.tscn

# Testes do Diretor Gemini e Validação de Contratos
godot --headless --path . res://tests/gemini_director_tests.tscn

# Testes de Integração Mundo + IA
godot --headless --path . res://tests/gemini_world_tests.tscn

# Testes de Conectividade do Cliente de Backend
godot --headless --path . res://tests/ai_backend_tests.tscn

# Testes Unitários do Backend Serverless (Node.js)
cd backend
npm test
```

*Nota: Os testes de IA utilizam mocks estritos de transporte HTTP, podendo ser executados sem consumo de quota ou chaves ativas.*

---

## 📂 Estrutura do Repositório

```
estagiario-da-discordia/
├── assets/                     # Arte final do jogo e pacotes de terceiros
│   ├── gen/                    # Spritesheets gerados (chars, buildings, env, props, ui)
│   ├── kenney_tiny_town/       # Pacote Kenney Tiny Town (CC0)
│   └── kenney_tiny_dungeon/    # Pacote Kenney Tiny Dungeon (CC0)
├── backend/                    # Servidor proxy Cloudflare Workers
│   ├── src/                    # Código-fonte (index.js, prompt.js, validate.js, world.js)
│   ├── test/                   # Testes unitários do worker
│   └── wrangler.toml           # Configuração de deployment serverless
├── docs/                       # Documentação técnica e game design
│   ├── GDD_Paradoxo_Estagiario_v2_COMPLETO.txt   # Game Design Document oficial
│   ├── AI_BACKEND.md           # Detalhes da infraestrutura de IA
│   └── GEMINI_DIRECT.md        # Guia para chamadas diretas sem backend
├── scenes/                     # Cenas estruturadas do Godot
│   └── player_intern.tscn      # Cena e nódulos do protagonista
├── scripts/                    # Scripts em GDScript (lógica de gameplay)
│   ├── game.gd                 # Autoload com estado global, atributos e reputação
│   ├── world.gd                # Lógica central da vila, simulação, ciclos e fases
│   ├── hud.gd                  # HUD pixel-art, barras de status, eventos e tabs
│   ├── npc.gd                  # Lógica de movimentação, emoções e falas dos NPCs
│   ├── player_intern.gd        # Movimentação, furtividade, emotes e câmera do jogador
│   ├── mission_portao.gd       # Sistema da Missão do Portão, pistas e suspeita
│   ├── gemini_director.gd      # Cliente de rede HTTP com retry e fallback da IA
│   ├── local_director.gd       # Diretor de cena de contingência offline
│   ├── main.gd                 # Menus, registro de operador e transições
│   ├── wrist_intro.gd          # Cinemática e briefing diegético do relógio de pulso
│   └── sfx.gd                  # Sintetizador procedural de áudio retrô
├── tests/                      # Cenários de teste automatizados (.gd e .tscn)
└── tools/gen/                  # Pipeline Python (Pillow) gerador de pixel art
```

---

## 🏆 Créditos e Agradecimentos

- **Desenvolvimento e Game Design:** Equipe do projeto *O Paradoxo do Estagiário*.
- **Game Jam:** Desenvolvido especialmente para a **Game Jam CIMATEC 2026.2**.
- **Modelos de Inteligência Artificial:** [Google Gemini API](https://ai.google.dev/) (*Gemini 2.5 Flash*).
- **Hospedagem de API Serverless:** [Cloudflare Workers](https://workers.cloudflare.com/).
- **Arte Base e Referências:** [Kenney.nl](https://kenney.nl/) — Pacotes *Tiny Town* e *Tiny Dungeon* disponibilizados sob licença [CC0 1.0 Universal (Domínio Público)](https://creativecommons.org/publicdomain/zero/1.0/).
- **Engine:** [Godot Engine](https://godotengine.org/) (Licença MIT).

---

<div align="center">
  <sub>Construído com café, cálculos temporais e uma pitada de desordem. Boa sorte no seu primeiro dia de estágio, Operador! ⏱️💼</sub>
</div>
