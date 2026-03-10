from __future__ import annotations

from pathlib import Path
import struct

import Vision
from Foundation import NSURL


def recognize_text(image_path: Path) -> list[dict[str, object]]:
    input_url = NSURL.fileURLWithPath_(str(image_path))
    handler = Vision.VNImageRequestHandler.alloc().initWithURL_options_(input_url, None)

    results: list[dict[str, object]] = []

    def completion_handler(request, error):
        if error:
            return
        for observation in request.results() or []:
            candidates = observation.topCandidates_(1)
            if not candidates:
                continue
            top_candidate = candidates[0]
            bbox = observation.boundingBox()
            results.append(
                {
                    "text": str(top_candidate.string()),
                    "confidence": float(top_candidate.confidence()),
                    "bbox": [
                        float(bbox.origin.x),
                        float(bbox.origin.y),
                        float(bbox.size.width),
                        float(bbox.size.height),
                    ],
                }
            )

    request = Vision.VNRecognizeTextRequest.alloc().initWithCompletionHandler_(completion_handler)
    request.setRecognitionLevel_(Vision.VNRequestTextRecognitionLevelAccurate)
    handler.performRequests_error_([request], None)
    return results


def contains_text(image_path: Path, needle: str) -> bool:
    needle_lower = needle.lower()
    return any(needle_lower in str(entry["text"]).lower() for entry in recognize_text(image_path))


def _png_dimensions(image_path: Path) -> tuple[int, int]:
    """Read PNG width and height from the IHDR chunk without external dependencies."""
    with open(image_path, "rb") as f:
        f.seek(16)  # skip 8-byte signature + 4-byte length + 4-byte 'IHDR'
        width = struct.unpack(">I", f.read(4))[0]
        height = struct.unpack(">I", f.read(4))[0]
    return width, height


def find_text_center_coords(
    image_path: Path,
    needle: str,
    screen_width: int,
    screen_height: int,
) -> tuple[int, int] | None:
    """Find the first OCR entry matching *needle* and return its center as logical screen coords.

    Vision bounding boxes are normalised to [0, 1] with the origin at the **bottom-left** of the
    image and the y-axis pointing **upward**.  macOS screen coordinates (used by cliclick) have
    the origin at the **top-left** with y pointing **downward**.  This function applies the Y-flip
    so the returned (x, y) coordinates can be passed directly to click_at() / double_click_at().

    On Retina displays screencapture produces a 2× image, but Vision normalises relative to that
    full-resolution image, so multiplying by the *logical* screen size (as returned by
    get_screen_size()) is enough — no explicit scale factor is needed.
    """
    entries = recognize_text(image_path)
    needle_lower = needle.lower()
    for entry in entries:
        if needle_lower not in str(entry["text"]).lower():
            continue
        bx, by, bw, bh = entry["bbox"]
        # Centre in Vision coords (bottom-left origin, y upward)
        cx = bx + bw / 2.0
        cy = by + bh / 2.0
        # Convert to logical screen coords (top-left origin, y downward)
        lx = int(cx * screen_width)
        ly = int((1.0 - cy) * screen_height)
        return lx, ly
    return None
