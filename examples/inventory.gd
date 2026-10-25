extends RefCounted
## Code under test for the examples, with a bug in each function.

const PRICES := {"sword": 10, "shield": 8}
const STOCK: Array[String] = ["sword", "shield", "potion"]


## The rows a grid [param columns] wide needs to show [param count] items.
static func rows_for(count: int, columns: int) -> int:
	# The bug: this rounds down. (count + columns - 1) / columns rounds up.
	@warning_ignore("integer_division")
	return count / columns


## The price of [param item]. The bug: a potion has no price.
static func price_of(item: String) -> int:
	return PRICES[item]
