class_name MatchConfig
extends RefCounted

## Canonical source of match-level configuration.
## Pass one instance from the pregame screen into the gameplay scene.
## All fields have defaults so the game launches without explicit configuration.

# ── map ──────────────────────────────────────────────────────────────────────
var map_width: int = 20
var map_height: int = 14

# ── colors (player faction 1) ─────────────────────────────────────────────────
var player_soldier_color: Color = Color("#4a7fc1")
var player_unit_color: Color = Color("#d6d2c4")
var player_archer_color: Color = Color("#2ec4b6")

# ── colors (enemy faction 2) ──────────────────────────────────────────────────
var enemy_unit_color: Color = Color("#e84a1e")
var enemy_structure_color: Color = Color("#c93a1a")

# ── AI timing ────────────────────────────────────────────────────────────────
var ai_production_start_tick: int = 180
var ai_production_interval_ticks: int = 55
var ai_attack_start_tick: int = 420
var ai_attack_wave_interval_ticks: int = 120
var ai_min_attackers_per_wave: int = 3


