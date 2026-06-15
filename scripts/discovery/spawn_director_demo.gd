class_name SpawnDirectorDemo
## Debug helper that runs three sequential Spawn Director placements for the same
## fragment and player, retaining history between runs, and writes the placement
## evidence to the repository's documented evidence location.
##
## This is a headless-friendly service; it does not manipulate scene nodes.

const EVIDENCE_DIR := "res://docs/evidence/placement_logs"
const DEFAULT_FILENAME := "phase5_three_run_demo.json"


## Runs three placements with the supplied seeds and returns one audit log per run.
## History is persisted between runs via GameState.save_state.persistent.spawn_history.
static func run(
	repo: DataRepository, fragment_id: String, seeds: Array[int], player_id: String = "demo-player"
) -> Array[Dictionary]:
	var director := SpawnDirector.new(repo, GameState)
	return director.run_three_seed_demo(player_id, fragment_id, seeds)


## Writes the three-run audit logs to docs/evidence/placement_logs/phase5_three_run_demo.json.
static func run_and_save(
	repo: DataRepository,
	fragment_id: String,
	seeds: Array[int] = [12345, 23456, 34567],
	player_id: String = "demo-player",
	file_name: String = DEFAULT_FILENAME
) -> Array[Dictionary]:
	var logs := run(repo, fragment_id, seeds, player_id)
	_write_evidence(logs, file_name)
	return logs


static func _write_evidence(logs: Array[Dictionary], file_name: String) -> void:
	var dir := DirAccess.open("res://docs")
	if dir == null:
		push_warning("SpawnDirectorDemo: cannot open res://docs for evidence")
		return
	if not dir.dir_exists("evidence"):
		dir.make_dir("evidence")
	var evidence_dir := DirAccess.open("res://docs/evidence")
	if evidence_dir != null and not evidence_dir.dir_exists("placement_logs"):
		evidence_dir.make_dir("placement_logs")

	var payload := {
		"generated_at": Time.get_datetime_string_from_system(),
		"player_id": logs[0].get("player_id", "") if not logs.is_empty() else "",
		"runs": logs,
	}
	var path := EVIDENCE_DIR.path_join(file_name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("SpawnDirectorDemo: could not write evidence to %s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
