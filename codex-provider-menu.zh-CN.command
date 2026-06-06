#!/bin/sh
cd "$(dirname "$0")" || exit 1

while true; do
  echo
  echo "Codex Provider 切换器"
  echo "1. 切换到 APIMaster 并同步历史"
  echo "2. 切换到官方订阅并同步历史"
  echo "3. 查看状态"
  echo "4. 测试 APIMaster /v1/models"
  echo "5. 保存当前配置为官方配置"
  echo "6. 修复 Desktop 历史列表"
  echo "0. 退出"
  echo
  printf "请选择: "
  read choice

  case "$choice" in
    1) python3 ./codex_provider_switcher.py apimaster --lang zh ;;
    2) python3 ./codex_provider_switcher.py official --lang zh ;;
    3) python3 ./codex_provider_switcher.py status --lang zh ;;
    4) python3 ./codex_provider_switcher.py test --lang zh ;;
    5) python3 ./codex_provider_switcher.py save-official --lang zh ;;
    6) python3 ./codex_provider_switcher.py repair-history --lang zh ;;
    0) exit 0 ;;
  esac
done
