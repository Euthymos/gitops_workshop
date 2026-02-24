#!/usr/bin/env bash
set -euo pipefail

echo "[check] Overujem prerekvizity..."

fail=0

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "  [ok] $cmd nájdený: $(command -v "$cmd")"
  else
    echo "  [CHYBA] $cmd nenájdený – nainštaluj ho pred pokračovaním"
    fail=1
  fi
}

check_cmd oc
check_cmd kubectl
check_cmd tkn
check_cmd helm
check_cmd git
check_cmd curl
check_cmd jq

if [[ $fail -eq 1 ]]; then
  echo ""
  echo "[CHYBA] Niektoré prerekvizity chýbajú. Nainštaluj ich a spusti znovu."
  exit 1
fi

echo ""
echo "[check] Overujem pripojenie na CRC klaster..."
if ! oc whoami >/dev/null 2>&1; then
  echo "[CHYBA] Nie si prihlásený na OCP klaster."
  echo "        Spusti: eval \$(crc oc-env) && oc login -u kubeadmin ..."
  exit 1
fi

echo "  [ok] Prihlásený ako: $(oc whoami)"
echo "  [ok] Klaster: $(oc whoami --show-server)"
echo ""
echo "[check] Všetky prerekvizity sú splnené."
