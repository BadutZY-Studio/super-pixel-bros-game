extends RefCounted
## Shop catalog + runtime sprite baking for every cosmetic (skins, suits, hats, face, back, trails).
##
## No PNG files are needed: the hero sprites are rebuilt from the same pixel maps that
## tools/gen_assets.py uses, with a palette per skin / suit, then hats, face items and back
## items are drawn on top / behind with the same dark outline as the original art.
## The result is one sprite sheet per form (small / big / fire) in a 32 px wide frame
## (the body sits in the middle 16 px, the rest is room for hats and capes).

const SLOTS := ["skin", "suit", "hat", "face", "back", "trail"]
const SLOT_NAMES := {"skin": "SKIN", "suit": "SUIT", "hat": "HAT", "face": "FACE", "back": "BACK", "trail": "TRAIL"}
const REMOVABLE := ["hat", "face", "back", "trail"]  # skin and suit always have one equipped

const CW := 32          # frame width
const PAD_TOP := 14     # extra rows above the body for tall hats
const BX := 8           # x of the body inside the frame
const FIRE_WHITE := "f5f5f5"
const OUTLINE_COLOR := Color(24.0 / 255.0, 16.0 / 255.0, 32.0 / 255.0)

const POSES := ["idle", "run1", "run2", "run3", "jump", "skid", "die"]
const ANIMS := {
	"idle": {"frames": [0], "fps": 1, "loop": true},
	"run": {"frames": [1, 2, 3], "fps": 10, "loop": true},
	"jump": {"frames": [4], "fps": 1, "loop": true},
	"skid": {"frames": [5], "fps": 1, "loop": true},
	"die": {"frames": [6], "fps": 1, "loop": true},
}

# ------------------------------------------------------------------ base hero art (same as gen_assets.py)
# K = cap (follows the shirt colour), N = hair, S = skin, E = eye / nose shade
const HEAD := [
	"....KKKKK.......",
	"...KKKKKKKKK....",
	"...NNNSSESS.....",
	"..NSNSSSESSSS...",
	"..NSNNSSSESSSS..",
	"..NNSSSSNNNN....",
	"....SSSSSSS.....",
]
# rows 0 and 1 when a hat replaces the cap
const HEAD_BARE := [
	"....NNNNN.......",
	"...NNNNSSSS.....",
]
const TORSO := [
	"...RRRBRRR......",
	"..RRRRBRRBRRR...",
	"..RRRRBBBBRRR...",
	"..WWRBYBBYBWW...",
	"..WWBBBBBBBBWW..",
	"..WBBBBBBBBBW...",
]
const TORSO_JUMP := [
	"..WRRRBRRR......",
	".WWRRRBRRBRRW...",
	".WWRRBBBBRRWW...",
	"..RRBYBBYBR.....",
	"...BBBBBBBB.....",
	"..BBBBBBBBBB....",
]
const STAND_TOP := "...BBB..BBB....."
const LEGS := {
	"idle": ["...BBB..BBB.....", ["..OOO....OOO....", ".OOOO....OOOO..."]],
	"run1": ["..BBB....BBB....", [".OOO......OOO...", "OOOO.....OOOO..."]],
	"run2": ["...BBBBBBB......", ["...OOOOOOO......", "...OOOOOOO......"]],
	"run3": ["....BB..BBB.....", ["...OOO...OOOO...", "..OOO....OOOO..."]],
	"jump": ["..BBB....BBBB...", ["OOOO.....OOOO...", "OOO.......OOO...."]],
	"skid": ["...BB....BB.....", ["..OOO.....OO....", ".OOOO....OOOO..."]],
	"die": ["..BBB....BBBB...", ["OOOO.....OOOO...", "OOO.......OOO...."]],
}
# how small-head rows map onto the taller head of the big / fire form (rows >= 7 shift by 2)
const BIG_HEAD_ROWS := {0: [0], 1: [1], 2: [2], 3: [3, 4], 4: [5, 6], 5: [7], 6: [8]}

const BASE_PAL := {
	"R": "e02424", "B": "3454e0", "Y": "ffdc3c", "W": "fafafa",
	"N": "6e3c14", "S": "ffcc9c", "E": "141414", "O": "8c501e",
}

static var _items: Array = []
static var _index: Dictionary = {}
static var _frames_cache: Dictionary = {}
static var _small_cache: Dictionary = {}
static var _thumb_cache: Dictionary = {}
static var _col_cache: Dictionary = {}
static var _shape_cache: Dictionary = {}


# ------------------------------------------------------------------ catalog
static func items() -> Array:
	if _items.is_empty():
		_build_catalog()
	return _items


static func by_id(id: String) -> Dictionary:
	if _items.is_empty():
		_build_catalog()
	return _index.get(id, {})


static func in_slot(slot: String) -> Array:
	var out: Array = []
	for it in items():
		if it["slot"] == slot:
			out.append(it)
	return out


static func default_loadout() -> Dictionary:
	return {"skin": "skin_classic", "suit": "suit_classic", "hat": "", "face": "", "back": "", "trail": ""}


static func free_ids() -> Array:
	return ["skin_classic", "suit_classic"]


static func sig(lo: Dictionary) -> String:
	var parts: Array = []
	for s in SLOTS:
		parts.append(String(lo.get(s, "")))
	return "|".join(parts)


static func _add(slot: String, id: String, nm: String, price: int, desc: String, extra: Dictionary) -> void:
	var d := {"slot": slot, "id": slot + "_" + id, "name": nm, "price": price, "desc": desc}
	d.merge(extra, true)
	_items.append(d)
	_index[d["id"]] = d


static func _build_catalog() -> void:
	_items.clear()
	_index.clear()
	# ---------------------------------------------------------------- SKINS (full colour sets)
	_add("skin", "classic", "CLASSIC", 0, "THE ORIGINAL HERO", {"pal": {}})
	_add("skin", "emerald", "EMERALD", 40, "ALL GREEN, ALL GOOD",
		{"pal": {"R": "2fb350", "B": "1d5a3e", "Y": "ffe066", "N": "5a3a1a", "O": "4a3018"}})
	_add("skin", "ocean", "OCEAN", 40, "FRESH FROM THE DEEP",
		{"pal": {"R": "22b8c8", "B": "1f5fa8", "Y": "fff2a8", "N": "3a2a5a", "O": "20407a"}})
	_add("skin", "sakura", "SAKURA", 50, "PINK AND PRETTY",
		{"pal": {"R": "ff7eb6", "B": "c04a8a", "Y": "fff0a0", "W": "fff5fa", "N": "d84a86", "O": "7a2a5a"}})
	_add("skin", "ember", "EMBER", 60, "BORN IN THE FIRE",
		{"pal": {"R": "ff7a1a", "B": "8a1c1c", "Y": "ffe36b", "W": "ffd9a0", "N": "3a1a0a", "O": "5a2410"}})
	_add("skin", "violet", "VIOLET", 60, "ROYAL PURPLE VIBES",
		{"pal": {"R": "9a52e0", "B": "40308a", "Y": "ffd84a", "N": "2a1450", "O": "301860"}})
	_add("skin", "frost", "FROST", 80, "COOL AS ICE",
		{"pal": {"R": "9fd8ff", "B": "5b8fd0", "Y": "ffffff", "W": "ffffff", "S": "ffe2d0", "N": "dfeaff", "O": "6a8ab0"}})
	_add("skin", "zombie", "ZOMBIE", 90, "BRAAAINS... AND COINS",
		{"pal": {"R": "8a8aa8", "B": "56704c", "Y": "c8c060", "W": "9ab08a", "S": "8fbf78", "N": "4a5a40", "E": "d83030", "O": "3a3a3a"}})
	_add("skin", "shadow", "SHADOW", 100, "STRIKES FROM THE DARK",
		{"pal": {"R": "3a3a52", "B": "1c1c2a", "Y": "e04040", "W": "2e2e44", "S": "e8c9a8", "N": "101018", "E": "ff4040", "O": "202030"}})
	_add("skin", "robot", "ROBOT", 140, "BEEP BOOP, JUMP JUMP",
		{"pal": {"R": "6a86c0", "B": "3e4e78", "Y": "40e0ff", "W": "d0dcec", "S": "b8c4d4", "N": "5a6a88", "E": "ff3a3a", "O": "2c3450"}})
	_add("skin", "skeleton", "SKELETON", 150, "SPOOKY SCARY BONES",
		{"pal": {"R": "30303c", "B": "484858", "Y": "eeeadd", "W": "eeeadd", "S": "eeeadd", "N": "bdb8a8", "O": "6a6a72"}})
	_add("skin", "golden", "GOLDEN", 250, "SOLID GOLD LEGEND",
		{"pal": {"R": "ffc828", "B": "c87818", "Y": "ffffff", "W": "fff0a8", "S": "ffd870", "N": "b87818", "E": "40200a", "O": "9a5a10"}})
	# ---------------------------------------------------------------- SUITS (shirt + overalls only)
	_add("suit", "classic", "ORIGINAL", 0, "THE CLASSIC OVERALLS", {"pal": {}})
	_add("suit", "farmer", "FARMER", 25, "READY FOR THE HARVEST",
		{"pal": {"R": "f2c230", "B": "3f8f3f", "Y": "ffffff", "W": "f5e6c8"}})
	_add("suit", "sport", "SPORT", 30, "TRACK STAR STRIPES",
		{"pal": {"R": "2a8cff", "R2": "ffffff", "B": "ffffff", "Y": "ff4040", "W": "ffffff"}})
	_add("suit", "camo", "CAMO", 40, "HARD TO SPOT",
		{"pal": {"R": "6b8a45", "R2": "4a6330", "B": "8a7a45", "Y": "c8b060", "W": "4a6330"}})
	_add("suit", "sailor", "SAILOR", 45, "ANCHORS AWEIGH",
		{"pal": {"R": "f4f4f8", "R2": "2a4fd0", "B": "1a2f7a", "Y": "ffd040", "W": "f4f4f8"}})
	_add("suit", "pirate", "PIRATE", 60, "YO HO HO",
		{"pal": {"R": "e8e8ee", "R2": "20202a", "B": "5a3a24", "Y": "ffd040", "W": "20202a"}})
	_add("suit", "arctic", "ARCTIC", 70, "BUILT FOR BLIZZARDS",
		{"pal": {"R": "bfe4ff", "R2": "ffffff", "B": "5a8fd8", "Y": "ffffff", "W": "ffffff"}})
	_add("suit", "tuxedo", "TUXEDO", 90, "BLACK TIE AFFAIR",
		{"pal": {"R": "24242e", "B": "24242e", "Y": "e83a3a", "W": "ffffff"}})
	_add("suit", "ninja", "NINJA", 100, "SILENT BUT STYLISH",
		{"pal": {"R": "2a2a3c", "R2": "3c3c54", "B": "2a2a3c", "Y": "d83030", "W": "2a2a3c"}})
	_add("suit", "royal", "ROYAL", 120, "FIT FOR A KING",
		{"pal": {"R": "7a2cb0", "R2": "9a4cd0", "B": "55208a", "Y": "ffe060", "W": "ffe060"}})
	_add("suit", "lava", "LAVA", 150, "HOT HOT HOT",
		{"pal": {"R": "ff6a1a", "R2": "ffc030", "B": "6a1a1a", "Y": "fff08a", "W": "ffb060"}})
	_add("suit", "rainbow", "RAINBOW", 200, "TASTE THE RAINBOW",
		{"pal": {"R": "e02424", "B": "3a3a8a", "Y": "ffffff", "W": "ffffff",
			"cycle": ["e02424", "ff8a1a", "ffe03a", "34c04a", "2a8cff", "9a52e0"]}})
	# ---------------------------------------------------------------- HATS
	_add("hat", "beanie", "BEANIE", 15, "WARM AND COZY", {"y0": -3, "pal": {"B": "3a6fe0", "W": "ffffff", "w": "c8d8ff"}, "rows": [
		"......WW........",
		".....WWWW.......",
		"....BBBBBB......",
		"...BBBBBBBB.....",
		"...WwWwWwWW.....",
	]})
	_add("hat", "party", "PARTY HAT", 20, "IT'S PARTY TIME", {"y0": -6, "pal": {"P": "ff5fa8", "Y": "ffe14a", "D": "c83a80"}, "rows": [
		"......YY........",
		"......PP........",
		".....PPPP.......",
		".....PYPD.......",
		"....PPPPYD......",
		"....PYPPPD......",
		"...YYYYYYYY.....",
	]})
	_add("hat", "catears", "CAT EARS", 25, "PURR-FECT STYLE", {"y0": -3, "pal": {"K": "2a2a34", "P": "ff8fb0"}, "rows": [
		"...K......K.....",
		"...KK....KK.....",
		"...KPK..KPK.....",
		"...KKKKKKKK.....",
	]})
	_add("hat", "tophat", "TOP HAT", 30, "VERY FANCY INDEED", {"y0": -7, "pal": {"K": "26262e", "G": "56566a", "R": "d02838"}, "rows": [
		"....KKKKK.......",
		"....KGKKK.......",
		"....KGKKK.......",
		"....KGKKK.......",
		"....KKKKK.......",
		"....RRRRR.......",
		"....RRRRR.......",
		"..KKKKKKKKK.....",
	]})
	_add("hat", "cowboy", "COWBOY HAT", 35, "YEEHAW PARTNER", {"y0": -3, "pal": {"B": "c08840", "D": "8a5a28", "K": "5a3414"}, "rows": [
		"....BBDDBB......",
		"....BBBBBB......",
		".B..KKKKKK..B...",
		".BBBBBBBBBBBB...",
	]})
	_add("hat", "chef", "CHEF HAT", 40, "COOKING UP COINS", {"y0": -6, "pal": {"W": "ffffff", "w": "d0d4e8", "G": "b8bcd4"}, "rows": [
		".....WWWW.......",
		"...WWWWWWWW.....",
		"..WWWWwWWWWW....",
		"..WWWWWWWWWw....",
		"...WWWWWWWw.....",
		"....WWwWWW......",
		"....WWWWWW......",
		"...GGGGGGGG.....",
	]})
	_add("hat", "pirate", "PIRATE HAT", 55, "ARRR, MATEY", {"y0": -4, "pal": {"K": "20202a", "W": "f4f4f8", "G": "d8a820"}, "rows": [
		"....KKKKK.......",
		"...KKKKKKK......",
		"..KKKWWWKKK.....",
		".KKKKWKWKKKK....",
		"GKKKKKKKKKKKG...",
	]})
	_add("hat", "viking", "VIKING", 70, "FOR VALHALLA", {"y0": -4, "pal": {"W": "f0ead8", "w": "c8c0a8", "S": "9aa4b8", "s": "c8d0e0", "B": "7a4a20"}, "rows": [
		".W..........W..",
		".WW........WW..",
		".wWSSSSSSSSWw..",
		"..WSsSSSSSSW...",
		"...SSSSSSSSS...",
		"...BBBBBBBBB...",
	]})
	_add("hat", "wizard", "WIZARD HAT", 90, "ABRACADABRA", {"y0": -9, "pal": {"P": "6a3ad0", "D": "4a24a0", "Y": "ffe14a", "S": "fff4a0"}, "rows": [
		".........P......",
		"........PP......",
		"........PPD.....",
		".......PPPD.....",
		".......PSPPD....",
		"......PPPPPD....",
		".....PPPPPPPD...",
		".....YYYYYYYY...",
		"..PPPPPPPPPPPP..",
	]})
	_add("hat", "halo", "HALO", 120, "ANGELIC VIBES", {"y0": -5, "float": true, "pal": {"Y": "fff08a", "y": "d89a1a", "g": "ffc830"}, "rows": [
		"....yggggy......",
		"...yYy..yYy.....",
		"....yggggy......",
	]})
	_add("hat", "crown", "CROWN", 200, "LONG LIVE THE KING", {"y0": -3, "pal": {"Y": "ffd23a", "D": "c08a10", "R": "e83a4a", "B": "3a8aff", "G": "3ad06a"}, "rows": [
		"...Y..YY..Y.....",
		"...YYYYYYYY.....",
		"...YRYYBYGY.....",
		"...DDDDDDDD.....",
	]})
	# ---------------------------------------------------------------- FACE
	_add("face", "roundglasses", "ROUND SPECS", 15, "SMART AND SHARP", {"y0": 1, "pal": {"G": "e8b830"}, "rows": [
		"......GGGGG.....",
		"....GGG...G.....",
		"......G...G.....",
		"......GGGGG.....",
	]})
	_add("face", "clownnose", "CLOWN NOSE", 20, "HONK HONK", {"y0": 3, "pal": {"R": "e8283a", "H": "ff9aa8"}, "rows": [
		"...........HR...",
		"...........RRR..",
	]})
	_add("face", "mask", "MASK", 25, "STAY SAFE OUT THERE", {"y0": 4, "pal": {"M": "8fd0e8", "m": "5ea8c8"}, "rows": [
		"......MMMMMMM...",
		"....mMMMMMMM....",
		".....mmmmmm.....",
	]})
	_add("face", "eyepatch", "EYEPATCH", 30, "ONE EYE ON THE PRIZE", {"y0": 1, "pal": {"K": "18181c"}, "rows": [
		".....KKK........",
		"......KKKKK.....",
		".......KKK......",
		".......KKK......",
	]})
	_add("face", "shades", "SHADES", 40, "TOO COOL FOR SCHOOL", {"y0": 2, "pal": {"K": "141418", "L": "9ad0ff"}, "rows": [
		"....KKKKKKKK....",
		"......KLKKKK....",
		"......KKKKKK....",
	]})
	_add("face", "glasses3d", "3D GLASSES", 50, "POP OUT OF THE SCREEN", {"y0": 2, "pal": {"K": "20202a", "R": "ff3040", "C": "30d8ff"}, "rows": [
		"....KKKKKKKKK...",
		"......KRRCCCK...",
		"......KRRCCCK...",
		"......KKKKKKK...",
	]})
	_add("face", "beard", "BIG BEARD", 60, "MAJESTIC FACIAL HAIR", {"y0": 5, "pal": {"B": "5a3418", "b": "7a4a24"}, "rows": [
		"....BBBBBBBB....",
		"....bBBBBBB.....",
		".....BbBBB......",
	]})
	# ---------------------------------------------------------------- BACK
	_add("back", "backpack", "BACKPACK", 30, "ADVENTURE ESSENTIALS", {"kind": "pack", "pal": {"G": "3c7a3c", "g": "5ca85a", "D": "28502a", "S": "8c5a24"}})
	_add("back", "shell", "SHELL", 40, "SLOW AND STEADY", {"kind": "shell", "pal": {"G": "36b04a", "g": "58d06a", "D": "1e7434", "Y": "f0dc96", "y": "c8b070"}})
	_add("back", "redcape", "RED CAPE", 60, "EVERY HERO NEEDS ONE", {"kind": "cape", "pal": {"A": "e02a2a", "B": "a01820", "T": "ffd23a"}})
	_add("back", "royalcape", "ROYAL CAPE", 90, "VELVET AND GOLD", {"kind": "cape", "pal": {"A": "6a2ab8", "B": "46187e", "T": "ffffff"}})
	_add("back", "angelwings", "ANGEL WINGS", 130, "SOAR THROUGH THE SKY", {"kind": "wings", "pal": {"W": "ffffff", "L": "c4d4f4", "D": "8aa0d0"}})
	_add("back", "demonwings", "DEMON WINGS", 130, "A LITTLE BIT NAUGHTY", {"kind": "wings", "pal": {"W": "a03ad0", "L": "6a1e98", "D": "40105e"}})
	_add("back", "jetpack", "JETPACK", 160, "FLAMES WHEN YOU JUMP", {"kind": "jet", "pal": {"G": "8a96ac", "g": "c4cede", "D": "56607a", "R": "e03030", "F": "ff8a1a", "f": "ffe45a"}})
	# ---------------------------------------------------------------- TRAILS
	_add("trail", "bubbles", "BUBBLES", 25, "POP POP POP", {"shape": "bubble", "colors": ["bfeaff", "8ad4ff", "e8f8ff"], "rate": 0.09})
	_add("trail", "snow", "SNOWFALL", 35, "A CHILL IN THE AIR", {"shape": "flake", "colors": ["ffffff", "d8ecff"], "rate": 0.07})
	_add("trail", "sparkle", "SPARKLE", 45, "SHINE BRIGHT", {"shape": "star", "colors": ["ffe45a", "ffffff", "fff0a0"], "rate": 0.07})
	_add("trail", "hearts", "HEARTS", 55, "SPREAD THE LOVE", {"shape": "heart", "colors": ["ff5a8a", "ff8aaa", "ff3a6a"], "rate": 0.12})
	_add("trail", "fire", "FLAMES", 80, "BURNING RUBBER", {"shape": "flame", "colors": ["ff6a1a", "ffa020", "ffe040"], "rate": 0.05})
	_add("trail", "rainbow", "RAINBOW", 120, "A TRAIL OF COLOUR", {"shape": "dot", "colors": ["ff3a3a", "ff9a2a", "ffe03a", "3ad04a", "2a8cff", "9a52e0"], "rate": 0.04})


# ------------------------------------------------------------------ colours
static func _col(hex: String) -> Color:
	if not _col_cache.has(hex):
		_col_cache[hex] = Color.html("#" + hex)
	return _col_cache[hex]


static func _colors(spec: Dictionary) -> Dictionary:
	var out := {}
	for k in spec:
		var v = spec[k]
		if v is Array:
			var arr: Array = []
			for h in v:
				arr.append(_col(String(h)))
			out[k] = arr
		else:
			out[k] = _col(String(v))
	return out


## Final palette for a loadout and form (0 small, 1 big, 2 fire).
static func palette(lo: Dictionary, form: int) -> Dictionary:
	var skin := by_id(String(lo.get("skin", "skin_classic")))
	if skin.is_empty():
		skin = by_id("skin_classic")
	var spec: Dictionary = BASE_PAL.duplicate()
	spec.merge(skin["pal"], true)
	var suit := by_id(String(lo.get("suit", "suit_classic")))
	if not suit.is_empty() and suit["id"] != "suit_classic":
		spec.merge(suit["pal"], true)
	var p := _colors(spec)
	p["K"] = p["R"]
	if form == 2:
		var white := _col(FIRE_WHITE)
		var f := p.duplicate()
		f["B"] = p["R"]
		f["R"] = white
		f["W"] = white
		f["K"] = white
		f.erase("R2")
		f.erase("cycle")
		return f
	return p


# ------------------------------------------------------------------ composing one frame
static func compose(lo: Dictionary, form: int, pose: String) -> Image:
	var big := form > 0
	var bh := 32 if big else 16
	var img := Image.create_empty(CW, bh + PAD_TOP, false, Image.FORMAT_RGBA8)
	var hat := by_id(String(lo.get("hat", "")))
	var face := by_id(String(lo.get("face", "")))
	var back := by_id(String(lo.get("back", "")))
	var pal := palette(lo, form)
	if not back.is_empty():
		_paint_back(img, back, big, pose)
	_paint_body(img, pal, big, pose, not hat.is_empty())
	if not face.is_empty():
		_paint_head_art(img, face, big)
	if not hat.is_empty() and not hat.get("float", false):
		_paint_head_art(img, hat, big)
	_outline(img)
	if not hat.is_empty() and hat.get("float", false):
		_paint_head_art(img, hat, big)  # floating hats (halo) keep their own edge, no dark outline
	return img


static func _body_rows(big: bool, pose: String, bare: bool) -> Array:
	var head: Array = HEAD.duplicate()
	if bare:
		head[0] = HEAD_BARE[0]
		head[1] = HEAD_BARE[1]
	var torso: Array = TORSO_JUMP if (pose == "jump" or pose == "die") else TORSO
	var leg: Array = LEGS[pose]
	var blue: String = leg[0]
	var shoes: Array = leg[1]
	var rows: Array = []
	if big:
		for i in [0, 1, 2, 3, 3, 4, 4, 5, 6]:
			rows.append([head[i], 0])
		for i in [0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 5]:
			rows.append([torso[i], 1])
		for i in 4:
			rows.append([STAND_TOP, 2])
		for i in 5:
			rows.append([blue, 2])
		for s in shoes:
			rows.append([s, 2])
	else:
		for r in head:
			rows.append([r, 0])
		for r in torso:
			rows.append([r, 1])
		rows.append([blue, 2])
		for s in shoes:
			rows.append([s, 2])
	return rows


static func _paint_body(img: Image, pal: Dictionary, big: bool, pose: String, bare: bool) -> void:
	var rows := _body_rows(big, pose, bare)
	var tlen := 0
	for r in rows:
		if r[1] == 1:
			tlen += 1
	var ty := 0
	for y in rows.size():
		var row: String = rows[y][0]
		var is_torso: bool = rows[y][1] == 1
		for x in mini(row.length(), 16):
			var ch := row[x]
			if ch == ".":
				continue
			var c: Color
			if ch == "R" and is_torso:
				c = pal["R"]
				if pal.has("cycle"):
					var cyc: Array = pal["cycle"]
					c = cyc[clampi(int(float(ty) * cyc.size() / float(tlen)), 0, cyc.size() - 1)]
				elif pal.has("R2") and ty % 2 == 1:
					c = pal["R2"]
			else:
				c = pal[ch]
			img.set_pixel(BX + x, PAD_TOP + y, c)
		if is_torso:
			ty += 1


## Draws an art block anchored to the head. rows are small-form head rows (y0 may be negative);
## in the big / fire form they are stretched exactly like the head sprite itself.
static func _paint_head_art(img: Image, it: Dictionary, big: bool) -> void:
	var cols := _colors(it["pal"])
	var rows: Array = it["rows"]
	var y0: int = it["y0"]
	for i in rows.size():
		var r: int = y0 + i
		var targets: Array = [r]
		if big:
			if r >= 0 and r <= 6:
				targets = BIG_HEAD_ROWS[r]
			elif r > 6:
				targets = [r + 2]
		for t in targets:
			_blit_row(img, rows[i], 0, t, cols)


static func _blit_row(img: Image, row: String, x0: int, y: int, cols: Dictionary) -> void:
	var cy := PAD_TOP + y
	if cy < 0 or cy >= img.get_height():
		return
	for x in row.length():
		var ch := row[x]
		if ch == "." or ch == " " or not cols.has(ch):
			continue
		var cx := BX + x0 + x
		if cx >= 0 and cx < CW:
			img.set_pixel(cx, cy, cols[ch])


static func _blit(img: Image, rows: Array, x0: int, y0: int, cols: Dictionary) -> void:
	for i in rows.size():
		_blit_row(img, rows[i], x0, y0 + i, cols)


static func _outline(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and nx < w and ny >= 0 and ny < h and src.get_pixel(nx, ny).a > 0.0:
					img.set_pixel(x, y, OUTLINE_COLOR)
					break


# ------------------------------------------------------------------ back items
const WING_UP := [
	"..WW....",
	".WWWW...",
	"WWLLWW..",
	"WLLLLWW.",
	"WLLLLLWW",
	"WWLLLLLW",
	".WWLLLLD",
	"..WWLLDD",
	"....WDD.",
]
const WING_MID := [
	"........",
	"WW......",
	"WWWWW...",
	"WLLLWWW.",
	"WLLLLLWW",
	".WWLLLLD",
	"...WWDD.",
]
const WING_DOWN := [
	".WW.....",
	".WLW....",
	".WLLW...",
	"..WLLW..",
	"..WLLDW.",
	"..WWDD..",
	"...WD...",
]


static func _paint_back(img: Image, it: Dictionary, big: bool, pose: String) -> void:
	var top := 9 if big else 7
	var air := pose == "jump" or pose == "die"
	var phase := 0
	if pose.begins_with("run"):
		phase = int(pose.substr(3)) - 1
	var cols := _colors(it["pal"])
	match String(it["kind"]):
		"cape":
			_paint_cape(img, cols, top, big, pose, air, phase)
		"wings":
			var art: Array = WING_DOWN
			var wy := top + 1
			if air:
				art = WING_UP
				wy = top - 4
			elif pose.begins_with("run") or pose == "skid":
				art = WING_MID
				wy = top + (1 if phase == 1 else 0)
			_blit(img, art, -6, wy + (2 if big else 0), cols)
		"pack":
			var rows := ["DDDD", "DGGD", "DGgD", "DGGD", "DSSD", "DDDD"]
			if big:
				rows = ["DDDD", "DGGD", "DGgD", "DGGD", "DGGD", "DGgD", "DGGD", "DSSD", "DDDD"]
			_blit(img, rows, -1, top + 1, cols)
			_blit(img, ["S"], 2, top + 1, cols)
		"shell":
			var rows := [".DGGD.", "DGgGGD", "DYGYGD", "DGYGgD", ".DDDD."]
			if big:
				rows = [".DGGGD.", "DGgGGGD", "DYGYGYD", "DGYGgGD", "DYGYGYD", "DGgGYGD", ".DDDDD."]
			_blit(img, rows, -3, top + 1, cols)
		"jet":
			var rows := ["gGgG", "GDGD", "GDGD", "GDGD", "RRRR"]
			if big:
				rows = ["gGgG", "GDGD", "GDGD", "GDGD", "GDGD", "GDGD", "GDGD", "RRRR"]
			_blit(img, rows, -2, top + 1, cols)
			if air:
				var fy := top + 1 + rows.size()
				_blit(img, ["FfFf", ".FF.", ".F.."], -2, fy, cols)


static func _paint_cape(img: Image, cols: Dictionary, top: int, big: bool, pose: String, air: bool, phase: int) -> void:
	var length := 13 if big else 9
	var sweep := 0.15
	if air:
		sweep = 0.55
	elif pose.begins_with("run"):
		sweep = [0.38, 0.50, 0.32][phase]
	elif pose == "skid":
		sweep = -0.15
	for i in length:
		var shift := int(round(float(i) * sweep * (0.75 if big else 1.0)))
		var xr := 3 - shift
		var wd := 4 + int(float(i) * (0.28 if big else 0.45))
		var xl := xr - wd + 1
		for x in range(maxi(xl, -8), xr + 1):
			var ch := "A"
			if x == xl:
				ch = "B"
			if i == length - 1:
				ch = "T"
			elif i == length - 2 and x != xl:
				ch = "B"
			var cy := PAD_TOP + top + i
			if cy < img.get_height():
				img.set_pixel(BX + x, cy, cols[ch])


# ------------------------------------------------------------------ sprite sheets
static func sheet_for(lo: Dictionary, form: int) -> ImageTexture:
	var fh := (32 if form > 0 else 16) + PAD_TOP
	var sheet := Image.create_empty(CW * POSES.size(), fh, false, Image.FORMAT_RGBA8)
	for i in POSES.size():
		var f := compose(lo, form, POSES[i])
		sheet.blit_rect(f, Rect2i(0, 0, CW, fh), Vector2i(i * CW, 0))
	return ImageTexture.create_from_image(sheet)


## {"frames": [SpriteFrames small, big, fire], "tex": [ImageTexture x3]} - cached per loadout.
static func frames_for(lo: Dictionary) -> Dictionary:
	var key := sig(lo)
	if _frames_cache.has(key):
		return _frames_cache[key]
	if _frames_cache.size() > 30:
		_frames_cache.clear()
	var out := {"frames": [], "tex": []}
	for form in 3:
		var tex := sheet_for(lo, form)
		var fh := (32 if form > 0 else 16) + PAD_TOP
		out["tex"].append(tex)
		out["frames"].append(_make_frames(tex, CW, fh, ANIMS))
	_frames_cache[key] = out
	return out


static func _make_frames(texture: Texture2D, fw: int, fh: int, anims: Dictionary) -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for anim_name in anims:
		var a: Dictionary = anims[anim_name]
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, a["fps"])
		sf.set_animation_loop(anim_name, a["loop"])
		for i in a["frames"]:
			var at := AtlasTexture.new()
			at.atlas = texture
			at.region = Rect2(i * fw, 0, fw, fh)
			sf.add_frame(anim_name, at)
	return sf


## Only the small form (shop preview / title screen runner). Cached per loadout.
static func small_frames(lo: Dictionary) -> SpriteFrames:
	var key := sig(lo)
	if _small_cache.has(key):
		return _small_cache[key]
	if _small_cache.size() > 40:
		_small_cache.clear()
	var sf := _make_frames(sheet_for(lo, 0), CW, frame_height(0), ANIMS)
	_small_cache[key] = sf
	return sf


## Frame height (body + room for hats) of a form.
static func frame_height(form: int) -> int:
	return (32 if form > 0 else 16) + PAD_TOP


## Small head-and-shoulders icon (no hat / back item) used by the HUD lives counter.
static func life_icon(lo: Dictionary) -> Texture2D:
	var l := lo.duplicate()
	l["hat"] = ""
	l["back"] = ""
	var at := AtlasTexture.new()
	at.atlas = frames_for(l)["tex"][0]
	at.region = Rect2(BX, PAD_TOP, 16, 16)
	return at


# ------------------------------------------------------------------ thumbnails for the shop grid
static func thumb(it: Dictionary) -> Texture2D:
	var id: String = it["id"]
	if _thumb_cache.has(id):
		return _thumb_cache[id]
	var slot: String = it["slot"]
	var lo := default_loadout()
	var crop := Rect2i(8, 14, 16, 14)
	match slot:
		"skin":
			lo["skin"] = id
		"suit":
			lo["suit"] = id
		"hat":
			lo["hat"] = id
			crop = Rect2i(4, 4, 20, 13)
		"face":
			lo["face"] = id
			crop = Rect2i(4, 13, 20, 12)
		"back":
			lo["back"] = id
			crop = Rect2i(2, 17, 24, 14)
		"trail":
			var t := _trail_thumb(it)
			_thumb_cache[id] = t
			return t
	var pose := "idle"
	if slot == "back" and (String(it["kind"]) == "jet" or String(it["kind"]) == "wings"):
		pose = "jump"
	var frame := compose(lo, 0, pose)
	var region := Image.create_empty(crop.size.x, crop.size.y, false, Image.FORMAT_RGBA8)
	region.blit_rect(frame, crop, Vector2i.ZERO)
	region.resize(crop.size.x * 2, crop.size.y * 2, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(region)
	_thumb_cache[id] = tex
	return tex


static func none_thumb() -> Texture2D:
	if _thumb_cache.has("none"):
		return _thumb_cache["none"]
	var rows := [
		"R......R",
		".R....R.",
		"..R..R..",
		"...RR...",
		"...RR...",
		"..R..R..",
		".R....R.",
		"R......R",
	]
	var img := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	_blit_plain(img, rows, {"R": Color(0.55, 0.58, 0.75)})
	img.resize(24, 24, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	_thumb_cache["none"] = tex
	return tex


static func _blit_plain(img: Image, rows: Array, cols: Dictionary) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if cols.has(row[x]):
				img.set_pixel(x, y, cols[row[x]])


static func _trail_thumb(it: Dictionary) -> Texture2D:
	var img := Image.create_empty(24, 15, false, Image.FORMAT_RGBA8)
	var colors: Array = it["colors"]
	var spots := [Vector2i(19, 8), Vector2i(13, 4), Vector2i(8, 9), Vector2i(3, 4), Vector2i(1, 10), Vector2i(10, 11)]
	for i in spots.size():
		var tex_img := _shape_image(String(it["shape"]), _col(String(colors[i % colors.size()])))
		var sp: Vector2i = spots[i]
		img.blend_rect(tex_img, Rect2i(0, 0, tex_img.get_width(), tex_img.get_height()), sp)
	img.resize(48, 30, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ trails
const SHAPES := {
	"dot": ["XX", "XX"],
	"star": [".X.", "XXX", ".X."],
	"flake": ["X.X", ".X.", "X.X"],
	"heart": [".X.X.", "XXXXX", "XXXXX", ".XXX.", "..X.."],
	"bubble": [".XX.", "X..X", "X..X", ".XX."],
	"flame": [".X.", "XXX", "XXX", ".X."],
}


static func _shape_image(shape: String, color: Color) -> Image:
	var rows: Array = SHAPES[shape]
	var img := Image.create_empty(String(rows[0]).length(), rows.size(), false, Image.FORMAT_RGBA8)
	_blit_plain(img, rows, {"X": color})
	return img


static func _shape_tex(shape: String, hex: String) -> Texture2D:
	var key := shape + hex
	if not _shape_cache.has(key):
		_shape_cache[key] = ImageTexture.create_from_image(_shape_image(shape, _col(hex)))
	return _shape_cache[key]


## One trail particle behind the hero. parent = any Node2D (level fx layer or a shop preview),
## feet = hero feet position in parent space, scale_f = zoom of the hero (shop preview).
static func spawn_trail(parent: Node, rng: RandomNumberGenerator, id: String, feet: Vector2, facing: int,
		counter: int, scale_f: float = 1.0, z: int = -1) -> void:
	var it := by_id(id)
	if it.is_empty() or parent == null or rng == null:
		return
	var colors: Array = it["colors"]
	var shape: String = it["shape"]
	var hex: String = colors[counter % colors.size()]
	var s := Sprite2D.new()
	s.texture = _shape_tex(shape, hex)
	s.centered = true
	s.scale = Vector2(scale_f, scale_f)
	var pos := Vector2(-facing * rng.randf_range(2.0, 6.0), -rng.randf_range(2.0, 10.0))
	var drift := Vector2(-facing * rng.randf_range(4.0, 12.0), 0.0)
	var life := 0.5
	match shape:
		"star":
			life = 0.45
			drift = Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-6.0, 2.0))
		"flake":
			life = 0.9
			pos.y -= rng.randf_range(0.0, 6.0)
			drift = Vector2(-facing * rng.randf_range(2.0, 8.0), rng.randf_range(8.0, 16.0))
		"heart":
			life = 0.8
			pos.y -= 6.0
			drift = Vector2(rng.randf_range(-5.0, 5.0), -rng.randf_range(12.0, 20.0))
		"bubble":
			life = 0.8
			pos.y -= 4.0
			drift = Vector2(rng.randf_range(-6.0, 6.0), -rng.randf_range(10.0, 18.0))
		"flame":
			life = 0.4
			drift = Vector2(-facing * rng.randf_range(2.0, 6.0), -rng.randf_range(6.0, 12.0))
		"dot":
			life = 0.45
			pos = Vector2(pos.x, -6.0 - float(counter % 3) * 2.0)
			drift = Vector2(-facing * 14.0, 0.0)
	var start := (feet + pos * scale_f).round()
	s.position = start
	s.z_index = z
	parent.add_child(s)
	var tw := s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "position", (start + drift * scale_f).round(), life)
	tw.tween_property(s, "modulate:a", 0.0, life).set_delay(life * 0.35)
	tw.chain().tween_callback(s.queue_free)


## Seconds between two trail particles.
static func trail_rate(id: String) -> float:
	var it := by_id(id)
	if it.is_empty():
		return 1.0
	return float(it["rate"])


# ------------------------------------------------------------------ shop basket icon (menu button)
static func basket_icon() -> Texture2D:
	if _thumb_cache.has("basket"):
		return _thumb_cache["basket"]
	var rows := [
		"......OOOOOOOO......",
		".....OhhhhhhhhO.....",
		"....Oh........hO....",
		"....Oh...OO...hO....",
		"....Oh..OggO..hO....",
		"..OOOOOOgGgOOOOOO...",
		".OBBbBBbBBbBBbBBbO..",
		".ObbBbbBbbBbbBbbBO..",
		".OBBbBBbBBbBBbBBbO..",
		"..ObbBbbBbbBbbBbO...",
		"..OBBbBBbBBbBBbBO...",
		"..ObbBbbBbbBbbBbO...",
		"...OBBbBBbBBbBBO....",
		"...ObbBbbBbbBbbO....",
		"....OOOOOOOOOOO.....",
	]
	var cols := {
		"O": OUTLINE_COLOR, "h": _col("c8883a"), "B": _col("e0a050"), "b": _col("a8682a"),
		"G": _col("fff2a0"), "g": _col("ffc92a"),
	}
	var img := Image.create_empty(20, 15, false, Image.FORMAT_RGBA8)
	_blit_plain(img, rows, cols)
	var tex := ImageTexture.create_from_image(img)
	_thumb_cache["basket"] = tex
	return tex


## Small solid coin (8x8) for price tags.
static func coin_icon() -> Texture2D:
	if _thumb_cache.has("coin"):
		return _thumb_cache["coin"]
	var rows := [
		"..OOOO..",
		".OyyYYO.",
		"OyYYYYYO",
		"OyYYyYYO",
		"OyYYyYYO",
		"OyYYYYYO",
		".OyYYYO.",
		"..OOOO..",
	]
	var cols := {"O": _col("8a5a08"), "Y": _col("ffd23a"), "y": _col("fff2a0")}
	var img := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	_blit_plain(img, rows, cols)
	var tex := ImageTexture.create_from_image(img)
	_thumb_cache["coin"] = tex
	return tex
