"""The coat's per-frame corrective keys follow the timeline (Director, 2026-11-13).

A coat fix is keyed per pose, `<Name>Fix_f<frame>` (ThrowFix_f09, ThrowFix_f12, ...). Blender's Edit Mode edits the ACTIVE shape key, not the
frame the timeline is on, so an edit made at frame 15 with `_f12` active lands in `_f12`. This module keeps the active key on the one named
for the frame nearest the current one, so moving along the timeline is enough (as in After Effects: the playhead picks the layer).

Embedded in a timeline `.blend` as a text datablock (`add_to_blend`, `use_module` on: it registers when the file opens; Blender asks once
to allow auto-running scripts). Never switches while the coat is in Edit Mode. Keys without a frame in their name are left alone.
"""
import re

KEY_PATTERN = re.compile(r"^(.+Fix)_f(\d+)$")
COAT = "Outfit_Coat"


def follow(scene, depsgraph=None):
    import bpy
    coat = bpy.data.objects.get(COAT)
    if coat is None or coat.mode == "EDIT" or coat.data.shape_keys is None:
        return
    blocks = coat.data.shape_keys.key_blocks
    here = scene.frame_current
    best, best_d = None, None
    for index, key in enumerate(blocks):
        m = KEY_PATTERN.match(key.name)
        if m is None:
            continue
        d = abs(int(m.group(2)) - here)
        if best_d is None or d < best_d:
            best, best_d = index, d
    if best is not None and coat.active_shape_key_index != best:
        coat.active_shape_key_index = best


def register():
    import bpy
    unregister()
    bpy.app.handlers.frame_change_post.append(follow)
    bpy.app.handlers.load_post.append(_after_load)
    follow(bpy.context.scene)


def unregister():
    import bpy
    for handlers in (bpy.app.handlers.frame_change_post, bpy.app.handlers.load_post):
        for h in [h for h in handlers if getattr(h, "__name__", "") in ("follow", "_after_load")]:
            handlers.remove(h)


def _after_load(*_args):
    import bpy
    follow(bpy.context.scene)


def add_to_blend(name="coat_key_follow.py"):
    """Embed this file as a module text of the open .blend (the caller saves)."""
    import bpy
    text = bpy.data.texts.get(name) or bpy.data.texts.new(name)
    text.clear()
    text.write(open(__file__).read())
    text.use_module = True
    return text


if __name__ == "__main__":
    register()
