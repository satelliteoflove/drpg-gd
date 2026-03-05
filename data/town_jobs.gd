class_name TownJobs
extends RefCounted

const JOBS: Array[Dictionary] = [
	{"id": 0, "name": "Militia", "slots": 2, "xp_per_day": 5, "gold_per_day": 2},
	{"id": 1, "name": "Temple Work", "slots": 2, "xp_per_day": 5, "gold_per_day": 2},
	{"id": 2, "name": "Locksmithing", "slots": 1, "xp_per_day": 5, "gold_per_day": 2},
	{"id": 3, "name": "Innkeeper", "slots": 1, "xp_per_day": 5, "gold_per_day": 2},
	{"id": 4, "name": "Bartender", "slots": 2, "xp_per_day": 5, "gold_per_day": 2},
	{"id": 5, "name": "Gardener", "slots": 2, "xp_per_day": 5, "gold_per_day": 2},
	{"id": 6, "name": "Blacksmith", "slots": 1, "xp_per_day": 5, "gold_per_day": 2},
	{"id": 7, "name": "Groundskeeper", "slots": 3, "xp_per_day": 5, "gold_per_day": 2},
	{"id": 8, "name": "Bailiff", "slots": 1, "xp_per_day": 5, "gold_per_day": 2},
]


static func get_job(index: int) -> Dictionary:
	if index < 0 or index >= JOBS.size():
		return {}
	return JOBS[index]


static func get_job_name(index: int) -> String:
	var job := get_job(index)
	return job.get("name", "Unknown")


static func get_all_jobs() -> Array[Dictionary]:
	return JOBS


static func count_assigned(roster: CharacterRoster, job_index: int) -> int:
	var count := 0
	for character in roster.get_all():
		if character.town_job == job_index:
			count += 1
	return count


static func is_slot_available(roster: CharacterRoster, job_index: int) -> bool:
	var job := get_job(job_index)
	if job.is_empty():
		return false
	return count_assigned(roster, job_index) < job.get("slots", 0)
