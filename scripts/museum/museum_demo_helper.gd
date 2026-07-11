class_name MuseumDemoHelper
## Debug-only helper for the museum / Portal recording workflow (P16.4 video seam).
##
## These functions are intentionally separated from normal progression and are only
## wired into DemoMenu, which itself is only available in debug builds. They let the
## team record one-button evidence of:
##
##   * POSTing a Gold-tier museum record through the backend Portal proxy,
##   * POSTing a Master Artifact record,
##   * refreshing the gallery from the Portal,
##   * opening the mock Portal HTML gallery in the system browser.
##
## The helper uses the same MuseumService / PortalClient path as the real game so the
## demo is representative, but it fabricates lightweight stand-in objects so it can run
## from any scene without a live delivery or finale state.

const GALLERY_BASE_URL := "http://localhost:3001"
const DEFAULT_GOLD_RECORD_ID := "oton_death_mask"
const DEFAULT_GOLD_DISPLAY_NAME := "Oton Death Mask"
const DEFAULT_MASTER_RECORD_ID := "master_artifact_demo"
const DEFAULT_MASTER_DISPLAY_NAME := "Heirloom Timepiece (placeholder)"


## Posts a stand-in Gold-tier record to the backend Portal proxy. Returns the
## deterministic museum_entry_id so the caller can show status.
static func post_test_gold_record(record_id := DEFAULT_GOLD_RECORD_ID) -> String:
	var inst := ObjectInstance.new()
	inst.template_id = record_id
	inst.condition = 95.0

	var template := ScrapObjectTemplate.new()
	template.id = record_id
	template.display_name = (
		DEFAULT_GOLD_DISPLAY_NAME if record_id == DEFAULT_GOLD_RECORD_ID else record_id
	)

	return MuseumService.post_gold_discovery(inst, template)


## Posts the real (or configured) Master Artifact record to the backend Portal proxy.
## Returns the deterministic museum_entry_id, or an empty string if no master artifact
## is configured.
static func post_test_master_artifact() -> String:
	if DataRepository.is_singleton_loaded() and DataRepository.singleton().master_artifact != null:
		return MuseumService.post_master_artifact()

	push_warning("MuseumDemoHelper: no master artifact configured; skipping.")
	return ""


## Asks MuseumService to refresh the gallery from the upstream Portal.
static func refresh_gallery() -> void:
	MuseumService.refresh_gallery()


## Opens the mock Portal HTML gallery for the current player in the default browser.
static func open_browser_gallery() -> void:
	var player_id := GameState.player_id if not GameState.player_id.is_empty() else "local-player"
	var url := "%s/?player_id=%s" % [GALLERY_BASE_URL, player_id.uri_encode()]
	OS.shell_open(url)
