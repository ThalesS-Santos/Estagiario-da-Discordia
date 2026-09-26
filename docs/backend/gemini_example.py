"""Server-side adapter example, not a public HTTP server.

Requires google-genai and pydantic v2 in YOUR backend environment.
GEMINI_API_KEY and GEMINI_MODEL are server environment variables.
Do not export this directory with the game. No request is sent on import.
"""

import asyncio
import json
import os
from typing import Literal

from google import genai
from pydantic import BaseModel, ConfigDict, Field


class NPCUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    npc_id: str
    dialogue_bubble: str = Field(max_length=240)
    new_state: Literal["IDLE", "WALK", "RUN", "AFRAID", "ANGRY", "TALK", "FALLEN"]
    target_node_to_move: str
    fear_level: int = Field(ge=0, le=100)
    anger_level: int = Field(ge=0, le=100)
    loyalty_level: int = Field(ge=0, le=100)


class ButterflyEffect(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    schema_version: Literal[1]
    instability_delta: float = Field(ge=-20, le=45, allow_inf_nan=False)
    npc_updates: list[NPCUpdate] = Field(max_length=12)


def validate_response(text: str, npc_ids: set[str], location_ids: set[str]) -> dict:
    if len(text.encode("utf-8")) > 65536:
        raise ValueError("Oversized model response")
    result = ButterflyEffect.model_validate_json(text)
    seen: set[str] = set()
    for update in result.npc_updates:
        if update.npc_id not in npc_ids or update.npc_id in seen:
            raise ValueError("Unknown or duplicate NPC")
        seen.add(update.npc_id)
        if update.target_node_to_move and update.target_node_to_move not in npc_ids | location_ids:
            raise ValueError("Unknown destination")
    return result.model_dump()


async def evaluate(
    trusted_payload: dict,
    trusted_system_prompt: str,
    npc_ids: set[str],
    location_ids: set[str],
) -> dict:
    """Called AFTER authentication, quotas and authoritative input validation.

    Pass the server-owned prompt corresponding to AIContract.SYSTEM_PROMPT.
    NPC/location registries come from server data, never client allow-lists.
    Catch provider errors in /simulate and return 502/503 without raw details.
    """
    model = os.environ["GEMINI_MODEL"]
    payload = dict(trusted_payload)
    payload["allowed_npcs"] = sorted(npc_ids)
    payload["allowed_locations"] = sorted(location_ids)
    async with genai.Client(api_key=os.environ["GEMINI_API_KEY"]).aio as client:
        interaction = await asyncio.wait_for(
            client.interactions.create(
                model=model,
                system_instruction=trusted_system_prompt,
                input=json.dumps(payload, ensure_ascii=False),
                response_format={
                    "type": "text",
                    "mime_type": "application/json",
                    "schema": ButterflyEffect.model_json_schema(),
                },
            ),
            timeout=15.0,
        )
    if interaction.status != "completed" or not interaction.output_text:
        raise ValueError("Model did not complete a structured response")
    return validate_response(interaction.output_text, npc_ids, location_ids)
