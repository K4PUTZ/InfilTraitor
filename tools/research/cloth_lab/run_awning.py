"""run_awning.py — ROOF_LAB room B's roof (gu 15..19 x 6..10, 2 GU up) under GRAVITY ONLY, no blast. Supported along its two back walls
(x = 15 west edge all along; z = 6 north edge as far as the wall row reaches, x <= 18), free on the east and south edges.
Usage: python3 run_awning.py <scenario> [seconds]"""
import json, os, subprocess, sys, time
import numpy as np
from PIL import Image
from pd import PDSheet
from render import Camera, render_scene_zb as render_scene, profile_panel, font
from PIL import ImageDraw

OUT = os.environ.get("CLOTH_OUT", "out")
FABRIC = (0.78, 0.74, 0.66)
CARDBOARD = (0.70, 0.55, 0.36)
N = 33
H = 4.0 / (N - 1)

SCENARIOS = {
    #  name:            material,  lb,   yield_theta, k_shear, drag, post
    "fabric":           dict(mat="fabric",    lb=0.12, yk=np.inf, ksh=60.0,   drag=1.0, post=False, color=FABRIC),
    "fabric_post":      dict(mat="fabric",    lb=0.12, yk=np.inf, ksh=60.0,   drag=1.0, post=True,  color=FABRIC),
    "cardboard":        dict(mat="cardboard", lb=0.70, yk=1.2,   ksh=1500.0, drag=0.4, post=False, color=CARDBOARD),
    "cardboard_post":   dict(mat="cardboard", lb=0.70, yk=1.2,   ksh=1500.0, drag=0.4, post=True,  color=CARDBOARD),
    "cardboard_elastic": dict(mat="cardboard (elastic only)", lb=0.70, yk=np.inf, ksh=1500.0, drag=0.4, post=False, color=CARDBOARD),
}

WALLS = [((14.0, 0.0, 5.0), (15.0, 2.0, 10.0)), ((14.0, 0.0, 5.0), (18.0, 2.0, 6.0))]
POST_BOX = ((18.94, 0.0, 9.94), (19.06, 2.0, 10.06))


def build(sc):
    s = PDSheet(N, N, H, (15.0, 2.0, 6.0), sc["lb"], k_stretch=3000.0, k_shear=sc["ksh"], yield_kappa=sc["yk"], drag=sc["drag"],
                dt=1.0 / 60.0, iters=12)
    idx = s.idx
    pins = list(idx[0, :])                                   # west edge, on the wall x = 14 (its top is the roof's level)
    pins += [idx[i, 0] for i in range(1, 25)]                # north edge as far as the wall row z = 5 reaches (x <= 18)
    if sc["post"]:
        pins += [idx[i, j] for i in range(N - 3, N) for j in range(N - 3, N)]   # a 3x3 grommet patch at the free corner
    s.pin(pins)
    s.boxes = list(WALLS)
    return s


def diag(grid):
    d = np.array([grid[i, i] for i in range(N)])
    s = ((d[:, 0] - 15.0) + (d[:, 2] - 6.0)) / np.sqrt(2.0)
    return s, d[:, 1]


def main():
    name = sys.argv[1]
    seconds = float(sys.argv[2]) if len(sys.argv) > 2 else 6.0
    sc = SCENARIOS[name]
    os.makedirs(OUT, exist_ok=True)
    fdir = os.path.join(OUT, name + "_frames")
    os.makedirs(fdir, exist_ok=True)
    s = build(sc)
    cam = Camera((16.5, 1.0, 8.0), 100.0, (800, 720))
    steps = int(round(seconds * 60))
    snaps, hist = [], []
    t0 = time.time()
    for k in range(steps):
        s.step()
        if k % 2 == 1:
            snaps.append((s.t, s.grid().copy()))
        if k % 30 == 29:
            hist.append(diag(s.grid()))
    print(f"[{name}] simulated {seconds}s in {time.time()-t0:.1f}s ({1000*(time.time()-t0)/steps:.1f} ms/step, {N*N} nodes)")
    np.savez_compressed(os.path.join(OUT, name + ".npz"), t=np.array([t for t, _ in snaps]), g=np.array([g for _, g in snaps]))
    pinned = s.pinned
    t0 = time.time()
    keyframes = {}
    for f, (t, g) in enumerate(snaps):
        title = f"{sc['mat']}  |  corner post: {'yes' if sc['post'] else 'no'}  |  t = {t:4.2f} s"
        iso = render_scene(g, cam, WALLS, sc["color"], pinned=pinned, size=(800, 720), post=POST_BOX if sc["post"] else None, title=title)
        sx, sy = diag(g)
        prof = profile_panel([(a, b) for a, b in hist[: max(0, int(t * 2))]] + [(sx, sy)],
                             [f"section along the diagonal  (support corner -> free corner)", f"free corner: {g[-1, -1, 1]:.2f} GU up   lowest node: {g[..., 1].min():.2f}"],
                             note="grey = every 0.5 s,  blue = now")
        info = Image.new("RGB", (480, 390), (24, 26, 30))
        d = ImageDraw.Draw(info)
        lines = [f"nodes: {N*N}  (1 per voxel, 1/8 GU)", f"bend length lb = {sc['lb']:.2f} GU", f"crease: {'none (elastic)' if not np.isfinite(sc['yk']) else 'at radius ' + format(1.0 / sc['yk'], '.2f') + ' GU'}",
                 f"pinned: west edge, north edge to x=18" + (", corner" if sc["post"] else ""), f"gravity 8.0 GU/s2, drag {sc['drag']}/s", "",
                 "on the floor: %d%% of the nodes" % int(100 * np.mean(g[..., 1] < 0.05))]
        for i, ln in enumerate(lines):
            d.text((14, 14 + 22 * i), ln, fill=(205, 207, 214), font=font(15))
        frame = Image.new("RGB", (1280, 720), (24, 26, 30))
        frame.paste(iso, (0, 0)); frame.paste(prof, (800, 0)); frame.paste(info, (800, 330))
        frame.save(os.path.join(fdir, f"f{f:04d}.png"))
        for kt in (0.0, 0.3, 0.6, 1.0, 2.0, 4.0, seconds):
            if abs(t - kt) < 1 / 60.0 + 1e-6 and kt not in keyframes:
                keyframes[kt] = iso
    print(f"[{name}] rendered {len(snaps)} frames in {time.time()-t0:.1f}s")
    # contact sheet of key frames
    keys = sorted(keyframes)
    sheet = Image.new("RGB", (3 * 520, 2 * 470), (20, 22, 26))
    for n, kt in enumerate(keys[:6]):
        im = keyframes[kt].resize((520, 468))
        ImageDraw.Draw(im).text((10, 440), f"t = {kt:.1f} s", fill=(235, 235, 240), font=font(18))
        sheet.paste(im, ((n % 3) * 520, (n // 3) * 470))
    sheet.save(os.path.join(OUT, name + "_sheet.png"))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "30", "-i", os.path.join(fdir, "f%04d.png"), "-c:v", "libx264", "-pix_fmt", "yuv420p",
                    "-crf", "20", os.path.join(OUT, name + ".mp4")], check=True)
    final = snaps[-1][1]
    print(json.dumps({"scenario": name, "free_corner_y": float(final[-1, -1, 1]), "lowest": float(final[..., 1].min()),
                      "on_floor_pct": float(100 * np.mean(final[..., 1] < 0.05)),
                      "stretch_max_pct": float(100 * (np.linalg.norm(np.diff(final, axis=0), axis=2).max() / H - 1))}))


if __name__ == "__main__":
    main()
