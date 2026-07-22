#!/bin/bash
# ANDROID_CONFIG — Atalho para buildar e instalar no Android

SDK_PATH="/opt/homebrew/share/android-commandlinetools"
ADB="${SDK_PATH}/platform-tools/adb"
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
APK="${PROJECT_ROOT}/export/infiltraitor.apk"

echo "=== INFILTRAITOR Android Build & Install ==="
echo ""
echo "Opções:"
echo "  1. Build (export o APK)"
echo "  2. Install (instala no celular via USB)"
echo "  3. Build + Install (ambos)"
echo "  4. Sair"
echo ""

read -p "Escolha (1-4): " choice

case $choice in
  1)
    echo "Buildando APK..."
    mkdir -p "${PROJECT_ROOT}/export"
    "$GODOT" --export-release Android "$APK" 2>&1 | tail -20
    if [ -f "$APK" ]; then
      echo "✅ APK pronto: $APK"
      ls -lh "$APK"
    else
      echo "❌ Build falhou"
      exit 1
    fi
    ;;
  2)
    if [ ! -f "$APK" ]; then
      echo "❌ APK não encontrado: $APK"
      echo "   Rode 'Build' primeiro"
      exit 1
    fi
    echo "Instalando no celular..."
    "$ADB" install "$APK"
    echo "✅ Pronto! Abra o app no seu Android."
    ;;
  3)
    echo "Buildando..."
    mkdir -p "${PROJECT_ROOT}/export"
    "$GODOT" --export-release Android "$APK" 2>&1 | tail -20
    if [ -f "$APK" ]; then
      echo "✅ Build completo"
      echo ""
      echo "Instalando no celular..."
      "$ADB" install "$APK"
      echo "✅ Pronto! Abra o app no seu Android."
    else
      echo "❌ Build falhou"
      exit 1
    fi
    ;;
  4)
    echo "Saindo..."
    exit 0
    ;;
  *)
    echo "Opção inválida"
    exit 1
    ;;
esac
