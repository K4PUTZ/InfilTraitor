## PickMath — the pure geometry of picking (kept out of `Board3DLive`, which needs the autoloads and so cannot be loaded
## headless by a selftest).
class_name PickMath
extends RefCounted


## Distance along a ray to the first face of the box over GU `gu`, standing on the ground (y = 0) and `height` tall in
## world units; -1 on a miss. `origin` inside the box answers 0.
static func ray_box(origin: Vector3, dir: Vector3, gu: Vector2i, height: float) -> float:
	var lo := Vector3(float(gu.x), 0.0, float(gu.y))
	var hi := Vector3(float(gu.x + 1), height, float(gu.y + 1))
	var t_min: float = 0.0
	var t_max: float = INF
	for axis in range(3):
		var o: float = origin[axis]
		var d: float = dir[axis]
		if absf(d) < 1e-9:
			if o < lo[axis] or o > hi[axis]:
				return -1.0
			continue
		var t1: float = (lo[axis] - o) / d
		var t2: float = (hi[axis] - o) / d
		t_min = maxf(t_min, minf(t1, t2))
		t_max = minf(t_max, maxf(t1, t2))
		if t_min > t_max:
			return -1.0
	return t_min
