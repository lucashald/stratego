class_name UnitIconCatalog
extends RefCounted

## The one place a (player, piece type) pair becomes a texture. Keeping the
## lookup here rather than in board_view.gd and main.gd stops the board, the
## roster and the battle cards from growing three different naming rules.
##
## Every faction now has its own set, so armies are told apart by their own
## cloth and crest rather than by a colour marker on shared art.

const FACTION_SETS: Dictionary = {
	StrategoGame.BLUE: {
		StrategoGame.LIGHT_INFANTRY: preload("res://assets/unit_icons/blue/li.png"),
		StrategoGame.MEDIUM_INFANTRY: preload("res://assets/unit_icons/blue/mi.png"),
		StrategoGame.HEAVY_INFANTRY: preload("res://assets/unit_icons/blue/hi.png"),
		StrategoGame.LIGHT_ARCHER: preload("res://assets/unit_icons/blue/la.png"),
		StrategoGame.MEDIUM_ARCHER: preload("res://assets/unit_icons/blue/ma.png"),
		StrategoGame.HEAVY_ARCHER: preload("res://assets/unit_icons/blue/ha.png"),
		StrategoGame.LIGHT_CAVALRY: preload("res://assets/unit_icons/blue/lc.png"),
		StrategoGame.MEDIUM_CAVALRY: preload("res://assets/unit_icons/blue/mc.png"),
		StrategoGame.HEAVY_CAVALRY: preload("res://assets/unit_icons/blue/hc.png"),
		StrategoGame.FLAG: preload("res://assets/unit_icons/blue/flag.png"),
	},
	StrategoGame.RED: {
		StrategoGame.LIGHT_INFANTRY: preload("res://assets/unit_icons/red/li.png"),
		StrategoGame.MEDIUM_INFANTRY: preload("res://assets/unit_icons/red/mi.png"),
		StrategoGame.HEAVY_INFANTRY: preload("res://assets/unit_icons/red/hi.png"),
		StrategoGame.LIGHT_ARCHER: preload("res://assets/unit_icons/red/la.png"),
		StrategoGame.MEDIUM_ARCHER: preload("res://assets/unit_icons/red/ma.png"),
		StrategoGame.HEAVY_ARCHER: preload("res://assets/unit_icons/red/ha.png"),
		StrategoGame.LIGHT_CAVALRY: preload("res://assets/unit_icons/red/lc.png"),
		StrategoGame.MEDIUM_CAVALRY: preload("res://assets/unit_icons/red/mc.png"),
		StrategoGame.HEAVY_CAVALRY: preload("res://assets/unit_icons/red/hc.png"),
		StrategoGame.FLAG: preload("res://assets/unit_icons/red/flag.png"),
	},
	StrategoGame.GREEN: {
		StrategoGame.LIGHT_INFANTRY: preload("res://assets/unit_icons/green/li.png"),
		StrategoGame.MEDIUM_INFANTRY: preload("res://assets/unit_icons/green/mi.png"),
		StrategoGame.HEAVY_INFANTRY: preload("res://assets/unit_icons/green/hi.png"),
		StrategoGame.LIGHT_ARCHER: preload("res://assets/unit_icons/green/la.png"),
		StrategoGame.MEDIUM_ARCHER: preload("res://assets/unit_icons/green/ma.png"),
		StrategoGame.HEAVY_ARCHER: preload("res://assets/unit_icons/green/ha.png"),
		StrategoGame.LIGHT_CAVALRY: preload("res://assets/unit_icons/green/lc.png"),
		StrategoGame.MEDIUM_CAVALRY: preload("res://assets/unit_icons/green/mc.png"),
		StrategoGame.HEAVY_CAVALRY: preload("res://assets/unit_icons/green/hc.png"),
		StrategoGame.FLAG: preload("res://assets/unit_icons/green/flag.png"),
	},
	StrategoGame.YELLOW: {
		StrategoGame.LIGHT_INFANTRY: preload("res://assets/unit_icons/yellow/li.png"),
		StrategoGame.MEDIUM_INFANTRY: preload("res://assets/unit_icons/yellow/mi.png"),
		StrategoGame.HEAVY_INFANTRY: preload("res://assets/unit_icons/yellow/hi.png"),
		StrategoGame.LIGHT_ARCHER: preload("res://assets/unit_icons/yellow/la.png"),
		StrategoGame.MEDIUM_ARCHER: preload("res://assets/unit_icons/yellow/ma.png"),
		StrategoGame.HEAVY_ARCHER: preload("res://assets/unit_icons/yellow/ha.png"),
		StrategoGame.LIGHT_CAVALRY: preload("res://assets/unit_icons/yellow/lc.png"),
		StrategoGame.MEDIUM_CAVALRY: preload("res://assets/unit_icons/yellow/mc.png"),
		StrategoGame.HEAVY_CAVALRY: preload("res://assets/unit_icons/yellow/hc.png"),
		StrategoGame.FLAG: preload("res://assets/unit_icons/yellow/flag.png"),
	},
}

## Shown for an enemy that can be seen but not identified. It carries the
## faction's own cloth and a question mark, and deliberately nothing else: Role
## and Strength are the secrets, so the banner must not hint at either. Weight
## is public, and the board draws the weight frame over this, which is why one
## banner per faction is enough rather than one per Weight.
const UNKNOWN_BANNERS: Dictionary = {
	StrategoGame.BLUE: preload("res://assets/unit_icons/blue/unknown.png"),
	StrategoGame.RED: preload("res://assets/unit_icons/red/unknown.png"),
	StrategoGame.GREEN: preload("res://assets/unit_icons/green/unknown.png"),
	StrategoGame.YELLOW: preload("res://assets/unit_icons/yellow/unknown.png"),
}


static func texture_for(player: int, piece_type: String) -> Texture2D:
	var set_for_player: Dictionary = FACTION_SETS.get(player, {})
	return set_for_player.get(piece_type) as Texture2D


static func texture_for_piece(piece: Dictionary) -> Texture2D:
	if piece.is_empty(): return null
	return texture_for(int(piece.get("player", -1)), String(piece.get("type", "")))


static func unknown_texture_for(player: int) -> Texture2D:
	return UNKNOWN_BANNERS.get(player) as Texture2D
