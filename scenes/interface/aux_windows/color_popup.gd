extends PopupPanel

signal color_selected(color: Color)

@onready var grid_container: GridContainer = $GridContainer
@onready var selector: Line2D = $Selector

const COLOR_RECT_SIZE := Vector2(32, 32)
const COLOR_RECT_PADDING := 4
const SELECTOR_SIZE := Vector2(40, 40)

const palette = [
	[GColor.BLACK,GColor.DARK_GRAY,GColor.LIGHT_GRAY,GColor.WHITE,GColor.CLEAR,GColor.CLEAR],
	[GColor.CLEAR,GColor.CLEAR,GColor.CLEAR,GColor.FOLLY,GColor.CLEAR,GColor.CLEAR],
	[GColor.ROSE_VALE,GColor.BULGARIAN_ROSE,GColor.DARK_CANDY_APPLE_RED,GColor.RED,GColor.SUNSET_ORANGE,GColor.MELON],
	[GColor.CLEAR,GColor.CLEAR,GColor.CLEAR,GColor.ORANGE,GColor.CLEAR,GColor.CLEAR],
	[GColor.CLEAR,GColor.CLEAR,GColor.WINDSOR_TAN,GColor.CHROME_YELLOW,GColor.RAJAH,GColor.CLEAR],
	[GColor.BRASS,GColor.ARMY_GREEN,GColor.LIMERICK,GColor.YELLOW,GColor.ICTERINE,GColor.PASTEL_YELLOW],
	[GColor.CLEAR,GColor.CLEAR,GColor.KELLY_GREEN,GColor.SPRING_BUD,GColor.INCHWORM,GColor.CLEAR],
	[GColor.CLEAR,GColor.CLEAR,GColor.CLEAR,GColor.BRIGHT_GREEN,GColor.CLEAR,GColor.CLEAR],
	[GColor.MAY_GREEN,GColor.DARK_GREEN,GColor.ISLAMIC_GREEN,GColor.GREEN,GColor.SCREAMIN_GREEN,GColor.MINT_GREEN],
	[GColor.CLEAR,GColor.CLEAR,GColor.CLEAR,GColor.MALACHITE,GColor.CLEAR,GColor.CLEAR],
	[GColor.CLEAR,GColor.CLEAR,GColor.JAEGER_GREEN,GColor.MEDIUM_SPRING_GREEN,GColor.MEDIUM_AQUAMARINE,GColor.CLEAR],
	[GColor.CADET_BLUE,GColor.MIDNIGHT_GREEN,GColor.TIFFANY_BLUE,GColor.CYAN,GColor.ELECTRIC_BLUE,GColor.CELESTE],
	[GColor.CLEAR,GColor.CLEAR,GColor.COBALT_BLUE,GColor.VIVID_CERULEAN,GColor.PICTON_BLUE,GColor.CLEAR],
	[GColor.CLEAR,GColor.CLEAR,GColor.CLEAR,GColor.BLUE_MOON,GColor.CLEAR,GColor.CLEAR],
	[GColor.LIBERTY,GColor.OXFORD_BLUE,GColor.DUKE_BLUE,GColor.BLUE,GColor.VERY_LIGHT_BLUE,GColor.BABY_BLUE_EYES],
	[GColor.CLEAR,GColor.CLEAR,GColor.CLEAR,GColor.ELECTRIC_ULTRAMARINE,GColor.CLEAR,GColor.CLEAR],
	[GColor.CLEAR,GColor.CLEAR,GColor.INDIGO,GColor.VIVID_VIOLET,GColor.LAVENDER_INDIGO,GColor.CLEAR],
	[GColor.PURPUREUS,GColor.IMPERIAL_PURPLE,GColor.PURPLE,GColor.MAGENTA,GColor.SHOCKING_PINK,GColor.RICH_BRILLIANT_LAVENDER],
	[GColor.CLEAR,GColor.CLEAR,GColor.JAZZBERRY_JAM,GColor.FASHION_MAGENTA,GColor.BRILLIANT_ROSE,GColor.CLEAR],
]

var selected_color: Color = GColor.BLACK

func _ready() -> void:
	_populate_grid()
	_select_color_rect(grid_container.get_child(0))

func _populate_grid() -> void:
	for row in palette:
		for color in row:
			var color_rect: ColorRect = ColorRect.new()
			color_rect.color = color
			color_rect.custom_minimum_size = COLOR_RECT_SIZE

			if color != GColor.CLEAR:
				_register_color_rect(color_rect)
				
			grid_container.add_child(color_rect)

func _register_color_rect(color_rect: ColorRect) -> void:
	color_rect.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_select_color_rect(color_rect))

func _select_color_rect(color_rect: ColorRect) -> void:
	selected_color = color_rect.color
	selector.position = color_rect.position
	color_selected.emit(selected_color)

func select_color(color: Color) -> void:
	for child in grid_container.get_children():
		if child is ColorRect and child.color == color:
			_select_color_rect(child)
			return
	selected_color = color
	color_selected.emit(color)
