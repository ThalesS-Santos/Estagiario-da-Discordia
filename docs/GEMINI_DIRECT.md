# Gemini direto no Godot

Anexe `scripts/gemini_director.gd` a um Node chamado `GeminiDirector`.
O script não depende de `Game`, `Director`, `AIContract` ou servidor próprio.
Não substitui automaticamente o autoload `Director` já usado pela partida.
Conecte os sinais a um único controlador do jogo para aplicar cada resultado
uma única vez. O retorno tem `instability_delta` e `npc_updates`.

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

Referências:
- [REST generateContent](https://ai.google.dev/api/generate-content)
- [Descontinuação do Gemini 1.5 Flash](https://firebase.google.com/docs/ai-logic/faq-and-troubleshooting)
