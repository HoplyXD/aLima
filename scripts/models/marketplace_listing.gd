class_name MarketplaceListing
## A first-class marketplace listing for a restored item (MKT-R1, DISP-R2, P14.1).
##
## Listings make "the player lists restored items" explicit loop state instead of
## selling straight through the Storage/Phone flow. A listing is created when the
## player lists an item for buyers, carries the asking price and the player's
## described honesty/condition at listing time, and is resolved when the item sells
## (SOLD) or is taken down (WITHDRAWN). Listings are loop-scoped: they live in
## LoopState.listings and are cleared on the five-day reset (CLAUDE.md §4-A).

enum Status {
	LISTED = 0,  ## Active and visible to buyers.
	SOLD = 1,  ## Resolved by a completed sale.
	WITHDRAWN = 2,  ## Taken down by the player (or superseded by a non-sale disposition).
}

const STATUS_NAMES: Array[String] = ["listed", "sold", "withdrawn"]

var instance_uid: String = ""  ## The listed ObjectInstance uid (unique within the loop).
var template_id: String = ""
var asking_price: int = 0  ## The player's posted price; the negotiation anchor.
var listed_day: int = 0
var condition_at_listing: int = 0  ## Snapshot for honesty/condition bookkeeping (DISP-R2).
var honest_description: bool = true  ## Whether the listing description matches the truth.
var status: int = Status.LISTED
var sold_price: int = 0  ## Final price once SOLD.
var sold_buyer_id: String = ""


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> MarketplaceListing:
	var l := MarketplaceListing.new()
	l.instance_uid = ModelUtils.as_string(data.get("instance_uid"))
	l.template_id = ModelUtils.as_string(data.get("template_id"))
	l.asking_price = ModelUtils.as_int(data.get("asking_price"))
	l.listed_day = ModelUtils.as_int(data.get("listed_day"))
	l.condition_at_listing = ModelUtils.as_int(data.get("condition_at_listing"))
	l.honest_description = ModelUtils.as_bool(data.get("honest_description"), true)
	l.status = status_from_name(ModelUtils.as_string(data.get("status"), "listed"))
	l.sold_price = ModelUtils.as_int(data.get("sold_price"))
	l.sold_buyer_id = ModelUtils.as_string(data.get("sold_buyer_id"))
	return l


func to_dictionary() -> Dictionary:
	return {
		"instance_uid": instance_uid,
		"template_id": template_id,
		"asking_price": asking_price,
		"listed_day": listed_day,
		"condition_at_listing": condition_at_listing,
		"honest_description": honest_description,
		"status": status_name(status),
		"sold_price": sold_price,
		"sold_buyer_id": sold_buyer_id,
	}


func is_active() -> bool:
	return status == Status.LISTED


static func status_from_name(name: String) -> int:
	var idx := STATUS_NAMES.find(name.to_lower().strip_edges())
	return Status.LISTED if idx < 0 else idx


static func status_name(value: int) -> String:
	if value < 0 or value >= STATUS_NAMES.size():
		return STATUS_NAMES[Status.LISTED]
	return STATUS_NAMES[value]


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if instance_uid.is_empty():
		result.add_field_error(file_path, instance_uid, "instance_uid", "listing uid is required")
	if template_id.is_empty():
		result.add_field_error(file_path, instance_uid, "template_id", "template_id is required")
	if asking_price < 0:
		result.add_field_error(
			file_path, instance_uid, "asking_price", "asking_price must be non-negative"
		)
	return result
