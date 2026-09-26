# Integração de IA e preparação para publicação

O runtime usa `HTTPRequest` nativo. `addons/godot_ai` é uma ponte MCP de
desenvolvimento para o editor, não um cliente de inferência para jogadores.
O provedor de referência é Gemini. Nenhuma chave ou chamada direta ao Google
fica no cliente. O backend será desenvolvido separadamente.

## Configurar

Em Project Settings, adicione `game/ai/backend_url` com a URL HTTPS do backend,
sem `/simulate`. Para desenvolvimento desktop também é possível definir
`PARADOXO_BACKEND_URL=http://127.0.0.1:8000`. Sem URL, o jogo roda localmente.
HTTP sem TLS só é aceito em loopback com porta explícita. Em export Web,
configure a URL no projeto e CORS no servidor para a origem exata do jogo.

`docs/backend/gemini_example.py` é um adaptador de referência do servidor,
não um serviço implantado. Instale `google-genai` e `pydantic` v2 no backend,
fixe versões no lockfile desse serviço e configure `GEMINI_API_KEY` e
`GEMINI_MODEL` no ambiente do servidor. Escolha o modelo disponível na sua
conta após medir qualidade, custo e latência; não há nome fixo no jogo.

Use a instrução de sistema em `AIContract.SYSTEM_PROMPT` como referência
versionada no servidor. Nunca aceite `system_prompt` enviado pelo jogador.
O prompt ajuda a orientar o modelo; a validação e as regras do servidor
continuam obrigatórias. Saída estruturada não garante causalidade correta.

## POST /simulate — contrato v1

O cliente envia `Content-Type: application/json` e `Idempotency-Key` aleatório.
O corpo contém:

- `schema_version: 1`, `request_id`, `locale`, `day`, `instability`, `rumors`;
- `actions`: objeto, tags, local e narrativa de cada intervenção;
- `world_state.npcs`: atributos atuais e posições; `water_poisoned`;
- `npc_memories`: memórias recentes por NPC;
- `allowed_npcs` e `allowed_locations`: IDs de referência do cliente.

O backend deve validar os dados e reconstruir IDs/limites usando seu próprio
catálogo. Em partidas com ranking ou estado compartilhado, o estado também
precisa ser autoritativo no servidor. Os IDs enviados não são autorização.
O adaptador Python recebe dados já validados, não o corpo bruto do HTTP.

Resposta HTTP 200: o objeto diretamente, sem envelope Gemini ou markdown:

```json
{
  "schema_version": 1,
  "instability_delta": 18,
  "npc_updates": [{
    "npc_id": "npc_baker",
    "dialogue_bubble": "Não bebam! Precisamos investigar o poço.",
    "new_state": "AFRAID",
    "target_node_to_move": "well",
    "fear_level": 65,
    "anger_level": 35,
    "loyalty_level": 30
  }]
}
```

Estados permitidos: `IDLE`, `WALK`, `RUN`, `AFRAID`, `ANGRY`, `TALK`, `FALLEN`.
Máximo 12 updates, um por NPC; falas de até 240 caracteres; níveis inteiros
de 0 a 100; delta finito de -20 a 45. Destinos são IDs de local ou NPC,
ou string vazia. Não são caminhos de nós, scripts ou comandos.

`AIContract.validate` rejeita o pacote inteiro quando um campo obrigatório,
tipo, ID ou limite é inválido. O adaptador converte diretivas em eventos
do executor existente. Respostas antigas com apenas `events` não fazem parte
do contrato de rede v1. O diretor local mantém eventos internos confiáveis.

O cliente limita a resposta a 64 KiB e aguarda até 20 segundos. Não segue
redirecionamentos e não faz retries que possam duplicar cobrança. Falhas,
429 e JSON inválido ativam o modo local e um cooldown de 60 segundos.
Sair da partida cancela a chamada e invalida resultados atrasados.
`ai_error` informa o HUD, `request_state_changed` controla a borboleta e
`butterfly_effect_calculated` notifica resultados remotos validados.
O resultado é aplicado uma vez pelo executor; não conecte outro consumidor
que some o mesmo delta novamente.

## Fluxo e persistência

Foi preservado o ciclo existente: preparar intervenção → confirmar narrativa
→ encerrar dia (automaticamente quando faltam PA) → executar consequências
→ avaliar vitória/derrota → próximo dia. A borboleta aparece durante a espera
real de HTTP. O terminal congela NPCs sem pausar o HTTP ou a interface.
O custo existente continua em 2 PA por intervenção e 3 PA por dia; balancear
esse orçamento e a dificuldade com jogadores é uma etapa pendente.

O save v2 é um checkpoint do início do dia, não uma gravação no meio de uma
animação. Preserva atributos, memórias, objetos e portadores, veneno, peixes,
água e estado do castelo. Escrita temporária e backup evitam substituir a
única cópia antes da gravação. Leitura inválida tenta `.bak`; saves antigos
válidos são aceitos com mundo padrão. Não é sincronização em nuvem.

## Navegação

`VillageNavigation` constrói a malha a partir dos placements do mapa atual.
As bases de edifícios, troncos, lago e paredes do castelo são excluídas e
também recebem colisões. Copas de árvores e telhados não bloqueiam o chão.
O interior e a entrada central do castelo ficam acessíveis. A malha é
gerada na criação da aldeia; não depende de executar o gerador Python.
Mudanças na geometria dos assets exigem revisar as bases de colisão e rotas.

## Verificação e limites de lançamento

Execute `godot --headless --path . --log-file .godot/tests.log res://tests/runtime_tests.tscn`.
Os testes usam HTTP local simulado e saves isolados em `.godot`; não chamam
Gemini, não gastam créditos e não alteram saves do jogador.
Validação realizada no Godot 4.7.1: 53 verificações passando, inclusive
resposta inválida, HTTP 429, cancelamento, navegação, envio duplicado,
recuperação de backup e condições de fim de partida. O terminal também foi
renderizado e inspecionado em 1280×720. Os casos com JSON propositalmente
inválido geram mensagens de parsing esperadas no log. O ambiente restrito
reportou falha ao ler o repositório de certificados do Windows; conexão HTTPS
com o backend real ainda precisa ser verificada fora desse ambiente.

Antes de publicar para o público, ainda são necessários backend real com
autenticação/sessões e limites por usuário, idempotência persistente, controle
de custos, moderação, métricas, política de dados, testes de carga e integração
com Gemini. O exemplo não implementa esses serviços. A limitação de palavras
no cliente é somente feedback de interface, não moderação de produção.

Também faltam validação visual/interativa em builds exportadas, testes de
resoluções e plataformas, acessibilidade, tradução dos textos da interface e
playtests de causalidade/dificuldade. `locale` já informa o idioma ao backend,
mas a interface atual permanece em português. Não há garantia de ausência
de bugs nem certificação de que o jogo esteja pronto para lançamento global.

Referências oficiais consultadas:
- https://ai.google.dev/gemini-api/docs/structured-output
- https://ai.google.dev/api/interactions-api
- https://docs.godotengine.org/en/stable/classes/class_navigationpolygon.html
