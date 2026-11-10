class_name SagaLifeline
extends Control

## One character's whole lifespan as a bar, split into the four life phases,
## with the years they spent in the guild's service drawn bright. The far end
## fades out so the maximum age stays a mystery.

const PHASE_COLORS := {
	CharacterEnums.LifePhase.YOUTH: Color(0.46, 0.76, 0.56),
	CharacterEnums.LifePhase.PRIME: Color(0.48, 0.64, 0.92),
	CharacterEnums.LifePhase.DECLINE: Color(0.88, 0.66, 0.32),
	CharacterEnums.LifePhase.FRAGILE: Color(0.78, 0.74, 0.88),
}
## Fractions of a race's career where each phase begins, matching
## CharacterEnums.get_life_phase.
const PHASE_STARTS := [0.0, 0.07, 0.50, 0.80]
const FADE_FROM := 0.85
const SLICES := 48

var race: CharacterEnums.Race
var age_in: int
var age_out: int
var end_color := UIColors.TEXT_PRIMARY


static func create(c: Character, p_age_in: int, p_age_out: int, p_end_color: Color) -> SagaLifeline:
	var line := SagaLifeline.new()
	line.race = c.race
	line.age_in = p_age_in
	line.age_out = p_age_out
	line.end_color = p_end_color
	line.custom_minimum_size = Vector2(260, 18)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _draw() -> void:
	paint(self, Rect2(Vector2.ZERO, size), race, age_in, age_out, end_color)


## Draws a lifeline into [param r] on any canvas item, so custom-drawn
## screens like the character sheet can show one too.
static func paint(canvas: CanvasItem, r: Rect2, p_race: CharacterEnums.Race,
		p_age_in: int, p_age_out: int, p_end_color: Color) -> void:
	var start := mini(CharacterEnums.get_base_age(p_race) * CharacterEnums.DAYS_PER_YEAR, p_age_in)
	var end := maxi(CharacterEnums.get_max_age_days(p_race), p_age_out)
	var x_of := func(age: int) -> float:
		return r.position.x + r.size.x * clampf(float(age - start) / float(maxi(1, end - start)), 0.0, 1.0)
	var mid := r.position.y + r.size.y * 0.5
	var thin := maxf(2.0, r.size.y * 0.25)
	var thick := maxf(thin, r.size.y - 4.0)

	# The whole life, faint and fading out toward the end.
	for i in SLICES:
		var a := start + int(float(end - start) * i / SLICES)
		var b := start + int(float(end - start) * (i + 1) / SLICES)
		var t := float(i) / SLICES
		var fade := 1.0 if t < FADE_FROM else clampf(1.0 - (t - FADE_FROM) / (1.0 - FADE_FROM), 0.0, 1.0)
		var col: Color = PHASE_COLORS[CharacterEnums.get_life_phase(p_race, a)]
		col.a = 0.28 * fade
		canvas.draw_rect(Rect2(x_of.call(a), mid - thin * 0.5, x_of.call(b) - x_of.call(a), thin), col)

	# The years in service, bright, phase by phase.
	var step := maxi(1, (p_age_out - p_age_in) / 200)
	var a := p_age_in
	while a < p_age_out:
		var phase := CharacterEnums.get_life_phase(p_race, a)
		var b := a
		while b < p_age_out and CharacterEnums.get_life_phase(p_race, b) == phase:
			b = mini(p_age_out, b + step)
		canvas.draw_rect(Rect2(x_of.call(a), mid - thick * 0.5, maxf(2.0, x_of.call(b) - x_of.call(a)), thick),
			PHASE_COLORS[phase])
		a = b

	# Where service ended (or where they stand now).
	canvas.draw_rect(Rect2(x_of.call(p_age_out) - 1.5, r.position.y, 3, r.size.y), p_end_color)
