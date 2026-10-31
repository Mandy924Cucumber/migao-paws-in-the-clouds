#!/bin/zsh
set -e
game_dir="${0:A:h}"
for godot_binary in "/Applications/Godot.app/Contents/MacOS/Godot" "$HOME/Downloads/Godot.app/Contents/MacOS/Godot"; do
  if [[ -x "$godot_binary" ]]; then
    exec "$godot_binary" --path "$game_dir"
  fi
done
if command -v godot >/dev/null 2>&1; then
  exec godot --path "$game_dir"
fi
print '请先安装 Godot 4.3 或更新版本，然后在 Godot 中导入本目录的 project.godot，按 F5 运行。'
read '?按回车退出。'
