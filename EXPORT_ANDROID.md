# Export para Android — Guia Passo-a-Passo

**Status**: Java ✅ instalado (22.0.1), Android SDK ⚠️ pendente.

## Instalação (Uma única vez) — CONCLUÍDA ✅

### ✅ 1. Android SDK via Homebrew — FEITO

```bash
# Já instalado:
/opt/homebrew/share/android-commandlinetools
```

### ✅ 2. Componentes essenciais — FEITOS

```bash
✅ platforms;android-34 (Android 14)
✅ build-tools;35.0.0
✅ platform-tools (adb 37.0.0)
```

### 3. Configurar Godot — PRÓXIMO PASSO

Abra o Godot e vá a **Editor → Editor Settings**:

1. Na aba de busca, escreva `android`
2. Configure os três caminhos abaixo:
   - **Android SDK Path**: `/opt/homebrew/share/android-commandlinetools`
   - **Android NDK Path**: (deixe em branco)
   - **Java Executable**: `/usr/bin/java`

Salve (Ctrl+S ou Cmd+S).

Godot pode pedir para fazer download dos templates de export — autorize:
- **Editor → Manage Export Templates → Download and Install** (selecione a versão 4.6.x, ~300 MB)

Aguarde o download completar (~1–2 min).

### 4. Criar o preset Android — DEPOIS DOS TEMPLATES

Vá a **Project → Export**:

1. Clique em **"Add Preset"**
2. Selecione **Android**
3. **Deixe tudo padrão** — não mude nada
4. Clique **"Create & Edit"** (vai criar `export_presets.cfg` automaticamente)
5. Volte pra tela de export (botão voltar no topo)
6. Select o preset **Android** e clique **"Export Project"** → guarde em `export/infiltraitor.apk`

A primeira build levará ~3–5 minutos (Godot gera um keystore de debug automaticamente).

---

## Export (A cada nova versão)

### Opção A: Export com nome automático

```bash
cd "/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR"
/Applications/Godot.app/Contents/MacOS/Godot --export-release Android export/infiltraitor.apk 2>&1 | tail -20
```

### Opção B: Via Godot GUI

1. Abra o projeto
2. **Project → Export**
3. Selecione o preset **Android**
4. Clique **"Export Project"** (vai pedir o arquivo `.apk`)
5. Guarde em `export/infiltraitor.apk` ou onde preferir

O arquivo terá `~25–50 MB`.

---

## Instalar no celular

### Via cabo USB (mais rápido)

1. Conecte o Android ao Mac via USB
2. Ative **Modo de Desenvolvedor** no Android (Settings → About → Build Number, 7 taps)
3. Ative **USB Debugging** (Settings → Developer Options)
4. No Mac, rode:

```bash
cd "/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR"
/opt/homebrew/share/android-commandlinetools/platform-tools/adb install export/infiltraitor.apk
```

Espere "Success" no terminal.

### Sem cabo (via email/Drive/Telegram)

1. Mande o `.apk` para você mesmo
2. Baixe no celular
3. Abra com "Instalar"
4. Pode pedir permissão "Instalar apps desconhecidos" — autorize uma vez

---

## Dica: Atalho pro adb (opcional)

Se quiser usar `adb` direto no terminal sem o caminho completo:

```bash
ln -s /opt/homebrew/share/android-commandlinetools/platform-tools/adb /usr/local/bin/adb
```

Daí em diante:
```bash
adb install export/infiltraitor.apk
```

---

## Troubleshooting

**Godot diz "Android SDK not found"**
→ Certifique-se que o path em Editor Settings é EXATO:
```
/opt/homebrew/share/android-commandlinetools
```
(não `/opt/homebrew/share/android-commandlinetools/cmdline-tools/` ou variações)

**"Export failed: certificate error"**
→ Normal na primeira build. Godot auto-gera um keystore de debug — aprove e repita.

**APK não instala no Android**
→ Aparelho pode ter outra versão. Desinstale a antiga (`adb uninstall com.infiltraitor.game` ou pela Settings).

---

## Próximas builds

Depois que tudo tiver configurado uma vez, pra cada nova versão é só rodar:

```bash
cd "/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR"
/Applications/Godot.app/Contents/MacOS/Godot --export-release Android export/infiltraitor.apk
```

Será entregue em `export/infiltraitor.apk`. Copia pro celular, pronto.
