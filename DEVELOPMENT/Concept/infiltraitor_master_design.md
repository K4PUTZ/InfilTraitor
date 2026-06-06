# INFILTRAITOR — Master Design Document
> Consolidação de todas as decisões de design tomadas em sessão de brainstorming
> Data: Junho 2026 | Status: Definido — pronto para geração de prompts de implementação

---

## 1. VISÃO GERAL DO PROJETO

**Gênero:** Stealth tático turn-based com progressão RPG — jogo sem fim
**Plataforma primária:** Mobile (iOS / Android) com suporte a HTML5
**Engine:** Godot 4.x (GDScript)
**Orientação:** Portrait, câmera segue o agente
**Referências:** Dishonored (feeling), XCOM 2 (sistema tático), Phoenix Point (progressão adversarial), Hitman GO (mobile stealth), Invisible Inc (informação como recurso), Diablo (escalada de poder infinita)
**Pitch de uma frase:** "O único jogo de stealth tático que funciona em mobile — porque cada decisão é sua, não dos seus reflexos."

**Modelo de jogo:** INFILTRAITOR não tem fim. A campanha de 3 capítulos é a pré-história — um tutorial narrativo que apresenta o lore, justifica o título e introduz as mecânicas progressivamente. Após a campanha, o agente entra em **modo Freelance**, com missões geradas proceduralmente, pacotes de conteúdo extra e contribuições da comunidade. O jogo escala indefinidamente: inimigos ficam mais fortes, o agente também, e o desafio se mantém proporcional — como Diablo faz com seus ciclos de dificuldade.

---

## 2. CONCEITO CENTRAL

**Informação é o recurso primário.** O agente é um espião — sucesso depende de *saber* sem ser sabido. Fog of war, propagação de ruído e imprevisibilidade dos inimigos tornam cada run única e cada ação consequente.

**O nome é a narrativa:** INFILTRAITOR — o agente é tanto infiltrador quanto traidor. Ele descobre que serviu o lado errado e precisa desmantelar o sistema de dentro.

---

## 3. NARRATIVA

### 3.1 As Duas Facções Principais
| Facção | Face pública | Verdade |
|---|---|---|
| **A Agência** | Estabilidade, proteção da ordem global | Atinge estabilidade via vigilância, manipulação de governos e supressão de dissidência |
| **A Rede** | Transparência, liberdade de informação | Vaza dados classificados; às vezes endangers inocentes com exposição indiscriminada |

**Nenhuma facção é puramente heroica.** O jogador escolhe sua cumplicidade.

### 3.2 Estrutura Narrativa em Dois Modos

**MODO CAMPANHA — A Pré-História (3 Capítulos)**
Narrativa linear, curatorialmente projetada. Serve como tutorial completo do jogo.
Cada capítulo introduz uma facção inimiga e um conjunto de mecânicas novas.
Tem começo, meio e fim — o arco do traidor se resolve aqui.

```
CAPÍTULO 1 — O Ativo
  Agente opera para a Agência sem questionar.
  Aprende: detecção, cone de visão, sombras.
  Virada: missão encobre baixas civis. Agente nota a discrepância.

CAPÍTULO 2 — A Fratura
  Primeiro contato com informante da Rede.
  Aprende: barulho, cobertura, comunicação inimiga.
  Virada: a Agência começa a suspeitar do agente.

CAPÍTULO 3 — O Traidor
  Agência queima a cobertura. Agente vai às profundezas.
  Aprende: eletrônicos, sistemas automatizados, confronto avançado.
  Resolução: escolha final — destruir a Agência por dentro ou ir público.
  Desbloqueio: MODO FREELANCE.
```

**MODO FREELANCE — O Jogo Sem Fim**
Desbloqueado após completar a campanha. O agente agora opera por conta própria.
Missões são procedurais, escaláveis e potencialmente infinitas.

```
Fontes de missão (a definir em detalhes futuramente):
  → Gerador procedural com LLM (histórias, NPCs, diálogos, objetivos)
  → Pacotes de conteúdo extra (DLC, eventos sazonais)
  → Sugestões e contribuições da comunidade
  → Missões contrato de facções (repeat com stats maiores — ciclo Diablo)

O agente continua crescendo: mais HP, mais armadura, armas mais poderosas.
Os inimigos crescem proporcionalmente — nunca fica trivial.
O décimo tiro ainda mata. A tensão nunca desaparece.
```

### 3.3 Entrega Narrativa
- **Briefing de missão:** 2–3 linhas antes de cada nível. Pulável.
- **Mensagens de comm-link:** Balões de fala em tiles/eventos específicos. Não bloqueiam o jogo.
- **Fragmentos de intel:** Coletáveis opcionais que constroem o lore aprofundado.
- **Tela de vitória/derrota:** Resultado narrativo breve + stats + recompensas.
- **Dossier:** Log acumulado de intel entre missões para quem quer a narrativa completa.

### 3.4 Geração Narrativa por LLM (Modo Freelance — Futuro)
O gerador de missões do modo Freelance usará um LLM externo para produzir:
- Briefings de missão únicos com contexto coerente ao lore
- NPCs com nomes, motivações e diálogos situacionais
- Objetivos primários e secundários variados e balanceados
- Recompensas adequadas ao nível e dificuldade
- Segredos e easter eggs embutidos organicamente

**Premissa de arquitetura — não criar bloqueios:**
O sistema de missão deve ser desenhado com **separação clara entre estrutura e conteúdo**.
A estrutura (segmentos, tiles, inimigos, objetivos) é definida pelo engine.
O conteúdo (texto, nomes, narrativa) é uma camada plugável sobre essa estrutura.
Isso garante que o LLM possa ser integrado depois sem refatorar a lógica de missão.

```
Estrutura de missão (engine — implementar agora):
  MissionData {
    id, difficulty_tier, faction, segments[], objectives[], rewards[]
  }

Conteúdo narrativo (LLM — plugar depois):
  MissionNarrative {
    briefing_text, npc_names[], dialogue_lines[], secret_hint?
  }
```

O engine nunca deve depender do conteúdo narrativo para resolver lógica de jogo.

---

## 4. SISTEMA DE TURNO

### 4.1 Estrutura Base
- **Estritamente turn-based.** Cada turno o agente recebe **2 AP**.
- Cada AP pode ser gasto em: mover, usar gadget/skill, atacar, interagir, esperar.
- Após o agente gastar AP (ou encerrar manualmente), **todos os inimigos executam seus turnos sequencialmente.**
- Loop: *observar → planejar → agir → observar consequências.*

### 4.2 Ordem de Turno e Câmera Passeante
- Cada ator tem seu próprio turno. A câmera "passeia" por cada um em ordem.
- **Painel de retratos** no canto da tela mostra todos os atores ativos na cena, em ordem de turno. O ativo pulsa levemente. Após agir, fica muted.
- **Velocidade da câmera é variável:**
  - Turno de rotina: câmera rápida, jogador mal nota.
  - Guarda em estado de alerta: câmera desacelera.
  - Detecção iminente: câmera pausa dramaticamente antes de resolver.
  - Esta variação é implementada via variável de duração do tween — custo zero, impacto enorme.

### 4.3 Sistema de Tic por Mudança de Aresta
- Detecção e barulho são **event-driven**, não loops contínuos.
- Um "tic" dispara **sempre que qualquer ator muda de aresta** (cruza de um tile para outro).
- Ao cruzar uma aresta, o sistema verifica:
  - Exposição do tile de destino nos cones de todos os guardas ativos
  - Chance de barulho gerado pelo movimento
  - Atualização de rastro e overlays visuais
- Guardas que mudam de posição também disparam tic — o cone deles se move e pode revelar o agente que estava "seguro".
- Isso garante **determinismo** — o jogador pode sempre entender por que foi detectado.
- Garante também **performance** em mobile — sem loops por frame.

### 4.4 Overwatch e Reações
- Se o agente encerra o turno com AP não gasto via ação *Esperar*, entra em **Overwatch**.
- Durante o turno inimigo, se uma ameaça entrar no raio de visão, o agente pode reagir automaticamente com ação pré-selecionada.
- **Janela de reação de detecção:** quando detectado durante o turno inimigo, o jogo pausa brevemente e apresenta menu de emergência: usar gadget, usar skill, ou aceitar aumento do medidor de alerta.

---

## 5. SISTEMA DE DETECÇÃO

### 5.1 O Cone de Visão por Tiles
- Cada guarda tem uma direção de facing em **8 possibilidades** (N, NE, E, SE, S, SW, W, NW).
- O cone é uma **máscara de tiles com probabilidades fixas** que rotaciona/espelha conforme a direção.
- Diagonal e cardinal usam o mesmo conjunto de probabilidades — a máscara se adapta.

**Probabilidades base do cone (estado normal/patrulha):**
| Distância | Probabilidade base | Estado relaxado |
|---|---|---|
| Tile 1 (adjacente) | 100% | 60% |
| Tile 2 | 95% | ~55% |
| Tile 3 | 85% | ~45% |
| Tile 4 | 60% | ~30% |
| Tile 5 | 40% | ~20% |
| Tile 6 | 15% | ~8% |
| Tile 7 | 5% | ~2% |
| Tile 8 | 1% | ~0% |

**Zonas laterais do cone:**
- Tiles laterais próximos têm probabilidades menores (40%, 15%, 5%) — passar do lado do guarda tem risco, só que menor.
- Borda do cone tem falloff suave, não corte abrupto.

### 5.2 Estado do Cone por OpState do Guarda
- **Relaxado / Patrulhando:** cone reduzido (tabela "estado relaxado" acima). Skills e acessórios podem reduzir mais.
- **Tenso / Alerta:** cone normal (tabela "probabilidade base").
- **Procurando / Perseguindo:** probabilidades triplicam. Cone pode expandir para omnidirecional.
- **Omnidirecional:** guarda parado em alerta máximo, percebendo o ambiente em todas as direções. Distribuição em diamante simétrico. Nenhum "lado seguro".

### 5.3 Sistema de Sombras — Multiplicador de Tile
- Paredes projetam sombras geometricamente baseadas nas fontes de luz do ambiente.
- Cada tile tem um **estado de iluminação** que modifica as probabilidades do cone:

| Visual do tile | Estado | Efeito nas probabilidades |
|---|---|---|
| Tile escuro (sombra profunda) | Cobertura total | Probabilidades ÷ 2 |
| Tile meio-sombra | Cobertura parcial | Probabilidades × 0.75 |
| Tile iluminado normal | Sem cobertura | Probabilidades normais |
| Tile super iluminado | Exposto | Probabilidades × 1.5 |

- Pelo menos **1/4 de cada sala** tem trilha de sombra garantida (paredes externas sempre bloqueiam alguma luz).
- Isso garante que sempre existe um caminho furtivo, mesmo na sala mais difícil.
- O tile mais escuro visualmente é o tile mais seguro mecanicamente — ensinável por instinto.

### 5.4 Fontes de Luz como Design de Nível
- A posição das luzes define as zonas de sombra — **a luz é design de nível**.
- **Luzes manipuláveis pelo agente:**
  - Apagar lâmpada (1 AP, faz barulho) — sombra permanente naquele segmento
  - Hackear painel elétrico — desliga sala inteira, pode acionar alarme
  - Lançar objeto na lâmpada (gadget) — silencioso mas usa item
- **Luzes dinâmicas:**
  - Holofote rotativo — sombra se move, cria janela de passagem calculável
  - Luz piscante de emergência — risco alterna por turno
  - Luz vermelha de alarme — elimina todas as sombras protetoras da sala

### 5.5 Medidor de Detecção Acumulativa
- Detecção acumula ao longo dos turnos — não é binária.
- **Decaimento:** quando o agente sai do cone, a detecção decai por turno. Taxa de decaimento varia por estado do guarda (relaxado decai rápido, perseguindo decai quase nada).
- **Ao atingir 100%:** agente descoberto. Fase de confronto inicia.
- A curva de acúmulo usa uma **forma sigmoide** — nos primeiros 40% é difícil ser detectado, de 40–70% sobe rápido, acima de 70% qualquer visão adicional fecha rapidamente. Cria a sensação de "escapei por pouco".

---

## 6. SISTEMA DE BARULHO

### 6.1 Geração de Barulho por Tic
- A cada tic (cruzamento de aresta), o agente tem chance de gerar barulho.
- Resultados possíveis: **silêncio / barulho pequeno / barulho médio / barulho alto**.
- Chance e intensidade dependem do terreno do tile de destino e das ações do agente.
- **Agente parado:** 0% de barulho.
- **Agente andando:** chance baixa, amplitude de 1 tile.
- **Agente correndo (2 tiles em 1 AP):** chance alta, amplitude de 2 tiles.
- Dentro da zona de 1 AP de um guarda: chance dobra.

### 6.2 Ícones de Barulho no Mapa
- Cada barulho gerado deixa um **ícone visual no tile anterior** onde foi produzido.
- O jogador vê quantos barulhos fez numa jogada — log visual de erros acumulando.
- A intensidade do ícone **degrada por turno** — barulho de 3 turnos atrás é evidência mais fraca.
- Guardas que passam pelo tile depois podem notar a evidência.

### 6.3 Propagação Sonora
- Som usa o **mesmo sistema de propagação** que o apito dos guardas e o alarme.
- Paredes atenuam o som — amplitude cai 1 por parede cruzada.
- Guardas dentro do raio ouvem e reagem conforme seu estado atual.

---

## 7. SISTEMA DE RASTRO E PREVISÃO

### 7.1 Rastro do Agente (Amarelo)
- Mostra os últimos N tiles percorridos pelo agente.
- Opacidade decrescente: tile mais recente = 100%, diminui 20% por tile.
- **Inimigos comuns NÃO veem o rastro** — seria difícil demais muito rápido.
- **Inimigos elite** veem o rastro e podem predizer a rota.

### 7.2 Previsão de Rota dos Guardas (Azul)
- Mostra os próximos N tiles que o guarda vai percorrer.
- Opacidade decrescente: próximo passo = 100%, diminui 20% por tile.
- Disponível para o agente conforme progressão de nível.

### 7.3 Previsão do Inimigo Elite — Inversão da Sombra
- O inimigo elite não só vê o rastro — ele **prediz a rota pelas zonas de sombra**.
- Sua previsão de rota aponta para onde as sombras levam, não para onde o agente está.
- O rastro de previsão dele vai para as zonas escuras — forçando o agente a ficar em zonas iluminadas e se arriscar mais.
- Cria dilema genuíno: sombra é refúgio contra guardas comuns, mas armadilha contra o elite.

### 7.4 Progressão de Informação Visual por Nível
| Nível do agente | Informação disponível |
|---|---|
| Recruta | Só o mapa. Nenhum overlay. Aprende na dor. |
| Operativo | Cone de detecção dos guardas visível (cores). |
| Agente | Rastro amarelo dos últimos 3 tiles visível para o jogador. |
| Especialista | Previsão azul dos próximos 3 tiles dos guardas. |
| Veterano | Rastro completo (5 tiles) + previsão completa (5 tiles). |
| Elite | Tudo acima + indicador de qual guarda age a seguir no painel. |

A UI é a recompensa de progressão. O mapa continua igualmente perigoso — o agente só passa a entender melhor o que sempre aconteceu.

---

## 8. SISTEMA DE CONFRONTO

### 8.1 Transição Stealth → Confronto
- Quando detecção atinge 100%, câmera faz close no rosto do guarda, pausa dramática, música muda.
- Transição é um momento claramente marcado — o jogador sabe que o jogo mudou.
- Bomba de fumaça pode reverter para stealth se usada corretamente (ver seção 8.5).

### 8.2 Os 4 Estados de Cobertura
| Estado | Visual | Acerto recebido | Dano recebido | Aim próprio |
|---|---|---|---|---|
| **Sem cobertura** | Em pé, exposto | 100% | 100% | 100% |
| **Minimal cover** | Deitado no chão | 70% | 70% | 50% |
| **Half cover** | Agachado, objeto baixo | 50% | 50% | 75% |
| **Full cover** | Atrás de parede/pilar | 25% | 25% | 100% |

**Regras de transição entre estados:**
- Mudar para cobertura melhor: custa 1 AP, fica brevemente exposto durante o deslocamento.
- Entrar em minimal cover: gratuito, mas não pode fazer mais nada além de atirar (50% aim) nesse turno.
- Sair de minimal cover: custa 1 AP. Levantar é lento — te prende por pelo menos 1 turno.

### 8.3 O Peek (Full Cover)
- Em full cover, atirar requer "sair" momentaneamente da cobertura.
- Durante o peek: acerto recebido sobe para ~60%, mas aim é 100%.
- Guardas em overwatch podem esperar o peek antes de atirar — duelo de paciência.

### 8.4 Flanqueamento
- Flanqueamento total (inimigo perpendicular à cobertura): degrada a cobertura um nível.
- Flanqueamento parcial (diagonal): reduz o multiplicador de proteção em 15%.
- Minimal cover é imune ao flanqueamento — deitado, não há "lado fraco". Mas mudar direção de aim custa 1 AP.
- Corpo de guarda caído pode ser usado como minimal cover — taticamente útil, narrativamente coerente.

### 8.5 Bomba de Fumaça como Pivô
- Quando usada em confronto, não só cobre visualmente — **reseta parcialmente** o estado de detecção.
- Guardas perdem posição confirmada do agente, voltam para "procurando" com último tile onde a fumaça caiu.
- Janela de 2–3 turnos para reposicionar.
- Permite escorregar de volta para o stealth se o jogador jogar bem.

### 8.6 Resolução de Combate por Tic
```
Tic de ataque:
  1. Dado de acerto: chance base - cobertura do alvo + precisão do atacante
  2. Se acerto: dado de dano (range por arma/skill)
  3. Dano resolve contra as camadas de resistência do alvo
  4. Se erro: feedback visual (bala no chão, faísca na parede)
```

---

## 9. SISTEMA DE RESISTÊNCIA DO AGENTE

### 9.1 As 3 Camadas
```
CAMADA 1 — HP (Vida)
  Início: 3 HP
  Máximo na campanha: até 5 HP
  No modo Freelance: escala proporcionalmente com o tier de dificuldade

CAMADA 2 — Armadura
  Absorve dano antes da vida
  Início: 0 (sem armadura)
  Degrada com uso — cada acerto reduz 1 ponto de armadura
  Máximo na campanha: 3 pontos
  No modo Freelance: escala com equipamento de tier mais alto

CAMADA 3 — [Reservado para desenvolvimento futuro]
  Espaço para mecânica adicional de late game
  Máximo: 1 ponto na campanha
```

### 9.2 O Teto de 9 e a Regra do Décimo Tiro
- Soma máxima de todas as camadas na campanha: **9 pontos**.
- O **décimo acerto é sempre fatal**, independente das probabilidades e camadas.
- Pula armadura, pula qualquer proteção, dano = crítico mortal.
- Tratamento visual especial — câmera lenta, som diferente, animação de morte distinta.
- Cria mecânica de "conta os tiros" — agente muito danificado é lido visualmente.

**A regra do décimo tiro no modo Freelance:**
O número absoluto de HP/armadura pode crescer com o tier, mas a **proporção se mantém**.
Se no tier 5 o agente aguenta 27 acertos, o 28º ainda é sempre fatal.
O décimo tiro é uma metáfora, não um número fixo — é sempre *um acerto além do limite*.
Isso garante que veteranos com muito poder ainda sintam a tensão do stealth.
A mecânica existe para desencorajar combate aberto: atirar em todo mundo eventualmente mata,
independente de quanto HP o agente tenha acumulado.

### 9.3 Distribuição Máxima de Pontos
| Camada | Máximo | Fonte |
|---|---|---|
| HP base | 5 | Upgrades de resistência |
| Armadura | 3 | Equipamento, Classe 1 |
| Reservado | 1 | Desenvolvimento futuro |
| **Total** | **9** | — |

### 9.4 Dado de Dano
| Resultado | Dano | Descrição |
|---|---|---|
| Baixo | 1 ponto | Ferimento leve, raspou |
| Médio | 2 pontos | Acerto direto |
| Alto | 3 pontos | Crítico normal |
| Décimo tiro | Fatal | Ignora tudo |

---

## 10. SISTEMA DE EQUIPAMENTO — 3 CLASSES

### 10.1 Filosofia de Equipamento
- O agente escolhe **um item de cada classe** antes de cada missão.
- Gadgets são **consumíveis** encontrados no mapa, comprados de NPCs, ou recompensados por missão. Máximo 2 por missão.
- Três decisões de loadout. Simples de ensinar, profundo para dominar.

### 10.2 Classe 1 — Armadura / Proteção
Progressão narrativa: espião discreto → ameaça blindada.
Proteção maior sempre tem custo de mobilidade ou furtividade.

| Tier | Nome | HP bônus | Armadura | Penalidade furtiva |
|---|---|---|---|---|
| 1 | Roupa civil | 0 | 0 | Disfarce perfeito |
| 2 | Roupa tática | 0 | 1 | Leve ruído ao correr |
| 3 | Colete balístico | 1 | 2 | Cone de barulho +1 |
| 4 | Armadura modular | 2 | 3 | Movimento +0.5 AP |
| 5 | Exoesqueleto leve | 3 | 3 | Nenhuma (motorizado) |
| 6 | Blindagem completa | 3 | 4 | Minimal cover impossível |
| 7 | Pele adaptativa | 2 | 2 | Multiplicador de sombra ×2 |

### 10.3 Classe 2 — Ataque / Arma
Progressão tecnológica espelha a narrativa.

| Tier | Arma | Dano | Barulho | Alcance |
|---|---|---|---|---|
| 1 | Punho / soco | 1 | Nenhum | Adjacente |
| 1 | Faca | 2 | Mínimo | Adjacente |
| 2 | Pistola silenciada | 1–2 | Baixo | 6 tiles |
| 2 | Arma de choque | Atordoa 2 turnos | Baixo | Adjacente |
| 3 | Rifle silenciado | 2–3 | Médio | 12 tiles |
| 3 | Lançador de dardos | Nocaute (sedativo) | Nenhum | 6 tiles |
| 4 | Arma laser | 3–4 | Alto | 15 tiles |
| 5 | Arma plasma | 4–5 | Alto | 10 tiles |
| 6 | Arma sônica | Atordoa área 3×3 | Muito alto | 5 tiles |

### 10.4 Classe 3 — Visor
Cada visor muda fundamentalmente como o jogador lê o mapa.

| Tier | Visor | O que revela | Limitação |
|---|---|---|---|
| 1 | Visão normal | Cone de visão padrão | Sem overlay |
| 2 | Visão noturna | Vê em tiles escuros | Ofusca em tiles iluminados |
| 2 | Binóculo tático | Cone dos guardas a distância | Estático |
| 3 | Visão de calor | Guardas através de paredes finas | Não distingue amigo/inimigo |
| 3 | Visão de movimento | Qualquer ator que se moveu no turno anterior | Não vê estáticos |
| 4 | Visão de raio X | Vê através de paredes e objetos | Bateria — 3 turnos por carga |
| 4 | Visão WiFi | Eletrônicos — câmeras, sensores, rádios | Só eletrônicos |
| 5 | Visor de análise tática | Probabilidade de detecção de cada tile | Só funciona parado |
| 5 | Visor preditivo | Previsão de rota dos guardas | Impreciso com elite |
| 6 | Visor espectral | Calor + raio X + WiFi + análise combinados | Pesado, +barulho |

### 10.5 Gadgets (Consumíveis)
Máximo 2 equipados por missão. Encontrados no mapa, comprados, ou recompensados.

| Tier | Gadget | Efeito | Usos |
|---|---|---|---|
| 1 | Detector de movimento | Mostra movimento em tile adjacente não visível | Passivo |
| 1 | Detector de ruído | Mostra intensidade de barulho ao redor | Passivo |
| 2 | Bomba de fumaça | Bloqueia LOS 3×3, 3 turnos | 3 |
| 2 | Flashbang | Atordoa visão na área por 1 turno | 2 |
| 2 | Bomba de gás | Nocauteia quem respirar por 2 turnos | 2 |
| 3 | Bomba EMP | Desativa eletrônicos na sala por 3 turnos | 2 |
| 3 | Bomba incendiária | Tile intransitável por 4 turnos | 2 |
| 3 | Bomba explosiva | Dano em área, destrói cobertura | 1 |
| 4 | Drone de reconhecimento | Voa 5 tiles revelando área | 1 por missão |
| 4 | Isca sonora | Cria barulho num tile à distância | 3 |
| 5 | Loop de câmera | Câmera mostra imagem falsa por 3 turnos | 2 |
| 5 | Scrambler de rádio | Bloqueia comunicação numa sala | 1 por missão |
| 6 | Gerador de sombra | Cria tile de sombra artificial por 3 turnos | 2 |

---

## 11. SISTEMA DE INIMIGOS

### 11.1 As 3 Facções Inimigas

**Facção 1 — A Agência**
Filosofia: controle via informação.
- Guardas com rádio e protocolos de check-in
- Câmeras com IA, sensores de movimento
- Tenentes que leem rastros e predizem rotas
- Jammers que embaralham leituras de visor
- Contrapoder natural: visor do agente

**Facção 2 — A Milícia**
Filosofia: força bruta e presença intimidadora.
- Guardas com armadura pesada, HP alto
- Patrulhas sempre em par — nunca sozinhos
- Pouca tecnologia, mas excelente cobertura e posicionamento
- Especialistas em flanqueamento coordenado
- Contrapoder natural: ataque do agente

**Facção 3 — A Corporação**
Filosofia: eficiência tecnológica e sistemas automatizados.
- Drones autônomos, lasers, câmeras com padrões fixos
- Comportamento previsível mas recuperação rápida
- Vulneráveis a EMP e hacking
- Armas de precisão que ignoram armadura
- Contrapoder natural: armadura do agente

### 11.2 Hierarquia de Guardas
```
RECRUTA
  Cone básico, audição normal, sem rádio.
  Ameaça: agente descuidado.

GUARDA PADRÃO
  Cone normal, rota de patrulha, apito.
  Ameaça: agente que subestima o cone lateral.

GUARDA VETERANO
  Cone ampliado, varredura periférica, detecta rastro parcialmente.
  Ameaça: agente que repete rotas previsíveis.

TENENTE
  Rádio (comunica posição exata a todos), lê rastro completo,
  prediz rota pelas sombras, protocolo de check-in.
  Ameaça: agente que não neutraliza comunicação primeiro.

CAPITÃO
  Todos os poderes do tenente + imune à fumaça,
  reconhece disfarce, coordena posicionamento dos subordinados,
  muda rotas quando suspeita.
  Ameaça: agente que depende de um único truque.

AGENTE RIVAL (boss)
  Espelho completo do agente jogador.
  Usa gadgets, muda de cobertura, foge e reagrupa.
  Tem HP, armadura, se cura entre encontros.
  Ameaça: agente que não adapta a estratégia.
```

### 11.3 As 5 Técnicas de Ponto e Contraponto
Inspiradas em Phoenix Point — cada poder do agente tem um espelho inimigo:

| # | Poder do Agente | Contrapoder do Inimigo | Quem introduz |
|---|---|---|---|
| 1 | Visão de calor | Roupa de isolamento térmico | A Agência, cap. 3 |
| 2 | Pistola com suppressor | Detector de supressor | A Milícia, cap. 2 |
| 3 | Dardo sedativo | Antídoto injetável / respirador | A Corporação, cap. 4 |
| 4 | Scrambler de rádio | Frequência alternativa / comunicação analógica | A Agência + Milícia |
| 5 | Full cover | Flanqueamento coordenado por dois guardas | A Milícia |

### 11.4 Escada de Poder por Capítulo
| Capítulo | Agente desbloqueia | Inimigos respondem com |
|---|---|---|
| 1 | Faca, visão normal | Recrutas sem rádio, cone básico |
| 2 | Pistola silenciada, fumaça | Detector de suppressor, máscara anti-fumaça |
| 3 | Visão noturna, arma de choque | Flash ao detectar, escudo de borracha |
| 4 | Rastro visível, previsão de rota | Tenente com rádio, leitura de rastro |
| 5 | Visão de calor, drone | Roupa térmica, scrambler anti-drone |
| 6 | Arma laser, loop de câmera | Escudo refletor, câmera com IA |

### 11.5 Telegrafamento de Novos Inimigos
```
Capítulo N:   Agente desbloqueia bomba de fumaça
Capítulo N+1: Guardas com MÁSCARA visível no sprite aparecem (jogador vê, não enfrenta)
Capítulo N+2: Primeiro confronto com guarda mascarado (jogador já sabe o que é)
```
Dificuldade justa, não frustrante. O jogador nunca é pego de surpresa por um mecânica desconhecida.

---

## 12. SISTEMAS DE COMUNICAÇÃO INIMIGA

### 12.1 Apito (Local)
- Alcance: 2 AP equivalente em tiles, com atenuação por paredes.
- Guard que ouve recebe conhecimento da posição aproximada do agente.
- Cooldown de 2 turnos por guarda.
- Visual: onda sonora direcional apontando para o agente.

### 12.2 Rádio (Global — apenas Tenente+)
- Transmite posição exata do agente para todos os guardas com rádio, sem limite de distância.
- Rádio emite ruído audível antes de transmitir — o agente tem 1 turno para reagir.
- Cooldown de 3 turnos.
- Check-in automático a cada 5 turnos — guarda que não responde é investigado.

### 12.3 Alarme de Parede
- Painéis de alarme são objetos interagíveis na cena.
- Guarda em fuga pathing para o alarme mais próximo.
- Ativar o alarme custa 1 turno completo (1 AP de movimento + 1 AP de ação).
- Agente pode interceptar nocauteando o guarda antes da ação resolver.
- Quando ativado: todos os guardas da cena sobem para estado de alerta máximo.
- Agente pode desabilitar painéis antes do alarme ser acionado (1 AP adjacente ao painel).

---

## 13. ESTRUTURA DE MAPA E PROGRESSÃO

### 13.1 Estrutura de Segmento (Locked)
- Mapa: grid 3×3 de segmentos de 18×36 tiles cada.
- Interior jogável: 7×25 tiles por segmento.
- Pontos de acesso: 1 principal + 1 secundário (bloqueado) + 1 secreto por borda ativa.
- Reset completo de AP ao entrar num novo segmento.
- Zona segura de 2 tiles na borda de entrada (garantidamente sem encontros).

### 13.2 Estrutura de Missão
- Cada missão é um **floor** com entrada, objetivos, e saída.
- Cada sala tem pelo menos um elemento: encontro inimigo, puzzle stealth, objetivo, cache de recompensa, restrição de travessia, ou evento narrativo.
- Objetivos possíveis: alcançar terminal, neutralizar guarda, passar sem detecção, recuperar item, escoltar/resgatar, sabotar sistema, sobreviver emboscada.

### 13.3 MVP — 3 Capítulos Focados
```
CAPÍTULO 1 — A Agência (sede corporativa)
  Agente: roupa civil, faca, visão normal, 1 gadget
  Inimigos: recruta, guarda com rádio, câmera simples
  Mecânica introduzida: cone de visão + sombras
  Objetivo de aprendizado: entender detecção

CAPÍTULO 2 — A Milícia (instalação industrial)
  Agente: colete leve, pistola silenciada, binóculo, 2 gadgets
  Inimigos: guarda com armadura, patrulha em par, tenente
  Mecânica introduzida: barulho + cobertura
  Objetivo de aprendizado: silêncio tem custo, confronto tem regras

CAPÍTULO 3 — A Corporação (laboratório)
  Agente: armadura modular, arma de choque, visão noturna, 2 gadgets
  Inimigos: drone, câmera com IA, guarda high-tech
  Mecânica introduzida: eletrônicos + sistemas automatizados
  Objetivo de aprendizado: nenhuma solução é universal
```

---

## 14. SISTEMAS DE PROGRESSÃO

### 14.1 Fonte de Itens
- Encontrados em cofres/chests no mapa
- Comprados de NPCs
- Recompensados por completar missões
- [Futuro] Mercado entre jogadores estilo TF2

### 14.2 O Informante — NPC Garantido
- Cada mapa pode conter um Informante: contato da Rede embutido no local.
- Alcançar o tile do Informante (1 AP) antes de ser detectado: escolha de 1 intel:
  - Posição exata do objetivo primário
  - Rota de patrulha de um guarda específico (overlay por 5 turnos)
  - Localização da passagem secreta mais próxima

### 14.3 Desafios Impossíveis para Iniciantes
- Algumas salas são visualmente acessíveis mas mecanicamente impossíveis sem skills específicas.
- Um guarda com rádio numa sala sem cobertura nenhuma é impossível sem interferência de sinal.
- O mapa mostra essas salas claramente, tentando o jogador, punindo quem entrar sem preparo.
- Veteranos reconhecem e contornam; iniciantes aprendem pela dor.

### 14.4 Escalada Infinita — Modo Freelance (Ciclo Diablo)
Após a campanha, o jogo entra em ciclos de dificuldade crescente — similar aos tormentos do Diablo ou às waves do XCOM em Ironman. A cada ciclo:

```
CICLO DE ESCALADA:
  → Inimigos ganham +X% de HP, dano e detecção
  → Agente pode equipar itens de tier mais alto
  → Novos tipos de inimigo são introduzidos
  → Mapas gerados são maiores e mais complexos
  → Missões contrato com recompensas maiores ficam disponíveis
  → A regra do décimo tiro se mantém — proporcional ao novo teto
```

**Premissas de arquitetura para suportar escalada infinita:**
- Stats de inimigos e agente devem ser **data-driven**, não hardcoded.
- Cada entidade carrega um `difficulty_tier: int` que multiplica suas stats base.
- O gerador de missão recebe o tier atual e produz encontros proporcionais.
- Nenhum sistema de jogo deve assumir valores máximos fixos de HP, dano, ou alcance.

```gdscript
# Correto — suporta escalada infinita:
var actual_hp = base_hp * difficulty_tier_multiplier

# Errado — cria teto artificial:
const MAX_HP = 9
```

### 14.5 Gerador de Missões com LLM (Futuro)
Quando implementado, o gerador vai produzir missões completas sob demanda:
- Contexto narrativo coerente com o lore e o histórico do agente
- NPCs com personalidade, motivação e diálogos situacionais
- Objetivos primários e secundários únicos e balanceados por tier
- Recompensas proporcionais ao risco e à dificuldade
- Segredos e easter eggs embutidos organicamente no mapa

**Requisito de arquitetura — separação estrutura/conteúdo:**
A lógica do jogo não pode depender do conteúdo narrativo para funcionar.
`MissionData` (estrutura) e `MissionNarrative` (conteúdo LLM) são objetos separados.
O jogo funciona completamente sem `MissionNarrative` — é apenas enriquecimento.

---

## 15. MONETIZAÇÃO

| Tipo | Implementação |
|---|---|
| Ads pré-nível | Intersticial pulável após 5s |
| Ads pós-nível | Intersticial ou recompensado (2x XP/coins) |
| Continue | Rewarded video em falha de missão |
| Restock gadgets | Rewarded video entre missões |
| Cosméticos | Skins de agente, temas de tile, animações de takedown — nunca pay-to-win |
| Ad-free pass | [Futuro] Compra única remove intersticiais |
| Pacotes de conteúdo | [Futuro] DLC de missões, facções e equipamentos extras |
| Passes de temporada | [Futuro] Conteúdo sazonal com missões temáticas e recompensas exclusivas |
| Mercado de itens | [Futuro] Troca entre jogadores estilo TF2 |

**Nota sobre o modelo infinito:**
O jogo sem fim cria naturalmente um modelo de receita de longo prazo.
Jogadores que chegam ao modo Freelance são jogadores retidos — o valor deles cresce com o tempo.
Pacotes de conteúdo e passes de temporada funcionam melhor com uma base de jogadores veteranos
do que com um jogo que termina em 6 horas.

---

## 16. DIREÇÃO DE ARTE

### 16.1 Fase Atual (Placeholder)
- Todas as entidades são shapes coloridos no grid.
- Agente: diamante verde. Guarda: diamante vermelho. Câmera: triângulo laranja.

### 16.2 Fase Final (Pre-rendered 3D)
- Assets modelados em Blender e renderizados como sprite sheets 2D.
- Sprites direcionais (N/S/E/W) e frames de animação (idle, walk, action).
- Swap puramente visual — lógica de TileMap e jogo não muda.

### 16.3 Paleta e Linguagem Visual
- Fundos escuros e contidos (concreto, aço) com cores de alta contrast para o agente e ameaças.
- Câmera isométrica 2.5D, projeção dimétrica (45° horizontal / 26.57° elevação), portrait.
- UI mínima: medidor de alerta (topo), AP indicator (topo), menu contextual (tap), painel de retratos (lateral).

---

## 17. ESTADO TÉCNICO ATUAL (Junho 2026)

### 17.1 O que está implementado e funcional
- Room builder com autotile de paredes (straights, corners, door slots)
- Segmento 18×36 com floor, bordas, inner walls, props
- Tile picking alinhado ao centro visual com diamond hit-testing
- Movimento escalonado com Dijkstra, eventos step_finished
- Overlay de range de movimento, path preview, confirmação two-tap, bands de AP
- FOW progressivo (3 camadas: shader de distância, polígonos, camera leash)
- Y-sorting em room root e todos os TileMapLayers
- Calibração de origem de todos os 88+ assets direcionais
- GuardEnemy placeholder com cone de visão, patrulha e FSM básico (patrol/suspicious/alert/chase)
- EnemyPhaseController sequencial
- TurnManager com fases explícitas
- Perspectiva switching runtime (N/E/S/W) com rotação de layout

### 17.2 O que precisa ser implementado (próximas fases)
- **M1.5 pendente:** portas (visual + lógica), transição entre segmentos, sprite do agente, menu de ação contextual
- **M2:** sistema de detecção por tics (substituir avaliação atual), sistema de barulho, LOS por edge walls, FSM completo dos guardas
- **M3:** gerador procedural de floors, templates de sala
- **M4:** vertical slice completo

### 17.3 Refatorações necessárias antes do M2
- Cone de visão: trocar projeção de eixo retangular por angular (FOV em graus)
- Pathfinding: `_step_toward()` greedy → A* real
- Modelo de tile: implementar wall_edges separado de blocked_cells
- Detecção: event-driven por aresta em vez de avaliação por turno

---

## 18. DECISÕES ABERTAS

Estas questões foram identificadas mas ainda não decididas:

- [ ] **Proteção psiônica:** reservada para desenvolvimento futuro. Não entra no MVP.
- [ ] **Mercado de itens entre jogadores:** reservado para desenvolvimento futuro.
- [ ] **Movimento diagonal:** bloqueado no início, possível unlock como skill de late game.
- [ ] **Multi-floor / elevação:** feature futura, não entra no MVP.
- [ ] **Custo exato de AP por tipo de terreno:** requer playtesting.
- [ ] **Cores do sistema de overlay:** 1 AP, 2 AP, danger, interagível, quest — definir paleta.
- [ ] **Armas usam munição, cooldown, ou só barulho?:** a decidir.
- [ ] **Gerador LLM de missões:** arquitetura separada de estrutura/conteúdo está definida. Integração futura.
- [ ] **Sessões de combate: o agente morre num tiro ou tem HP?** → **DECIDIDO: 3 HP base, teto proporcional por tier, décimo tiro (relativo ao teto) sempre fatal.**
- [ ] **Geração procedural: fixa por capítulo ou adaptativa?** → **DECIDIDO: fixa por capítulo na campanha + ciclos de escalada no modo Freelance.**
- [ ] **Itens: encontrados ou comprados?** → **DECIDIDO: ambos — chests, NPCs, recompensas de missão.**
- [ ] **O jogo tem fim?** → **DECIDIDO: não. Campanha de 3 capítulos é a pré-história. Modo Freelance é infinito.**

---

## 19. RESTRIÇÕES DE ARQUITETURA PARA JOGO INFINITO

Estas regras devem ser seguidas em todo o desenvolvimento para não criar bloqueios futuros:

```
REGRA 1 — Stats são sempre data-driven, nunca hardcoded
  → Todo valor numérico (HP, dano, alcance, detecção) vive em recursos ou dicionários
  → Nenhum const MAX_HP ou valor fixo em lógica de jogo
  → O sistema deve funcionar corretamente para qualquer tier de dificuldade

REGRA 2 — Estrutura e conteúdo narrativo são sempre separados
  → MissionData (estrutura) funciona sem MissionNarrative (conteúdo)
  → O engine nunca depende de texto para resolver lógica
  → Todo texto é substituível sem tocar em código de jogo

REGRA 3 — O gerador de missão recebe tier, produz encontros proporcionais
  → Nenhum encontro é hardcoded para um nível específico de stats
  → O mesmo template de mapa deve funcionar em tier 1 e tier 50

REGRA 4 — A regra do décimo tiro é proporcional, não absoluta
  → O limite fatal é sempre "teto atual + 1", não o número 10
  → O teto é calculado dinamicamente: sum(hp, armor, extras) + 1

REGRA 5 — Sistemas de comunicação inimiga são plugáveis
  → Apito, rádio, alarme são comportamentos independentes que guardas equipam
  → Adicionar novo tipo de comunicação não exige refatorar guardas existentes

REGRA 6 — O painel de retratos suporta número variável de atores
  → Nunca assumir quantidade fixa de guardas por missão
  → UI escala para 2 a 20+ atores sem quebrar
```

---

*Este documento é a consolidação das decisões de design da sessão de brainstorming de Junho 2026. Deve ser incorporado ao GAME_PLAN.md como fonte de verdade antes da geração dos prompts de implementação.*
