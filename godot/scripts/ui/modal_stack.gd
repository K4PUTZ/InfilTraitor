## ModalStack — single source of truth for what Escape targets next.
##
## Root cause this replaces: Escape (`ui_pause`) was handled unconditionally
## in InputController._input(), which runs before room.gd's own
## _unhandled_input() — so a context menu's own Escape-aware check never got
## a chance to run, and Escape always opened the Main Menu instead of
## cancelling whatever was actually on top (2026-07-22 bug report).
##
## Any modal — a WindowBase panel, the grenade context menu, a future
## sub-menu — pushes its own close callable when it opens and is removed
## when it closes, by whatever path (Escape, its own Cancel/Back button, an
## outside click). Escape always targets the top of the stack, so nested
## menus (Main Menu -> Controls, or a world context menu opened over
## gameplay) close in the right order on successive presses instead of every
## Escape independently racing to open the Main Menu.
class_name ModalStack

var _stack: Array[Callable] = []


## Register a modal as open. No-op if already registered (a modal that opens
## twice without closing should not get two stack entries for one Escape).
func push(close_callable: Callable) -> void:
	if not _stack.has(close_callable):
		_stack.append(close_callable)


## Unregister a modal that closed through some other path than handle_escape()
## (its own button, an outside click) so the stack does not keep a stale entry.
func remove(close_callable: Callable) -> void:
	_stack.erase(close_callable)


func is_empty() -> bool:
	return _stack.is_empty()


## Escape entry point: close only the top-most modal (last one opened).
## Returns false if the stack was already empty — the caller's own Escape
## fallback (e.g. open the Main Menu) applies in that case instead.
func handle_escape() -> bool:
	if _stack.is_empty():
		return false
	var close_callable: Callable = _stack.pop_back()
	close_callable.call()
	return true
