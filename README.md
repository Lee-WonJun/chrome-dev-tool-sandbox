# Chrome DevTools Sandbox


https://github.com/user-attachments/assets/5273a7a9-d1c1-4d4c-a23a-2ea6c7a19403


Disposable Chrome containers with a remote CDP endpoint and optional web UI.

Built on top of [linuxserver/docker-chrome](https://github.com/linuxserver/docker-chrome), with a small proxy layer so Chrome DevTools Protocol stays reachable from outside the container.

## Why

- Chrome DevTools MCP is awesome, especially when you can attach to a remote host.
- Tools like KasmVNC or Selkies are awesome because they give you a browser-accessible virtual environment you can use like a sandbox, then suspend, resume, keep, or throw away.
- Putting those together is more awesome.
- You can spin up fresh Chrome containers whenever you want.
- You can go beyond just splitting profiles inside Chrome and separate whole browser environments the way you want.
- You can keep them off your host machine.
- You can dispose, keep, suspend, or resume them however you want.
- You can use them like a headless browser if you want, then open the web UI when you need the GUI for the same session.

## What It Solves

Recent Chrome builds reject external CDP connections even when Chrome is started with `--remote-debugging-address=0.0.0.0`. In practice that means Docker port forwarding alone is not enough.

This repo works around that by terminating external traffic on a container-local `socat` proxy and forwarding it to Chrome over loopback.

```text
Host -> :9223 -> socat proxy inside container -> 127.0.0.1:9222 -> Chrome
```

## Architecture

- Base image: `lscr.io/linuxserver/chrome`
- Browser UI:
  - HTTP on container port `3000`
  - HTTPS on container port `3001`
- CDP:
  - Chrome listens on `127.0.0.1:9222` inside the container
  - `socat` exposes a separate external proxy port, `9223` by default
- Persistence:
  - browser state is stored under `./config`

## How To Use It

- Use `http://host:9223` as the CDP endpoint from MCP or other automation tooling.
- Keep the web UI closed if you do not need it and use the container like a remote browser backend.
- Open the web UI when you want to inspect or interact with the same running browser session manually.
- Spin up a new container when you want a separate environment, or keep and reuse one when you want the state to persist.

## Quick Start

1. Copy the example environment file if you want to customize ports or runtime settings.

```bash
cp .env.example .env
```

2. Start the sandbox.

```bash
docker compose up -d --build
```

3. Verify that CDP is reachable.

```bash
curl http://127.0.0.1:9223/json/version
```

4. Open the browser UI.

```text
http://localhost:3000
https://localhost:3001
```

## Configuration

The included `.env.example` covers the common product-level knobs.

| Variable | Default | Purpose |
| --- | --- | --- |
| `CONTAINER_NAME` | `chrome-sandbox` | Compose container name |
| `PUID` | `1000` | Runtime user ID for the base image |
| `PGID` | `1000` | Runtime group ID for the base image |
| `TZ` | `Etc/UTC` | Container timezone |
| `WEB_HTTP_PORT` | `3000` | Host port mapped to the HTTP browser UI |
| `WEB_HTTPS_PORT` | `3001` | Host port mapped to the HTTPS browser UI |
| `CDP_PROXY_PORT` | `9223` | External CDP proxy port |
| `CDP_PROXY_BIND_ADDRESS` | `0.0.0.0` | Bind address for the proxy listener |
| `CHROME_DEBUG_ADDRESS` | `127.0.0.1` | Internal Chrome debugging bind address |
| `CHROME_DEBUG_PORT` | `9222` | Internal Chrome debugging port |
| `CHROME_USER_DATA_DIR` | `/config/chrome-debug-profile` | Chrome profile directory |
| `CHROME_SHM_SIZE` | `1gb` | Shared memory size for the browser |
| `EXTRA_CHROME_CLI` | empty | Extra Chrome flags appended to the generated Chrome launch arguments |

The compose file generates the base `CHROME_CLI` required by the linuxserver wrapper and appends `EXTRA_CHROME_CLI` if you need additional flags.

## Usage

### Connect from MCP clients

#### OpenAI Codex

Add this to `~/.codex/config.json`:

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest", "--browserUrl", "http://127.0.0.1:9223"]
    }
  }
}
```

#### Kiro CLI

Add this to `~/.kiro/settings/mcp.json`:

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest", "--browserUrl", "http://127.0.0.1:9223"]
    }
  }
}
```

### Call CDP directly

```bash
curl http://127.0.0.1:9223/json/list
curl -X PUT "http://127.0.0.1:9223/json/new?https://example.com"
```

## Verification

After startup, the following checks should pass:

```bash
# container is healthy
docker compose ps

# CDP metadata is reachable
curl http://127.0.0.1:9223/json/version

# browser tab list is reachable
curl http://127.0.0.1:9223/json/list
```

If the UI is required, also confirm the browser frontend responds on `http://localhost:3000` or `https://localhost:3001`.

## Notes

- Port `9222` is intentionally kept internal. The supported external entrypoint is the proxy port, `9223` by default.
- Browser profile data persists in `./config`, which is useful when you want to suspend, resume, or keep a session around.
- Startup cleans stale Chrome singleton lock files inside the configured profile directory so reused volumes can boot cleanly.
- If you want a fresh browser state, stop the stack and clear `./config` before starting again.
- The CDP health check targets the proxy endpoint rather than the raw Chrome port, which better reflects real client readiness.

## Credits

- [linuxserver/docker-chrome](https://github.com/linuxserver/docker-chrome) for the base browser container
