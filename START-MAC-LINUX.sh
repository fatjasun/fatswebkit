#!/usr/bin/env sh
# Same job as START-WINDOWS.bat: find this script's folder, check the pieces are
# there, and run the server from the web directory.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
PORT=${1:-8001}

if [ ! -f "$HERE/web/serve.py" ]; then
  echo
  echo "  This file must stay next to the 'web' folder."
  echo "  Extract the whole zip first, then run this from inside it."
  echo
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo
  echo "  python3 was not found."
  echo "  macOS:  brew install python3     (or python.org/downloads)"
  echo "  Linux:  sudo apt install python3"
  echo
  exit 1
fi

cd "$HERE/web" || exit 1
exec python3 serve.py "$PORT"
