# Horns-up
Jogo bode

## Rodar

- Jogo: `godot --path .` (A/D ou setas andam, Espaço pula, J ataca). Com o martelo de gelo, segurar contra uma parede de gelo no ar gruda nela; Espaço pula de parede.
- Testes: `godot --headless --path . --import` (só na primeira vez, registra os `class_name`) e depois `godot --headless --path . -s tests/run_tests.gd`. Sai com código 1 se algo falhar.
