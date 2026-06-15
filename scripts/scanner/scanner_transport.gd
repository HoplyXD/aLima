class_name ScannerTransport
## Minimal transport boundary for the scanner.
##
## Phase 7 implements only the cached fixture transport. Phase 8 will add an
## HTTP transport that returns the same ScannerResponse type. The scene code
## never knows which transport is in use.


## Submits a request and returns a result dictionary with `ok`, `response`
## (ScannerResponse or Dictionary), and optional `error`. Implementations must
## not block the main thread.
func submit(_request: ScannerRequest) -> Dictionary:
	push_warning("ScannerTransport.submit() called on base class")
	return {"ok": false, "error": "no transport implementation"}
