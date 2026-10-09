# Session record — 2026-10-09: project and performance evaluation

No code changed. Director: *"vamos gastar uma rodada pra fazer uma avaliação do projeto como um todo, e do trabalho de aprimoramento
da performance até aqui. Reconhecendo que a parte de gameplay ainda está pendente."*

`verify.py smoke` PASSED at the start (102 s, 74 selftests) on `2fb06604`.

**The evaluation is [`docs/production/RETROSPECTIVE_2026-10.md`](../docs/production/RETROSPECTIVE_2026-10.md)** (the successor of the July
retrospective; indexed in `docs/README.md` and `docs/production/README.md`). Nothing in it is ratified: §8's five recommendations are
proposals awaiting the Director.

**Director's ruling, same day (retrospective §10, roadmap top block):** recommendations 1 (an exit and a freeze) and 2 (the five-minute
test early in A2) DECLINED; the performance phase closes only when the engine is fully optimised and ready for the gameplay load; the
fallback is a smaller segment, never lower quality. Recommendations 3-5 not ruled.

**Later the same day — the exit criterion and the performance work (Director: "Esse é o critério, pode seguir com o PB-3"; then "pode seguir com
todos os passos, tomando as decisões recomendadas"):** the exit criterion is `PERFORMANCE_BUDGET` §0d. PB-3 (segment-shaped maps, `gen_segment_map.py`,
`pb3_study.py`), PB-4 (segment cycle: flat) and seven PB-6 levers (§0f: pass split, solid-twin materials, sRGB cubic, blast-with-props fixes, cell plane
sized to the map, bulk light apply, parallel board load + cached decal catalogue) — on the Moto the HEAVY segment went from PSS 953 MiB / GPU 39.4 ms /
blast 332 ms / load 16.2 s to 757 MiB / 24.4 ms / 166 ms / 11.9 s, inside every measured part of §0d. Each lever identity-checked (pixel gate, board
probe against a fresh baseline, `LIGHT_BULK_CHECK`). `verify.py smoke` green at every commit; `verify.py full` was run once (plane change): every gate
green except the probe/pixel identity gates held to the stale `c9c0a119` baseline, then re-run against the fresh one: identical.

**Resume point:** owed on the performance phase — (1) Q5, the Director's: is ~7-12 s between segments acceptable, or should the next segment be
prepared while the player plays; (2) the Galaxy A16 round on the current code (not attached today); (3) GLASS g1's intermittent pixel-gate difference
(`technical_debt.md`); (4) the remaining load (store build ~1.6 s, board ~5 s before the parallel merge on the Moto, re-measure). Then PB-5's verdict
(§3) and PB-7 (the budget gate).
