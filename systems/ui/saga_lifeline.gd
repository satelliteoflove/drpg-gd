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


func _span() -> Vector2i:
	var start := CharacterEnums.get_base_age(race) * CharacterEnums.DAYS_PER_YEAR
	var end := CharacterEnums.get_max_age_days(race)
	return Vector2i(mini(start, age_in), maxi(end, age_out))


func _x(age: int) -> float:
	var span := _span()
	return size.x * clampf(float(age - span.x) / float(maxi(1, span.y - span.x)), 0.0, 1.0)


func _phase_at(age: int) -> CharacterEnums.LifePhase:
	return CharacterEnums.get_life_phase(race, age)


func _draw() -> void:
	var span := _span()
	var mid := size.y * 0.5
	var thin := 4.0
	var thick := size.y - 4.0

	# The whole life, faint and fading out toward the end.
	for i in SLICES:
		var a := span.x + int(float(span.y - span.x) * i / SLICES)
		var b := span.x + int(float(span.y - span.x) * (i + 1) / SLICES)
		var t := float(i) / SLICES
		var fade := 1.0 if t < FADE_FROM else clampf(1.0 - (t - FADE_FROM) / (1.0 - FADE_FROM), 0.0, 1.0)
		var col: Color = PHASE_COLORS[_phase_at(a)]
		col.a = 0.28 * fade
		draw_rect(Rect2(_x(a), mid - thin * 0.5, _x(b) - _x(a), thin), col)

	# The years in service, bright, phase by phase.
	var a := age_in
	while a < age_out:
		var phase := _phase_at(a)
		var b := a
		var step := maxi(1, (age_out - age_in) / 200)
		while b < age_out and _phase_at(b) == phase:
			b = mini(age_out, b + step)
		draw_rect(Rect2(_x(a), mid - thick * 0.5, maxf(2.0, _x(b) - _x(a)), thick), PHASE_COLORS[phase])
		a = b

	# Where service ended (or where they stand now).
	var end_x := _x(age_out)
	draw_rect(Rect2(end_x - 1.5, 0, 3, size.y), end_color)
