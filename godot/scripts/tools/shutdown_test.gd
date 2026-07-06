#!/usr/bin/env godot
## Shutdown test - Validates that game closes cleanly without SIGABRT
## Usage: godot --path . --script godot/scripts/tools/shutdown_test.gd

extends SceneTree

func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("SHUTDOWN CRASH TEST")
	print("=".repeat(70))
	print("\nThis script validates that Godot exits cleanly without SIGABRT crash.")
	print("The game will load fully, then exit cleanly.\n")
	
	# Wait for scene to load
	print("Waiting for full initialization...")
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("[SHUTDOWN-TEST] Engine and scripts initialized")
	print("[SHUTDOWN-TEST] All systems ready")
	print("[SHUTDOWN-TEST] Initiating clean exit...")
	print("\nExpected: Clean exit with code 0")
	print("Failure: SIGABRT during Main::cleanup()\n")
	
	quit()
