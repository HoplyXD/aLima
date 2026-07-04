extends GutTest
## The per-artifact ArtifactScannerData node: an unauthored node yields nothing, an authored one
## produces a payload that parses + validates as a real ScannerResponse (so folder artifacts with the
## node are scannable without any data/scanner-cache JSON entry).


func test_unauthored_node_yields_no_scanner_data() -> void:
	var node := ArtifactScannerData.new()
	assert_false(node.is_authored(), "a node with no type is not authored")
	assert_true(node.to_response_dict().is_empty())
	node.free()


func test_authored_node_produces_a_valid_scanner_response() -> void:
	var node := ArtifactScannerData.new()
	node.type = "brass hand bell"
	node.period = "early 20th century"
	node.materials = ["brass"] as Array[String]
	node.markings = ["tarnish", "cast seam"] as Array[String]
	node.condition_note = "Tarnished but intact."
	node.cultural_relevance = "A common household/chapel hand bell."
	node.price_min = 20
	node.price_max = 70
	node.confidence = ArtifactScannerData.Confidence.MEDIUM
	var data := node.to_response_dict()
	node.free()

	assert_false(data.is_empty(), "authored node yields a payload")
	assert_eq(data["price_range"], [20, 70])
	assert_eq(data["confidence"], "medium")

	data["request_id"] = "test_request"
	var response := ScannerResponse.from_dictionary(data)
	assert_true(response.validate().is_valid(), "scene scanner data is a valid ScannerResponse")
	assert_eq(response.type, "brass hand bell")
	assert_eq(response.price_range_min, 20)
