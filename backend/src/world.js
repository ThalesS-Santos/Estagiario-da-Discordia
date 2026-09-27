// Fonte da verdade do servidor: IDs, locais e o dossiê do mundo. O cliente NUNCA define isto.
export const NPCS = {
  npc_king: "Aldemar I, o Rei. Tirano orgulhoso; teme perder o trono; lealdade total à coroa.",
  npc_baker: "João da Padaria, padeiro fofoqueiro e crédulo; espalha boatos rápido. Guarda rancor de Bram por uma dívida de 10 moedas não paga há semanas — precisa de pressão externa para ter coragem de cobrar em público.",
  npc_smith: "Gordo Marten, ferreiro rude e temperamental; desconfia da guarda.",
  npc_guard: "Bram, guarda do portão do castelo; leal, cético, disciplinado. Tem uma dívida não paga com João da Padaria (10 moedas) que o envergonha. Abandona o posto quando há tumulto sério na praça central ou na ferraria — instinto mais forte que o dever. Teme humilhação pública.",
  npc_priestess: "Mira, sacerdotisa; calma, moral, reage forte a sacrilégios.",
  npc_merchant: "Valdo, mercador oportunista; só lealdade ao lucro.",
  npc_orphan: "Lila, órfã; assustadiça, muito crédula, vê tudo.",
  villager_farmer: "Tobias, fazendeiro; simples e supersticioso.",
  villager_woman: "Helga, camponesa; comenta tudo com todos.",
  villager_elder: "Ancião Osric; respeitado, sábio, difícil de enganar. Vigia o portão do castelo de longe e alerta Bram se perceber algo suspeito.",
  villager_boy: "Pip, menino; curioso e ingênuo.",
  villager_lady: "Dama Isolde, nobre; vaidosa, teme escândalos.",
};

export const LOCATIONS = {
  throne: "sala do trono", castle_gate: "portão do castelo", castle_yard: "pátio do castelo",
  fountain: "fonte da praça", plaza: "praça central", well: "poço", notice_board: "mural de avisos",
  stall: "banca do mercador", bakery: "padaria", residence: "casas", forge: "ferraria",
  temple: "templo", lake: "lago", forest: "floresta", road_south: "estrada sul", open_field: "campo aberto",
};

export const STATES = ["IDLE", "WALK", "RUN", "AFRAID", "ANGRY", "TALK", "FALLEN"];
export const NPC_IDS = new Set(Object.keys(NPCS));
export const LOCATION_IDS = new Set(Object.keys(LOCATIONS));
