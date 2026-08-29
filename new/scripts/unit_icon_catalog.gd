class_name UnitIconCatalog
extends RefCounted

## Temporary shared art catalog. Until the other faction sets are ready, every
## player resolves to the same normalized Green formation textures.
const GREEN_TEXTURES: Dictionary = {
	StrategoGame.LIGHT_INFANTRY: preload("res://assets/unit_icons/green/li.png"),
	StrategoGame.MEDIUM_INFANTRY: preload("res://assets/unit_icons/green/mi.png"),
	StrategoGame.HEAVY_INFANTRY: preload("res://assets/unit_icons/green/hi.png"),
	StrategoGame.LIGHT_ARCHER: preload("res://assets/unit_icons/green/la.png"),
	StrategoGame.MEDIUM_ARCHER: preload("res://assets/unit_icons/green/ma.png"),
	StrategoGame.HEAVY_ARCHER: preload("res://assets/unit_icons/green/ha.png"),
	StrategoGame.LIGHT_CAVALRY: preload("res://assets/unit_icons/green/lc.png"),
	StrategoGame.MEDIUM_CAVALRY: preload("res://assets/unit_icons/green/mc.png"),
	StrategoGame.HEAVY_CAVALRY: preload("res://assets/unit_icons/green/hc.png"),
}


static func texture_for_type(piece_type: String) -> Texture2D:
	return GREEN_TEXTURES.get(piece_type) as Texture2D


static func texture_for_piece(piece: Dictionary) -> Texture2D:
	if piece.is_empty(): return null
	return texture_for_type(String(piece.get("type", "")))
