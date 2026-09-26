# Gemini direto no Godot

`world.gd` já instancia `scripts/gemini_director.gd` como filho chamado
`GeminiDirector`. O Enter/confirmação do HUD está conectado: não adicione
um segundo diretor à cena principal. O script também pode ser usado
isoladamente; ele não depende de `Game`, `Director`, `AIContract` ou servidor.
O retorno tem `instability_delta` e `npc_updates`.

## Fluxo integrado

1. Soltar objeto com fofoca ou sussurrar para NPC abre o terminal existente.
2. Enter dispara `_on_gossip_submitted` → `terminal_submit` → `_request_caos`.
   O mundo descreve o objeto/local ou o destinatário do sussurro e lê medo,
   raiva, lealdade, estado e posição global dos NPCs visíveis na cena, incluindo
   aldeões. Credulidade e memórias vêm do estado persistente.
3. A borboleta aparece imediatamente, antes de chamar o Gemini. Jogador e
   NPCs ficam imóveis durante a espera. Novos envios e Encerrar Dia são bloqueados.
4. `_on_caos_gerado` confirma a ação, aplica as diretivas aos NPCs e sincroniza
   os atributos persistentes. `get_ai_target` resolve IDs em marcadores de
   locais ou NPCs reais. `NavigationAgent2D` recebe a posição global; estados
   RUN e AFRAID correm, WALK caminha. Falas aparecem no Label de cada NPC.
5. `Game.add_instability` aplica o delta uma vez; seu sinal anima a barra.
   Depois das reações o controle volta ao jogador no mesmo dia. Chegar a
   100 dispara a vitória. Encerrar Dia avança o relógio/dia e verifica derrota,
   sem fazer uma segunda chamada nem reaplicar a fofoca.

Falhas reabrem o terminal com o texto preservado. Não há cobrança da
confirmação enquanto a resposta não for válida; o PA já gasto ao pegar um
objeto continua reservado. ESC permite cancelar e Z devolver o objeto.
Depois de uma resposta aplicada, Z não desfaz somente o objeto/PA deixando
consequências inconsistentes: use Reiniciar Dia para voltar ao checkpoint.

O autoload `Director` antigo permanece para compatibilidade/utilidades,
mas não recebe inferências no fluxo atual. Não há fallback local silencioso.

## Uso isolado em outra cena

```gdscript
func _ready() -> void:
    $GeminiDirector.butterfly_effect_calculated.connect(_on_effect)
    $GeminiDirector.ai_error.connect(_on_ai_error)

func ask_gemini() -> void:
    $GeminiDirector.evaluate_butterfly_effect(
        "Mover frasco ao poço",
        "O rei mandou envenenar a água",
        {"npc_baker": {"fear": 30, "anger": 20, "loyalty": 40}}
    )

func _on_effect(data: Dictionary) -> void:
    # Encaminhe data ao controlador da rodada/NPCs e atualize a UI.
    pass

func _on_ai_error(message: String) -> void:
    # Exiba a mensagem na UI e libere o botão de interação.
    push_warning(message)
```

Configure `GEMINI_API_KEY` no ambiente do processo que inicia o Godot, ou
atribua `api_key` em tempo de execução. Ela não é exportada ao Inspector para
evitar gravá-la acidentalmente na cena. A chave enviada na conversa não foi
incluída em nenhum arquivo nem usada em chamadas reais. Revogue/substitua
essa chave antes de usar uma credencial nova.

`model_name` é exportado e mantém `gemini-1.5-flash` conforme solicitado.
Esse modelo foi descontinuado: troque por um modelo disponível na sua conta
que suporte `generateContent`, instrução de sistema e saída JSON. O script
não troca o modelo silenciosamente. Uma chamada ao modelo antigo pode falhar.
Como o nó da partida é criado dinamicamente, configure o modelo em
Project Settings → `game/ai/gemini_model`, ou pela variável `GEMINI_MODEL`.
A variável de ambiente tem precedência sobre a configuração do projeto.

`allowed_locations` contém os IDs deste mapa e pode ser editado no Inspector.
O estado deve ter o formato `{npc_id: atributos}`; só NPCs fornecidos e destinos
permitidos são aceitos. A validação cobre limites, tipos, estados e duplicatas.

O POST usa `system_instruction`, `contents/parts` e
`generationConfig.response_mime_type = "application/json"`. Os erros não
incluem a URL com chave nem o corpo bruto devolvido pelo Google. A espera
manual de 15 segundos ignora pausa e velocidade do jogo; temporizadores
antigos não cancelam pedidos novos. Não há retries automáticos ou fallback
escondido. `cancel_pending()` permite cancelamento explícito.

Chamadas diretas não conseguem manter uma chave compartilhada secreta em um
jogo público, mesmo quando obtida do ambiente. Para distribuir esse modo,
considere credenciais fornecidas pelo próprio jogador; proteger uma chave
do desenvolvedor e impor quotas confiáveis requer um serviço sob seu controle.

Testes sem rede externa ou credenciais reais:
`godot --headless --path . --log-file .godot/gemini_tests.log res://tests/gemini_director_tests.tscn`

Teste do fluxo integrado HUD → Gemini → NPCs/HUD:
`godot --headless --path . --log-file .godot/gemini_world_tests.log res://tests/gemini_world_tests.tscn`
Este teste substitui apenas o envio HTTP por um mock; o parser, os sinais,
o HUD e o mundo são os reais. Inclui estado vivo dos NPCs, rotas, aldeões,
duplicação, tratamento de erros, repetição e avanço do dia sem inferência.

Referências:
- [REST generateContent](https://ai.google.dev/api/generate-content)
- [Descontinuação do Gemini 1.5 Flash](https://firebase.google.com/docs/ai-logic/faq-and-troubleshooting)
