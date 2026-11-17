class_name PRTheme
extends RefCounted
## Shared look for every PlatformRace screen, inspired by modern fighting-game
## menus: slanted panels, heavy italic type, hard edges and snappy animations.
## Everything is built in code so no .tres files are needed.
##
## Palette
##   main       NAVY   dark blue surfaces (panels, bars)
##   secondary  GOLD   titles, the timer, calls to action
##   tertiary   SKY    selections, info, outlines
##   neutrals   INK (black) and WHITE (text)
##   alert      RED    hindering, danger, warnings
##
## Font: Nunito (SIL Open Font License, licence next to it). The display style
## is Nunito Black slanted, the body style is upright Nunito.

const FONT_DIR := "res://Minigames/PlatformRace/race/ui/fonts/"

const INK := Color("#070A12")
const NAVY := Color("#0E1A3A")
const NAVY_LIGHT := Color("#1C2F63")
const WHITE := Color("#F2F5FF")
const GOLD := Color("#F5B940")
const SKY := Color("#46C2FF")
const RED := Color("#FF3B55")
const MUTED := Color("#8D9CC4")

## How far panels and chips lean (StyleBoxFlat skew).
const LEAN := 0.22

static var _fonts := {}


# --- Fonts ------------------------------------------------------------------------

## Heavy slanted type for titles, numbers and banners.
static func display_font() -> Font:
	return _font(900, 0.2)


## Upright Nunito, bold by default, for anything read quickly.
static func body_font(weight := 800) -> Font:
	return _font(weight, 0.0)


static func _font(weight: int, slant: float) -> Font:
	var key := "%d:%.2f" % [weight, slant]
	if _fonts.has(key):
		return _fonts[key]
	var path := FONT_DIR + "Nunito.ttf"
	var base: Font = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	var fv := FontVariation.new()
	fv.base_font = base
	var ts := TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): weight}
	if slant != 0.0:
		fv.variation_transform = Transform2D(Vector2(1, 0), Vector2(slant, 1), Vector2.ZERO)
	_fonts[key] = fv
	return fv


# --- Boxes -----------------------------------------------------------------------

## A slanted panel with a bright accent edge on the left.
static func panel(accent := SKY, bg := NAVY, alpha := 0.86, lean := LEAN, edge := 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(bg.r, bg.g, bg.b, alpha)
	sb.border_color = accent
	sb.border_width_left = edge
	sb.skew = Vector2(lean, 0)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.anti_aliasing = true
	return sb


## A flat slanted fill with no border (bars, chips, highlights).
static func fill(color: Color, lean := LEAN, margin_x := 10, margin_y := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.skew = Vector2(lean, 0)
	sb.content_margin_left = margin_x
	sb.content_margin_right = margin_x
	sb.content_margin_top = margin_y
	sb.content_margin_bottom = margin_y
	sb.anti_aliasing = true
	return sb


## Black or white, whichever reads better on `bg`.
static func text_on(bg: Color) -> Color:
	return INK if bg.get_luminance() > 0.55 else WHITE


# --- Widgets ---------------------------------------------------------------------

static func label(text: String, size := 16, color := WHITE, font: Font = null, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font if font else body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(INK, 0.9))
	return l


static func title(text: String, size := 40, color := WHITE, outline := 0) -> Label:
	return label(text, size, color, display_font(), outline)


## A filled slanted chip, e.g. "✚ HELP" or "READY".
static func chip(text: String, color: Color, size := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", fill(color, LEAN, 9, 0))
	p.add_child(label(text, size, text_on(color), display_font()))
	return p


## A key or pad button drawn as a small white keycap.
static func keycap(text: String, size := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := fill(WHITE, 0.0, 6, 0)
	sb.set_corner_radius_all(3)
	sb.border_color = MUTED
	sb.border_width_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	var l := label(text, size, INK, body_font(900))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(size * 0.9, 0)
	p.add_child(l)
	return p


## A row mixing keycaps and text. Items: Control nodes, or Strings. A String
## wrapped in [brackets] becomes a keycap: row(["[S]", "power"]).
static func row(items: Array, size := 14, color := WHITE, sep := 6) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", sep)
	for it in items:
		if it is Control:
			h.add_child(it)
		elif it is String:
			var s: String = it
			if s.begins_with("[") and s.ends_with("]") and s.length() > 2:
				h.add_child(keycap(s.substr(1, s.length() - 2), size))
			else:
				h.add_child(label(s, size, color))
	return h


## A thin coloured bar (cooldowns, timers). `ratio` 0..1 is how full it is.
static func meter(color: Color, width := 60.0, height := 5.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(width, height)
	bar.max_value = 1.0
	bar.step = 0.0
	bar.add_theme_stylebox_override("background", fill(Color(INK, 0.6), LEAN, 0, 0))
	bar.add_theme_stylebox_override("fill", fill(color, LEAN, 0, 0))
	return bar


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


## "1:05.3" from seconds.
static func time_text(seconds: float, tenths := true) -> String:
	var s := maxf(seconds, 0.0)
	var m := int(s / 60.0)
	if tenths:
		return "%d:%04.1f" % [m, s - m * 60.0]
	return "%d:%02d" % [m, int(s) % 60]


# --- Animations -------------------------------------------------------------------
# Tweens are created on the node itself, so they stop when the node is freed.

## Fades a control in while it grows from a narrow sliver (a quick "wipe").
static func wipe_in(c: Control, delay := 0.0, duration := 0.22) -> void:
	c.modulate.a = 0.0
	c.pivot_offset = Vector2(0, c.size.y * 0.5)
	c.scale = Vector2(0.4, 1.0)
	var tw := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, duration * 0.7).set_delay(delay)
	tw.tween_property(c, "scale", Vector2.ONE, duration).set_delay(delay)


## A short scale punch, e.g. when something is picked.
static func pop(c: Control, amount := 0.12, duration := 0.18) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * (1.0 + amount)
	var tw := c.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, duration)


## Slides an anchored (non-container) control in from `offset` pixels away.
static func slide_in(c: Control, offset: Vector2, delay := 0.0, duration := 0.3) -> void:
	var target := c.position
	c.position = target + offset
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "position", target, duration).set_delay(delay)
	tw.tween_property(c, "modulate:a", 1.0, duration * 0.5).set_delay(delay)
