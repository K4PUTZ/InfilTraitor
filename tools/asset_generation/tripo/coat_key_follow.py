"""The coat's per-frame corrective keys follow the timeline (Director, 2026-11-13).

A coat fix is keyed per pose, `<Name>Fix_f<frame>` (ThrowFix_f09, ThrowFix_f12, ...). Blender's Edit Mode edits the ACTIVE shape key, not the
frame the timeline is on, so an edit made at frame 15 with `_f12` active lands in `_f12`. This module keeps the active key on the one named
for the frame nearest the current one, so moving along the timeline is enough (as in After Effects: the playhead picks the layer).

Embedded in a timeline `.blend` as a text datablock (`add_to_blend`, `use_module` on: it registers when the file opens; Blender asks once
to allow auto-running scripts). Never switches while the coat is in Edit Mode. A key's frame is read from the animation (2026-11-15:
the end keys `CrouchFix` / `IdleFix` carry no frame in their name); keys never keyed at 1 and with no `_f<N>` are left alone. It also
LOCKS every key but the one at home on the current frame, and the first frame's key always, so an edit cannot land in the wrong key.
"""
import re

KEY_PATTERN = re.compile(r"^(.+Fix)_f(\d+)$")
COAT = "Outfit_Coat"
FULL = 0.999   ## a key is "at home" on the frame where its value is keyed at 1


def _fcurves(action):
    """Every F-curve of an action, legacy (`action.fcurves`) or layered (Blender 4.4+: layers -> strips -> channelbags)."""
    curves = list(getattr(action, "fcurves", None) or [])
    for layer in getattr(action, "layers", []):
        for strip in layer.strips:
            for bag in getattr(strip, "channelbags", []):
                curves.extend(bag.fcurves)
    return curves


def key_frames(coat):
    """{key index: its frame}. The frame comes from the animation (the first keyframe where the key's value is 1), so a key named with no
    frame (`CrouchFix`, ending the clip; `IdleFix`, inherited from the previous one) is found too; `_f<N>` in the name is the fallback."""
    keys = coat.data.shape_keys
    blocks = keys.key_blocks
    frames = {}
    action = keys.animation_data.action if keys.animation_data else None
    if action is not None:
        for fc in _fcurves(action):
            m = re.match(r'^key_blocks\["(.+)"\]\.value$', fc.data_path)
            if m is None or m.group(1) not in blocks:
                continue
            full = [p.co[0] for p in fc.keyframe_points if p.co[1] >= FULL]
            if full:
                frames[blocks.find(m.group(1))] = int(round(min(full)))
    for index, key in enumerate(blocks):
        m = KEY_PATTERN.match(key.name)
        if m is not None and index not in frames:
            frames[index] = int(m.group(2))
    return frames


def follow(scene, depsgraph=None):
    """The active coat key is the one at home on this frame (the nearest one between keys). Only that key is editable, and only ON its
    frame: every other key (the Basis and the other clips' keys included) is locked (`lock_shape`, which Edit Mode respects), and the key at home on the clip's FIRST frame stays locked
    always, since that pose belongs to the clip before this one. Between keyframes nothing is editable."""
    import bpy
    coat = bpy.data.objects.get(COAT)
    if coat is None or coat.mode == "EDIT" or coat.data.shape_keys is None:
        return
    blocks = coat.data.shape_keys.key_blocks
    frames = key_frames(coat)
    if not frames:
        return
    here = scene.frame_current
    best = min(frames, key=lambda i: (abs(frames[i] - here), frames[i]))
    editable = best if frames[best] == here and frames[best] != scene.frame_start else None
    for index in range(len(blocks)):   ## every key, the Basis and other clips' keys too
        lock = index != editable
        if blocks[index].lock_shape != lock:
            blocks[index].lock_shape = lock
    if coat.active_shape_key_index != best:
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
