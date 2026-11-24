export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get install -y -qq curl git xz-utils ca-certificates ripgrep >/dev/null 2>&1
export PATH=/opt/pecera-hermes/home/.local/bin:$PATH
rm -rf /tmp/hermes; mkdir -p /tmp/hermes/sessions /tmp/hermes/skills /tmp/hermes/memories
HERMES_HOME=/tmp/hermes hermes pm repair 2>&1 | tail -2
HERMES_HOME=/tmp/hermes hermes --version 2>&1 | head -1
rm -rf /opt/pecera-hermes/tmp-hermes && cp -a /tmp/hermes /opt/pecera-hermes/tmp-hermes && du -sh /opt/pecera-hermes/tmp-hermes && echo RUNTIME_SAVED