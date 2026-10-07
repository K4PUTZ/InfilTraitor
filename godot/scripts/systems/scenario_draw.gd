## ScenarioDraw — wait for the next DRAWN frame, but never forever.
##
## `await RenderingServer.frame_post_draw` returns only after a frame is actually drawn. A harness window sits off-screen
## (`--position 4000,4000`, so it never pops up over the Director's work) and macOS sometimes treats such a window as occluded: the engine
## then keeps running process frames flat out (`DisplayServerMacOS::can_any_window_draw()` is false, no draw is issued, ~100 % CPU) and
## every `await RenderingServer.frame_post_draw` waits for ever. Found 2026-10-06 after FOUR intermittent "hangs" (a scenario that never
## reached its next step; a `verify.py --baseline` boot that timed out), by sampling a hung process: its main thread was in ordinary
## `SceneTree::process` work and no drawing symbol appeared anywhere in the stack.
##
## ⚠️ THE CAUSE IS INFERRED, NOT PROVEN: the stack showed ordinary frames, `can_any_window_draw()` being asked and no draw issued; before this change about 3 of 6
## runs of one GLASS scenario hung, after it 14 of 14 ran clean, but the fallback was never seen firing (no warning in those 14), and a minimised window
## still draws, so the condition could not be forced. If a hang ever shows with this in place, the cause is something else.
##
## So: wait for the draw, but if `WAIT_FRAMES` process frames pass without one, say so (a warning) and force one
## (`RenderingServer.force_draw`), which draws the viewports whether or not the OS thinks the window is visible. A capture taken after it
## is a real frame. In gameplay the window is visible, a draw comes every frame and this costs nothing.
class_name ScenarioDraw
extends RefCounted

const WAIT_FRAMES: int = 20


static func next_drawn_frame(tree: SceneTree) -> void:
	var state := {"drawn": false}
	var on_draw := func() -> void:
		state["drawn"] = true
	RenderingServer.frame_post_draw.connect(on_draw, CONNECT_ONE_SHOT)
	var waited: int = 0
	while not state["drawn"] and waited < WAIT_FRAMES:
		await tree.process_frame
		waited += 1
	if state["drawn"]:
		return
	if RenderingServer.frame_post_draw.is_connected(on_draw):
		RenderingServer.frame_post_draw.disconnect(on_draw)
	push_warning("[ScenarioDraw] no frame was drawn in %d process frames (the window is probably occluded by the OS): forcing a draw" % WAIT_FRAMES)
	RenderingServer.force_draw(false)
