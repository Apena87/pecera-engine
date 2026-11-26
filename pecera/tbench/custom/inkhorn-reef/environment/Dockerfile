FROM node:22-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium python3 curl git ripgrep xz-utils tmux ca-certificates fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
RUN mkdir -p /app/game
