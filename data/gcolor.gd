class_name GColor

# Pebble 2-bit-per-channel color palette.
# Each R/G/B channel is quantized to one of {0x00, 0x55, 0xAA, 0xFF} (i.e. {0, 85, 170, 255}).
# Source: https://developer.repebble.com/docs/c/Graphics/Graphics_Types/Color_Definitions/

const CLEAR                   := Color(0.0,       0.0,       0.0,       0.0)
const BLACK                   := Color("#000000")
const OXFORD_BLUE             := Color("#000055")
const DUKE_BLUE               := Color("#0000AA")
const BLUE                    := Color("#0000FF")
const DARK_GREEN              := Color("#005500")
const MIDNIGHT_GREEN          := Color("#005555")
const COBALT_BLUE             := Color("#0055AA")
const BLUE_MOON               := Color("#0055FF")
const ISLAMIC_GREEN           := Color("#00AA00")
const JAEGER_GREEN            := Color("#00AA55")
const TIFFANY_BLUE            := Color("#00AAAA")
const VIVID_CERULEAN          := Color("#00AAFF")
const GREEN                   := Color("#00FF00")
const MALACHITE               := Color("#00FF55")
const MEDIUM_SPRING_GREEN     := Color("#00FFAA")
const CYAN                    := Color("#00FFFF")
const BULGARIAN_ROSE          := Color("#550000")
const IMPERIAL_PURPLE         := Color("#550055")
const INDIGO                  := Color("#5500AA")
const ELECTRIC_ULTRAMARINE    := Color("#5500FF")
const ARMY_GREEN              := Color("#555500")
const DARK_GRAY               := Color("#555555")
const LIBERTY                 := Color("#5555AA")
const VERY_LIGHT_BLUE         := Color("#5555FF")
const KELLY_GREEN             := Color("#55AA00")
const MAY_GREEN               := Color("#55AA55")
const CADET_BLUE              := Color("#55AAAA")
const PICTON_BLUE             := Color("#55AAFF")
const BRIGHT_GREEN            := Color("#55FF00")
const SCREAMIN_GREEN          := Color("#55FF55")
const MEDIUM_AQUAMARINE       := Color("#55FFAA")
const ELECTRIC_BLUE           := Color("#55FFFF")
const DARK_CANDY_APPLE_RED    := Color("#AA0000")
const JAZZBERRY_JAM           := Color("#AA0055")
const PURPLE                  := Color("#AA00AA")
const VIVID_VIOLET            := Color("#AA00FF")
const WINDSOR_TAN             := Color("#AA5500")
const ROSE_VALE               := Color("#AA5555")
const PURPUREUS               := Color("#AA55AA")
const LAVENDER_INDIGO         := Color("#AA55FF")
const LIMERICK                := Color("#AAAA00")
const BRASS                   := Color("#AAAA55")
const LIGHT_GRAY              := Color("#AAAAAA")
const BABY_BLUE_EYES          := Color("#AAAAFF")
const SPRING_BUD              := Color("#AAFF00")
const INCHWORM                := Color("#AAFF55")
const MINT_GREEN              := Color("#AAFFAA")
const CELESTE                 := Color("#AAFFFF")
const RED                     := Color("#FF0000")
const FOLLY                   := Color("#FF0055")
const FASHION_MAGENTA         := Color("#FF00AA")
const MAGENTA                 := Color("#FF00FF")
const ORANGE                  := Color("#FF5500")
const SUNSET_ORANGE           := Color("#FF5555")
const BRILLIANT_ROSE          := Color("#FF55AA")
const SHOCKING_PINK           := Color("#FF55FF")
const CHROME_YELLOW           := Color("#FFAA00")
const RAJAH                   := Color("#FFAA55")
const MELON                   := Color("#FFAAAA")
const RICH_BRILLIANT_LAVENDER := Color("#FFAAFF")
const YELLOW                  := Color("#FFFF00")
const ICTERINE                := Color("#FFFF55")
const PASTEL_YELLOW           := Color("#FFFFAA")
const WHITE                   := Color("#FFFFFF")

const COLOR_NAMES := {
	CLEAR:                   "Clear",
	BLACK:                   "Black",
	OXFORD_BLUE:             "Oxford Blue",
	DUKE_BLUE:               "Duke Blue",
	BLUE:                    "Blue",
	DARK_GREEN:              "Dark Green",
	MIDNIGHT_GREEN:          "Midnight Green",
	COBALT_BLUE:             "Cobalt Blue",
	BLUE_MOON:               "Blue Moon",
	ISLAMIC_GREEN:           "Islamic Green",
	JAEGER_GREEN:            "Jaeger Green",
	TIFFANY_BLUE:            "Tiffany Blue",
	VIVID_CERULEAN:          "Vivid Cerulean",
	GREEN:                   "Green",
	MALACHITE:               "Malachite",
	MEDIUM_SPRING_GREEN:     "Medium Spring Green",
	CYAN:                    "Cyan",
	BULGARIAN_ROSE:          "Bulgarian Rose",
	IMPERIAL_PURPLE:         "Imperial Purple",
	INDIGO:                  "Indigo",
	ELECTRIC_ULTRAMARINE:    "Electric Ultramarine",
	ARMY_GREEN:              "Army Green",
	DARK_GRAY:               "Dark Gray",
	LIBERTY:                 "Liberty",
	VERY_LIGHT_BLUE:         "Very Light Blue",
	KELLY_GREEN:             "Kelly Green",
	MAY_GREEN:               "May Green",
	CADET_BLUE:              "Cadet Blue",
	PICTON_BLUE:             "Picton Blue",
	BRIGHT_GREEN:            "Bright Green",
	SCREAMIN_GREEN:          "Screamin Green",
	MEDIUM_AQUAMARINE:       "Medium Aquamarine",
	ELECTRIC_BLUE:           "Electric Blue",
	DARK_CANDY_APPLE_RED:    "Dark Candy Apple Red",
	JAZZBERRY_JAM:           "Jazzberry Jam",
	PURPLE:                  "Purple",
	VIVID_VIOLET:            "Vivid Violet",
	WINDSOR_TAN:             "Windsor Tan",
	ROSE_VALE:               "Rose Vale",
	PURPUREUS:               "Purpureus",
	LAVENDER_INDIGO:         "Lavender Indigo",
	LIMERICK:                "Limerick",
	BRASS:                   "Brass",
	LIGHT_GRAY:              "Light Gray",
	BABY_BLUE_EYES:          "Baby Blue Eyes",
	SPRING_BUD:              "Spring Bud",
	INCHWORM:                "Inchworm",
	MINT_GREEN:              "Mint Green",
	CELESTE:                 "Celeste",
	RED:                     "Red",
	FOLLY:                   "Folly",
	FASHION_MAGENTA:         "Fashion Magenta",
	MAGENTA:                 "Magenta",
	ORANGE:                  "Orange",
	SUNSET_ORANGE:           "Sunset Orange",
	BRILLIANT_ROSE:          "Brilliant Rose",
	SHOCKING_PINK:           "Shocking Pink",
	CHROME_YELLOW:           "Chrome Yellow",
	RAJAH:                   "Rajah",
	MELON:                   "Melon",
	RICH_BRILLIANT_LAVENDER: "Rich Brilliant Lavender",
	YELLOW:                  "Yellow",
	ICTERINE:                "Icterine",
	PASTEL_YELLOW:           "Pastel Yellow",
	WHITE:                   "White",
}

# Quantizes an arbitrary Color to the nearest color in the Pebble 64-color palette
# by rounding each channel independently to the nearest value in {0, 85, 170, 255}.
static func nearest(color: Color) -> Color:
	var r := roundf(color.r * 3.0) / 3.0
	var g := roundf(color.g * 3.0) / 3.0
	var b := roundf(color.b * 3.0) / 3.0
	return Color(r, g, b, 1.0)

static func to_rgba8(color: Color) -> int:
	var r := color.r8 / 85
	var g := color.g8 / 85
	var b := color.b8 / 85
	
	return ((((0x00 | (r << 6)) | (g << 4)) | (b << 2)) | 0b11)
	
	
	
