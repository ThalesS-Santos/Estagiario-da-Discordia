# Backend de IA — O Paradoxo do Estagiário

Proxy serverless na **Cloudflare Workers**. Ele guarda a chave do Gemini (que **nunca** vai no jogo), monta o prompt do Diretor de Cena, chama o Gemini e devolve ao jogo só o resultado validado. Como é serverless, **não existe máquina para manter ligada**: fica no ar 24h por dia sozinho, e o plano gratuito cobre 100 mil requisições por dia.

```
Jogo (.exe / HTML5) --POST /simulate--> Worker (chave secreta) --> Gemini
                     <-- efeito validado --
```

Se o servidor ou o Gemini falhar, o próprio jogo usa o Diretor local e a partida continua (uma mensagem "IA offline" aparece). Ainda assim, o objetivo é o servidor ficar no ar durante todo o julgamento.

## Publicar (uma vez, ~10 minutos)

Pré-requisitos: conta gratuita na [Cloudflare](https://dash.cloudflare.com/sign-up), [Node.js](https://nodejs.org) 18+ e uma chave do Gemini criada em [Google AI Studio](https://aistudio.google.com/apikey).

```bash
cd backend
npm install
npx wrangler login                      # abre o navegador para autorizar
npx wrangler secret put GEMINI_API_KEY  # cole a chave quando pedir (fica só na Cloudflare)
npx wrangler deploy
```

O último comando imprime a URL, algo como `https://paradoxo-estagiario-ia.SEU-USUARIO.workers.dev`.

### Testar

```bash
curl https://paradoxo-estagiario-ia.SEU-USUARIO.workers.dev/health
# {"ok":true,"models":[...],"key_configured":true}

curl -X POST https://paradoxo-estagiario-ia.SEU-USUARIO.workers.dev/simulate \
  -H "Content-Type: application/json" \
  -d '{"player_action":"Colocou o frasco de veneno no poço","gossip":"O rei mandou envenenar a água","npcs_state":{"npc_baker":{"fear":30,"anger":20,"loyalty":40,"credulity":75},"npc_guard":{"fear":10,"anger":30,"loyalty":95,"credulity":35}},"context":{"day":1,"instability":5,"rumors":0}}'
```

> **PowerShell:** as aspas do `-d '...'` quebram no PowerShell (erro `invalid_json`) e `curl` ali é apelido de `Invoke-WebRequest`. Use `curl.exe` com um arquivo: salve o JSON em `teste.json` e rode `curl.exe -X POST URL/simulate -H "Content-Type: application/json" --data-binary "@teste.json"`.

A resposta deve ser um JSON com `instability_delta` e `npc_updates`. Se vier `502 ai_unavailable`, confira o modelo e a chave (abaixo).

### Ligar o jogo ao servidor

No Godot: **Project → Project Settings → (Advanced) `game/ai/backend_url`** e cole a URL **sem** barra no final. O valor também pode vir da variável de ambiente `PARADOXO_BACKEND_URL` (útil em testes). Faça isso **antes de exportar** o executável.

## Modelos

O padrão é `gemini-2.5-flash`, com reservas `gemini-2.0-flash` e `gemini-2.5-flash-lite`, tentados em ordem quando há 404, quota (429) ou erro do servidor. Os nomes disponíveis mudam com o tempo e por conta, então **confirme** com sua chave:

```bash
curl "https://generativelanguage.googleapis.com/v1beta/models?key=SUA_CHAVE" | findstr "name"
```

Para trocar, edite `GEMINI_MODEL` e `GEMINI_FALLBACK_MODELS` em `wrangler.toml` e rode `npx wrangler deploy`.

## Cotas e custos (importante para o dia do julgamento)

- O plano gratuito do Gemini tem limite de requisições por minuto e por dia. Vários jurados jogando ao mesmo tempo podem estourar. Para ficar seguro, ative o **faturamento** no projeto da chave (o custo do Flash para este uso é muito baixo) e crie um **alerta de orçamento** no Google Cloud.
- Use uma chave **exclusiva** deste projeto, restrita à *Generative Language API*. Se vazar, revogue e rode `npx wrangler secret put GEMINI_API_KEY` de novo.
- O Worker limita cada IP a 6 pedidos por minuto (`RATE_LIMIT_PER_MINUTE`). Para uma proteção mais forte, crie uma regra de *Rate limiting* no painel da Cloudflare para a rota `/simulate`.
- Monitore em **Workers & Pages → paradoxo-estagiario-ia → Metrics/Logs**.

## Desenvolvimento local

```bash
copy .dev.vars.example .dev.vars   # coloque sua chave (o arquivo é ignorado pelo git)
npm run dev                        # http://127.0.0.1:8787
```

No Godot, use `PARADOXO_BACKEND_URL=http://127.0.0.1:8787` para testar contra o Worker local.

## Testes

```bash
npm test
```

Cobrem validação tolerante, o fluxo completo com Gemini simulado, o segredo indo no header (nunca na URL), a troca de modelo reserva, o `502` quando tudo falha e o limite por IP. Não fazem chamadas reais.

## Segurança

- A chave só existe como *secret* da Cloudflare. Nada de chave no repositório, no jogo ou nos logs.
- O servidor define o prompt, os IDs de NPCs e de locais; o cliente só envia dados de jogo, e tudo é limitado e validado. A resposta do modelo é sanitizada (IDs conhecidos, sem duplicatas, valores dentro dos limites) e só ela chega ao jogo.
- Texto do jogador é tratado como dado não confiável no prompt.
