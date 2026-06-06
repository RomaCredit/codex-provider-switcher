#!/bin/sh
cd "$(dirname "$0")" || exit 1

while true; do
  echo
  echo "Codex Provider Switcher"
  echo "1. Switch to APIMaster and sync history"
  echo "2. Switch to official subscription and sync history"
  echo "3. Show status"
  echo "4. Test APIMaster /v1/models"
  echo "5. Save current profile as official"
  echo "6. Repair Desktop history list"
  echo "0. Exit"
  echo
  printf "Choose: "
  read choice

  case "$choice" in
    1) python3 ./codex_provider_switcher.py apimaster --lang en ;;
    2) python3 ./codex_provider_switcher.py official --lang en ;;
    3) python3 ./codex_provider_switcher.py status --lang en ;;
    4) python3 ./codex_provider_switcher.py test --lang en ;;
    5) python3 ./codex_provider_switcher.py save-official --lang en ;;
    6) python3 ./codex_provider_switcher.py repair-history --lang en ;;
    0) exit 0 ;;
  esac
done
