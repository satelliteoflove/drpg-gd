class_name GameCalendar
extends RefCounted

const START_YEAR: int = 1490
const START_MONTH: int = 3
const START_DAY: int = 1

const DAYS_PER_MONTH: int = CharacterEnums.DAYS_PER_MONTH
const MONTHS_PER_YEAR: int = CharacterEnums.MONTHS_PER_YEAR
const DAYS_PER_YEAR: int = CharacterEnums.DAYS_PER_YEAR


static func get_date(game_day: int) -> Dictionary:
	var absolute_day := game_day - 1
	var start_offset := (START_YEAR * DAYS_PER_YEAR) + ((START_MONTH - 1) * DAYS_PER_MONTH) + (START_DAY - 1)
	var total_day := start_offset + absolute_day
	var year := total_day / DAYS_PER_YEAR
	var day_in_year := total_day % DAYS_PER_YEAR
	var month := day_in_year / DAYS_PER_MONTH + 1
	var day := day_in_year % DAYS_PER_MONTH + 1
	return {"year": year, "month": month, "day": day}


static func format_date(game_day: int) -> String:
	var date := get_date(game_day)
	return "Day %d, Month %d, Year %d" % [date["day"], date["month"], date["year"]]


static func format_short(game_day: int) -> String:
	var date := get_date(game_day)
	return "M%d D%d, %d" % [date["month"], date["day"], date["year"]]


static func create_date_grid(game_day: int) -> Dictionary:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 0)
	var headers := ["Day", "Month", "Year"]
	for h in headers:
		var lbl := Label.new()
		lbl.text = h
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SMALL)
		lbl.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
		grid.add_child(lbl)
	var day_lbl := Label.new()
	day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid.add_child(day_lbl)
	var month_lbl := Label.new()
	month_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid.add_child(month_lbl)
	var year_lbl := Label.new()
	year_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid.add_child(year_lbl)
	var date := get_date(game_day)
	day_lbl.text = str(date["day"])
	month_lbl.text = str(date["month"])
	year_lbl.text = str(date["year"])
	return {"grid": grid, "day": day_lbl, "month": month_lbl, "year": year_lbl}


static func update_date_labels(labels: Dictionary, game_day: int) -> void:
	var date := get_date(game_day)
	labels["day"].text = str(date["day"])
	labels["month"].text = str(date["month"])
	labels["year"].text = str(date["year"])
