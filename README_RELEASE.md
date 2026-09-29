# 🦋 O Paradoxo do Estagiário

**Game Jam CIMATEC 2026.2: Efeito Borboleta**

## 📖 Sobre o Jogo

Um jogo 2D top-down em pixel art onde você é um estagiário de uma agência interdimensional (Agência Panóptico) em uma vila medieval. Sua missão: **derrubar o Rei Aldemar I em 3 dias sem violência**.

### Como jogar:
- **Mover**: WASD ou Setas
- **Interagir**: E (pegar objetos) ou S (sussurrar boatos)
- **Modo Furtivo**: Shift (se mover silenciosamente)
- **Desfazer**: Z
- **Status**: TAB
- **Menu**: ESC

### Mecânicas:
- **3 dias × 3 ações por dia** = 9 ações totais
- Pegar um objeto custa **1 PA**
- Soltar com um boato custa **1 PA**
- Sussurrar para um NPC custa **1 PA**
- Ganhe ao atingir **100 de Instabilidade Social**
- A IA (Gemini) simula como os NPCs reagem aos seus atos

## 🎮 Sistema de Ação

1. **Pegar + Narrativa**: pegue um objeto e solte com uma história (ex: "Essa cerveja é envenenada!") → os NPCs reagem
2. **Sussurro**: converse com NPCs para propagar boatos
3. **Observar**: veja como a vila muda com cada ação

## 🎨 Arte

- Estilo **pixel art moderno** inspirado em Pokémon FireRed/Emerald
- Sprites 64×72 px com escala 2×
- Paleta extraída do Kenney Tiny Town (CC0)
- Todos os ativos gerados proceduralmente em Python

## 🤖 IA

O jogo usa o **Google Gemini** para simular as reações dos NPCs em tempo real. A conexão é feita via **Cloudflare Workers** (servidor privado) para maior segurança.

Se a IA ficar offline, o jogo usa um modo de **fallback local** e continua funcionando normalmente.

## 📋 Requisitos

- **Windows 10+** (x64)
- 500 MB de espaço livre
- Conexão à internet (para IA; modo offline funciona)

## 🛠️ Controles de Debug

- `F1`: Teleportar para mouse
- `F2`: Spawn objeto em mouse
- `F3`: Log de estado
- `F4`: Toggle câmera de mundo/jogador

## 📚 Créditos

- **Arte**: Kenney Tiny Town & Tiny Dungeon (CC0)
- **Motor**: Godot 4.7
- **IA**: Google Gemini API
- **Feito para**: Game Jam CIMATEC 2026.2

## 📞 Contato

Desenvolvedor: ThalesS-Santos  
Email: thalessena272006@gmail.com

---

**Deadline**: 28/09/2026 23h59  
**Submissão**: itch.io
