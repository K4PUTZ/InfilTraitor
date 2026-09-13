# RESUMO DE SESSÃO — 2026-09-12
## Diagnóstico em dispositivo: a explosão no celular

**Pergunta prioritária (Director):** *"testar se a explosão vai ser factível num
celular comum. O resto não serve pra nada se o jogo não funcionar."*

**Resposta: não é factível hoje — e a explosão não é a causa.**

---

## 1. O veredito

Teto ratificado nesta sessão (§0.5 do
[`DEVICE_DIAGNOSTICS_MASTER_PLAN`](PLANNING/DEVICE_DIAGNOSTICS_MASTER_PLAN.md)):
sonho 60 fps, **meta 30 fps / 33,3 ms**, piso 24–25 fps — **só nos frames de
playback**; load, load de mapa e pre-cook podem demorar.

| | Moto g04s | Galaxy A16 5G |
|---|---|---|
| playback, jogado na mão | 104,5 ms | **78–88 ms** |
| pior frame de playback | 486 ms | 2 134 ms |
| veredito vs 33,3 ms | 3,1× acima | **2,4–2,6× acima** |

O jogo **roda** nos dois aparelhos (Vulkan Mobile, sem erro fatal). O que não
cabe no orçamento é o frame.

## 2. A causa, medida por três instrumentos independentes

| instrumento | o que viu |
|---|---|
| censo de memória | o mapa sozinho custa **2,2 GB**; ~530 MB de gráfica são room build / colocação / submissão |
| ablação do bake | o bake leva o TileSet de **98 → 32 987 tiles**; desligado = metade da memória, 2,3× mais lento |
| frame probe | **1 379 draw calls, 25 535 objetos, 14–20 ms de GPU — com o tabuleiro PARADO** |

**32 camadas opacas + 16 de vidro sobre 145 448 células** é o custo: em memória,
em draw calls e em tempo de GPU. A detonação adiciona ~10 ms a um frame que já
custa ~20. **Ela nunca foi o problema; é o que roda em cima de um tabuleiro que
já consome a maior parte do frame.**

Corolário medido: uma CPU 2× mais rápida (Exynos 1330 vs T606) cortou o boot pela
metade e moveu o playback em **8%**.

## 3. Ferramentas construídas (todas commitadas e com selftest onde cabia)

| | |
|---|---|
| `tools/persistent/export_android.py` | export + **assinatura** + asserção de conteúdo + install. 491 → 130,6 MB |
| `tools/persistent/device_run.py` | precondições, launch pelo alias, logcat filtrado, `--mem-poll`, `--device`, force-stop ao fim |
| `DevFlags` (autoload) | `env → arquivo → default`; torna ~200 probes alcançáveis dentro do APK |
| `MemStage` | marcadores de memória por estágio de boot |
| `VoxelRenderer.memory_census()` | censo de TileSet/atlas/camadas |
| benchmark `BENCHMARK=1` | 3 detonações idênticas, RNG travado, encerra o processo |
| `BakeConfig.force_no_bake` | a ablação do bake, alcançável no APK |

## 4. Armadilhas encontradas — o que custaria caro repetir

- **`--export-release` deixa um APK completo e SEM ASSINATURA quando o export
  FALHA.** Exit 1, arquivo perfeito no disco, zero `META-INF`. A primeira versão
  do script checava `apk.exists()` e aprovou esse build.
- **Tela desligada lê como driver Vulkan quebrado.** `Failed to create vulkan
  window` era o aparelho dormindo. Um protetor de tela esteve a um relatório de
  virar veredito de renderer.
- **`is_resolving_action()` é o lock de ação, não o fim do playback** — libera na
  metade do blast. O benchmark matava o processo antes do relatório.
- **Granada é consumida ao detonar** — reusar o índice 0 fazia 2 de 3 rodadas não
  medirem nada enquanto imprimiam "resolved".
- **Instrumentos nulos são nulos, não zero:** `get_rendering_info()` = 0,0 MB com
  atlas de 163,8 MB; `get_static_memory_usage()` é debug-only; `FileAccess` não
  abre `/proc` no Android. Todos registrados como indisponíveis.
- **"Pega a terceira rodada, está quente" não é regra.** Moto esquenta
  (4728→486 ms), Galaxy degrada (672→2134 ms) — é propriedade da folga de RAM.

## 5. ⚠️ Aberto e não resolvido

- **DIAG-11:** o benchmark automatizado dá 24 ms onde a mão dá 78–88 ms. O frame
  probe mostrou que a diferença é o **custo ocioso do tabuleiro**, não a
  explosão — mas *o que* eleva esse custo na sessão jogada ainda não tem nome.
  Agora é medível: comparar draw calls e objetos contra os números do §10.10.
- **A decisão de arquitetura** (menos camadas, ou menos células vivas por
  camada). É do Director e do `PERFORMANCE_MASTER_PLAN`. Três listas de
  candidatos foram escritas antes das suas medições nesta sessão e **duas
  saíram erradas** — não há caso para chutar a quarta.
- **Reprecificar o bake:** ~1 GB de RAM por 2,3× de velocidade de blast, num
  aparelho de 3,4 GB.
- **`BakeConfig.enabled = true`** enquanto o próprio comentário diz que o canon
  de build de release é `false`. Todo número desta sessão foi com bake LIGADO.
- **SYS-CHECK-01** (`PERFORMANCE_MASTER_PLAN` §15): checkup de sistema na
  primeira execução. Capturado, não desenhado.
- **Interface (JAMES):** Part 6 botão sanduíche → menu principal; Part 7
  orientação dirigindo M/D.

## 6. Onde retomar

O aparelho é caracterizado, o arnês está pronto e o ciclo inteiro é um comando:

```bash
python3 tools/persistent/export_android.py --install --device <serial>
python3 tools/persistent/device_run.py --device <serial> --seconds 150 --mem-poll 20
```

A próxima sessão começa pela decisão de arquitetura do §5, não por mais medição.
