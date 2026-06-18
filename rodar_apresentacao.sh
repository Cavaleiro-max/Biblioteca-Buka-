#!/bin/bash
# ============================================================
# rodar_apresentacao.sh
# Script para rodar o Buka+ no browser SEM bloqueio de CORS
# Usar na apresentação do TCC quando não há Android Studio
# ============================================================

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   BUKA+ — Modo Apresentação TCC      ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Passo 1: Compilar o app Flutter para Web
echo "▶ A compilar o app para Web..."
flutter build web --release

if [ $? -ne 0 ]; then
  echo "❌ Erro na compilação. Verifique os erros acima."
  exit 1
fi

echo "✅ Compilação concluída!"
echo ""

# Passo 2: Abrir o Chrome SEM segurança CORS
# Isto é APENAS para testes e apresentações locais
echo "▶ A abrir o Chrome sem restrições CORS..."
echo "   (APENAS para apresentação — nunca usar assim no dia-a-dia)"
echo ""

# Detectar sistema operativo
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # Linux (Ubuntu, etc.)
  # Criar perfil temporário para não afectar o Chrome normal
  mkdir -p /tmp/chrome_buka_tcc
  
  google-chrome \
    --disable-web-security \
    --user-data-dir="/tmp/chrome_buka_tcc" \
    --allow-running-insecure-content \
    --no-first-run \
    --app="http://localhost:8080" \
    &

elif [[ "$OSTYPE" == "darwin"* ]]; then
  # Mac
  mkdir -p /tmp/chrome_buka_tcc
  
  open -a "Google Chrome" \
    --args \
    --disable-web-security \
    --user-data-dir="/tmp/chrome_buka_tcc" \
    --allow-running-insecure-content \
    --app="http://localhost:8080"
fi

# Passo 3: Servir o app compilado
echo "▶ A iniciar servidor local na porta 8080..."
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  App disponível em: http://localhost:8080 ║"
echo "║  Pressione Ctrl+C para parar              ║"
echo "╚══════════════════════════════════════════╝"
echo ""

cd build/web && python3 -m http.server 8080
