FROM lscr.io/linuxserver/chrome:latest

LABEL org.opencontainers.image.title="Chrome DevTools Sandbox"
LABEL org.opencontainers.image.description="Disposable Chrome sandbox with a stable CDP proxy for AI agents and automation"
LABEL org.opencontainers.image.source="https://github.com/Lee-WonJun/chrome-dev-tool-sandbox"

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    socat && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=5 \
  CMD curl --silent --fail "http://127.0.0.1:${CDP_PROXY_PORT:-9223}/json/version" >/dev/null || exit 1

EXPOSE 3000 3001 9223

ENTRYPOINT ["/entrypoint.sh"]
