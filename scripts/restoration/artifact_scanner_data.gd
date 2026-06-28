@tool
class_name ArtifactScannerData
extends Node
## Designer-authored scanner data for ONE artifact, added as a child node of its scene. The
## ArtifactCatalog reads it during the folder scan, and the offline scanner serves it — so any new
## artifact dropped in scenes/restoration/artifacts/ becomes scannable (and therefore sellable, since
## a piece must be scanned + judged before it can be listed) with NO data/scanner-cache JSON edit.
##
## Advisory only: the scanner SUGGESTS, the player judges (PRD §20). Marked unverified, since this is
## dev-authored game content, not a verified historical source (CLAUDE.md §4-G/§4-L).

enum Confidence { HIGH, MEDIUM, LOW, UNCERTAIN }

const _CONFIDENCE_NAMES := {
	Confidence.HIGH: "high",
	Confidence.MEDIUM: "medium",
	Confidence.LOW: "low",
	Confidence.UNCERTAIN: "uncertain",
}

## What the scanner reads the object AS (e.g. "brass hand bell"). Required to be scannable.
@export var type: String = ""
## Estimated era (e.g. "early 20th century").
@export var period: String = ""
## Detected materials (e.g. ["brass"]).
@export var materials: Array[String] = []
## Notable marks/features the scan calls out (e.g. ["tarnish", "cast seam"]).
@export var markings: Array[String] = []
## One-line condition summary.
@export_multiline var condition_note: String = ""
## Folklore-framed cultural context. Never asserts archaeological fact.
@export_multiline var cultural_relevance: String = ""
## Suggested value range the scanner reports.
@export var price_min: int = 0
@export var price_max: int = 0
## How sure the scan is — the player still makes the final call.
@export var confidence: Confidence = Confidence.MEDIUM
## What the scan is unsure about (counterfeit cross-referencing hook).
@export_multiline var uncertainty_notes: String = ""


## True once enough is authored for a usable scan (at minimum a type).
func is_authored() -> bool:
	return not type.strip_edges().is_empty()


## The scanner-response payload (matching data/scanner-cache shape), or empty when not authored.
func to_response_dict() -> Dictionary:
	if not is_authored():
		return {}
	return {
		"type": type,
		"period": period,
		"materials": materials.duplicate(),
		"markings": markings.duplicate(),
		"condition_note": condition_note,
		"cultural_relevance": cultural_relevance,
		"price_range": [maxi(0, price_min), maxi(price_min, price_max)],
		"modification_signs": [],
		"confidence": _CONFIDENCE_NAMES.get(confidence, "medium"),
		"uncertainty_notes": uncertainty_notes,
		"source_references":
		[
			{
				"status": "unverified",
				"note": "Designer-authored scanner data; not a verified historical source.",
			}
		],
	}
