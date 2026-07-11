extends MainLoop

func _initialize():
    print("Test start - checking if compositor loads...")
    var compositor_class = preload("res://godot/scripts/systems/bake_compositor.gd")
    if compositor_class:
        print("SUCCESS: Compositor loaded!")
    else:
        print("FAILURE: Could not load compositor")
    return true

