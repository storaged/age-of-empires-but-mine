class_name StateHasher
extends RefCounted

## Computes hash from canonical authoritative state only.


func compute_authoritative_state_hash(game_state: GameState) -> String:
	return game_state.serialize_canonical().sha256_text()
