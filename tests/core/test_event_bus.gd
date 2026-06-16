extends GutTest

## Tests that EventBus exposes the Stable Interface signals and that typed
## payloads can be emitted and received.


func test_clock_signals_compile_and_fire() -> void:
	watch_signals(EventBus)
	EventBus.hour_changed.emit(2, 14)
	EventBus.day_changed.emit(3)
	EventBus.loop_reset.emit(2)
	EventBus.clock_pause_changed.emit(true, "dialogue")
	assert_signal_emitted_with_parameters(EventBus, "hour_changed", [2, 14])
	assert_signal_emitted_with_parameters(EventBus, "day_changed", [3])
	assert_signal_emitted_with_parameters(EventBus, "loop_reset", [2])
	assert_signal_emitted_with_parameters(EventBus, "clock_pause_changed", [true, "dialogue"])


func test_delivery_and_restoration_signals_compile_and_fire() -> void:
	watch_signals(EventBus)
	EventBus.delivery_generated.emit(1, ["a", "b"])
	EventBus.triage_completed.emit(["a"], ["b"])
	EventBus.restoration_completed.emit("inst_001", 85.0, "soft_cloth")
	EventBus.object_opened.emit("inst_001", "fragment", "fragment_01")
	assert_signal_emitted_with_parameters(EventBus, "delivery_generated", [1, ["a", "b"]])
	assert_signal_emitted_with_parameters(EventBus, "triage_completed", [["a"], ["b"]])
	assert_signal_emitted_with_parameters(
		EventBus, "restoration_completed", ["inst_001", 85.0, "soft_cloth"]
	)
	assert_signal_emitted_with_parameters(
		EventBus, "object_opened", ["inst_001", "fragment", "fragment_01"]
	)


func test_discovery_signals_compile_and_fire() -> void:
	watch_signals(EventBus)
	EventBus.carrier_activated.emit("inst_001", "fragment_01")
	EventBus.echo_proximity_changed.emit("inst_001", 0.75, "voice")
	EventBus.fragment_discovered.emit("fragment_01", "inst_001")
	EventBus.portal_completed.emit("fragment_01", "museum_001", false, "A recovered gear.")
	EventBus.fragment_seated.emit("fragment_01", 0)
	assert_signal_emitted_with_parameters(
		EventBus, "carrier_activated", ["inst_001", "fragment_01"]
	)
	assert_signal_emitted_with_parameters(
		EventBus, "echo_proximity_changed", ["inst_001", 0.75, "voice"]
	)
	assert_signal_emitted_with_parameters(
		EventBus, "fragment_discovered", ["fragment_01", "inst_001"]
	)
	assert_signal_emitted_with_parameters(
		EventBus, "portal_completed", ["fragment_01", "museum_001", false, "A recovered gear."]
	)
	assert_signal_emitted_with_parameters(EventBus, "fragment_seated", ["fragment_01", 0])
