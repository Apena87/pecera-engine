set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get install -y -qq curl git xz-utils ca-certificates ripgrep >/dev/null
export HOME=/opt/pecera-hermes/home
mkdir -p "$HOME"
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- --skip-setup
export PATH="$HOME/.local/bin:$PATH"
HERMES_HOME=/tmp/hermes hermes version
ls -la "$HOME/.local/bin" | head -20
du -sh /opt/pecera-hermes
echo PREBUILT_OK