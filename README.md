# YYB-Go Add-ons

Home Assistant OS / Supervisor Add-on repository for **YYB-Go Enhanced**.

This repository is an HAOS packaging layer. It does **not** fork or modify the YYB-Go business logic. The Add-on Docker build fetches and builds a pinned upstream revision from:

- Upstream: `https://github.com/525815266/YYB-Go-Enhanced`
- Pinned revision: `dd0081ef393a3d3024b145dd038ea1192fdc00c5`

## Add repository to Home Assistant

Add this repository URL in **Settings → Apps → App store → Repositories** (older Home Assistant versions may still call Apps “Add-ons”):

```text
https://github.com/windowlife/yyb_go_addons
```

Then install **YYB-Go Enhanced**.

Before first start, open the app configuration and set a strong `web_password`.

## Architecture

The original upstream Docker Compose deployment uses two containers:

- `yyb-go`: Go backend on port `8000`
- `yyb-web`: Nginx Basic Auth reverse proxy on port `8080`

This HAOS package combines both processes in one Supervisor-managed container:

```text
LAN browser
    |
    | host port 8000 (default)
    v
Nginx :8080  -- Basic Auth -->  YYB-Go :8000
                                  ^
                                  |
                           HAOS internal network
                                  |
                              QingLong
```

The backend port `8000` is **not** published to the HAOS host. It remains reachable by other apps on the Home Assistant internal network.

## QingLong integration

When `ql_url` is left empty, the startup script asks Supervisor for installed apps and tries to find an app whose name or slug contains `QingLong`, `qinglong`, or `青龙`. It then converts the Supervisor app slug into the HAOS DNS hostname automatically.

You can always override automatic detection with `ql_url`. This discovery requires `hassio_role: manager`; the startup script removes `SUPERVISOR_TOKEN` from the environment before launching the upstream YYB-Go process.

The Add-on also derives its own internal DNS name from Supervisor and supplies it to YYB-Go as `YYB_QINGLONG_SERVER`, so that YYB-Go can create QingLong `YYB_SERVER` entries that point back to this Add-on.

## Persistent data

The upstream mutable directories are redirected to Home Assistant's persistent `/data` volume:

```text
/data/db
/data/avatars
/data/qr
```

Templates and other immutable resources continue to come from the image, so upstream template updates are picked up when the Add-on image is rebuilt.

## Updating upstream YYB-Go

To update to a newer upstream revision:

1. Change `ARG YYB_REF=...` in `yyb_go/Dockerfile`.
2. Increase `version` in `yyb_go/config.json`.
3. Add a line to `yyb_go/CHANGELOG.md`.
4. Run `python3 tests/validate.py`.
5. Build/install the Add-on and verify Web UI, account persistence, and QingLong connectivity.

## Notice

YYB-Go Enhanced is a separate upstream project. This repository only contains the HAOS packaging/adaptation code. Use the upstream service in accordance with its notices, platform terms, and applicable laws.
