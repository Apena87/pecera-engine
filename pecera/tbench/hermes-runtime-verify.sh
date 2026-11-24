(command -v git >/dev/null) || (apt-get update -qq >/dev/null 2>&1; DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git ripgrep curl xz-utils ca-certificates >/dev/null 2>&1)
. /etc/os-release; echo "image: $PRETTY_NAME glibc $(ldd --version | head -1 | awk '{print $NF}')"
s=$(date +%s)
mkdir -p "$HOME/.local/bin"; ln -sf /opt/pecera-hermes/home/.local/bin/hermes "$HOME/.local/bin/hermes"; export PATH="$HOME/.local/bin:$PATH"
rm -rf /tmp/hermes; cp -a /opt/pecera-hermes/tmp-hermes /tmp/hermes
HERMES_HOME=/tmp/hermes hermes --version 2>&1 | head -2
e=$(date +%s); echo "setup seconds: $((e-s))"