class_name Utils extends Object

static func get_weighted_random(items_weighted: Array, rng: RandomNumberGenerator) -> Variant:
	var total_weight = 0
	for item in items_weighted:
		total_weight += item[1]

	var choice = rng.randi_range(0, total_weight - 1)
	var current_weight = 0
	for item in items_weighted:
		current_weight += item[1]
		if choice < current_weight:
			return item[0]
	return null # Sollte nie erreicht werden
