## Mobile Testing — Local Server + ngrok

### Quick Start (Two Terminal Tabs)

**Tab 1: Local HTTP Server**
```bash
cd "/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR/export/web"
python3 -m http.server 8080
```
→ Serves the web build on `http://localhost:8080`

**Tab 2: ngrok Tunnel**
```bash
ngrok http 8080
```
→ Creates a public HTTPS tunnel (look for `Forwarding:` line in output)

### Testing on Mobile

| Access | URL | Use Case |
|--------|-----|----------|
| **Same WiFi (LAN)** | `http://<your-mac-ip>:8080` | Fast, low latency |
| **Any network (ngrok)** | `https://...ngrok-free.dev` | Remote testing, sharing |

**Find your Mac IP:**
```bash
ipconfig getifaddr en0
```

### Input on Mobile (FL-01+)

- **Single tap** → Select tile
- **Double tap** (same area, <300ms) → Move agent
- **One-finger drag** → Pan camera
- **Pinch** → Zoom (if configured)

### Stopping the Servers

```bash
# Kill Python server (check terminal or use Ctrl+C, or: pkill -f "http.server 8080")

# Stop ngrok (Ctrl+C in ngrok terminal)
```

**Note:** The web build at `export/web` must be re-exported from Godot if code changes. During development, use the Godot editor directly for faster iteration.