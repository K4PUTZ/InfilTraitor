## Scale study — dense content, desktop, 2026-10-07

| GU | claims | store MB | store ms | quads | board ms | load s | idle ms/f | idle proc | draws | nodes | blast mean | blast worst | mem MB | plane err | ERR |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 24 | 176298 | 13.65 | 113 | 1211 | 612 | 3.7 | 16.7 | 17.9 | 111 | 1123 | 17 | 109.2 | 426 | 0 | 0 |
| 32 | 267733 | 20.71 | 173 | 1657 | 823 | 4.5 | 16.7 | 18.3 | 102 | 1339 | 16.6 | 47.1 | 542 | 0 | 0 |
| 44 | 506061 | 35.09 | 329 | 3378 | 1404 | 7 | 16.7 | 18.9 | 90 | 1999 | 16.6 | 49.6 | 869 | 0 | 0 |
| 64 | 1010677 | 66.59 | 670 | 6972 | 3417 | 13.6 | 16.7 | 33.5 | 95 | 3490 | 16.9 | 103.4 | 1325 | 1 | 1 |
| 96 | 2148413 | 137.37 | 1407 | 15169 | 6072 | 29.3 | 16.7 | 42.6 | 107 | 7031 | 20.6 | 653 | 1890 | 1 | 1 |
| 128 | 3766238 | 234.4 | 2467 | 26967 | 10074 | 53 | 16.7 | 39.4 | 105 | 12316 | 23.9 | 1132.4 | 3166 | 1 | 1 |

Cost per GU^2 relative to the 24 GU row (1.00 = linear; above = the curve bends up):
- claims — 24: 1.00, 32: 0.85, 44: 0.85, 64: 0.81, 96: 0.76, 128: 0.75
- store ms — 24: 1.00, 32: 0.86, 44: 0.87, 64: 0.83, 96: 0.78, 128: 0.77
- board ms — 24: 1.00, 32: 0.76, 44: 0.68, 64: 0.79, 96: 0.62, 128: 0.58
- load s — 24: 1.00, 32: 0.68, 44: 0.56, 64: 0.52, 96: 0.49, 128: 0.50
- mem MB — 24: 1.00, 32: 0.72, 44: 0.61, 64: 0.44, 96: 0.28, 128: 0.26

### Reading (desktop shape, 2026-10-07; handset rows owed at step B)
- **The 46 GU cell-plane limit is the first hard wall, and it is real:** from 64 GU the engine prints
  `[CellPlaneStore] PERF-P3: cell (40, 448) is outside the 512x512 cell plane — raise SOOT_TEX_SIZE` (one loud line; every cell past the
  plane draws with no light or soot). Everything above 44 in this table is a map the game cannot yet render correctly.
- **Size alone is cheap, content is not:** with the same sizes and NO props / guards (`scale_study_desktop_empty_2026-10-07.md`) the
  worst blast frame stays 35-68 ms up to 96 GU and 146 ms at 128; with STRESS's density it is 103 ms at 64, 653 ms at 96, 1 132 ms at 128.
  The blast bends with what is in the map (props: the debris job; glass; guards), not with the floor area.
- **Idle `process` ms bends at 64 GU with content** (18 -> 33-43 ms; flat 18 ms empty): guard-cone smoothing scales with the guard count
  (24 -> 223 at 128 GU), the same cost the STRESS idle frame already shows (13 ms of `guard cone smooth`).
- **Linear in the store:** claims and store ms per GU^2 hold at 0.75-0.87 of the 24 GU row (a fixed cost amortising, no bend); the load
  grows about as the area (53 s at 128 GU dense on this desktop). Memory per GU is the unreliable column here (system-available delta);
  read PSS on the handset.
- Caveat: the FIRST size of a series pays a cache warm-up (24 GU empty: board 1 084 ms against 704 at 32), which skews the
  per-GU^2 ratios built on it. Re-run the base row, or read the absolute columns.
