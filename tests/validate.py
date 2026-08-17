#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "yyb_go"
EXPECTED_REF = "9fc25bad7c099a861876cd78460c496df4fccc85"
EXPECTED_VERSION = "1.1.0"


def fail(message: str) -> None:
    raise AssertionError(message)


def require_file(path: Path) -> str:
    if not path.is_file():
        fail(f"missing required file: {path.relative_to(ROOT)}")
    raw = path.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        fail(f"UTF-8 BOM is not allowed: {path.relative_to(ROOT)}")
    return raw.decode("utf-8")


def validate_repository() -> None:
    text = require_file(ROOT / "repository.yaml")
    for key in ("name:", "url:", "maintainer:"):
        if key not in text:
            fail(f"repository.yaml missing {key}")


def validate_config() -> None:
    raw = require_file(ADDON / "config.json")
    cfg = json.loads(raw)

    for key in ("name", "version", "slug", "description", "arch"):
        if key not in cfg:
            fail(f"config.json missing {key}")

    if cfg["version"] != EXPECTED_VERSION:
        fail(f"version must be {EXPECTED_VERSION}")
    if cfg["slug"] != "yyb_go":
        fail("slug must stay yyb_go")
    if sorted(cfg["arch"]) != ["aarch64", "amd64"]:
        fail("arch must contain exactly aarch64 and amd64")

    if cfg.get("hassio_api") is not True:
        fail("hassio_api must be enabled for Supervisor discovery")
    if cfg.get("hassio_role") != "manager":
        fail("hassio_role must be manager so /addons discovery is permitted")

    ports = cfg.get("ports", {})
    if ports != {"8000/tcp": 8000}:
        fail("single-container version must expose only 8000/tcp -> host 8000")
    if cfg.get("webui") != "http://[HOST]:[PORT:8000]/":
        fail("webui must target upstream YYB-Go port 8000")
    if cfg.get("watchdog") != "http://[HOST]:[PORT:8000]/health":
        fail("watchdog must use upstream /health endpoint")

    options = cfg.get("options", {})
    schema = cfg.get("schema", {})
    for removed in ("web_user", "web_password"):
        if removed in options or removed in schema:
            fail(f"legacy nginx option must be removed: {removed}")

    if "yyb_qinglong_server" in options:
        fail("yyb_qinglong_server must be truly optional; remove its default")
    if schema.get("yyb_qinglong_server") != "str?":
        fail("yyb_qinglong_server must be optional")
    if schema.get("yyb_admin_password") != "password?":
        fail("yyb_admin_password must be optional and masked")
    if options.get("yyb_cookie_secure") is not False:
        fail("yyb_cookie_secure must default to false for direct HTTP access")


def validate_dockerfile() -> None:
    text = require_file(ADDON / "Dockerfile")
    if f"ARG YYB_REF={EXPECTED_REF}" not in text:
        fail("Dockerfile is not pinned to the expected upstream revision")
    for required in (
        "FROM golang:1.23-alpine AS build",
        "ENV GOPROXY=https://goproxy.cn,direct",
        "FROM alpine:3.21",
        "EXPOSE 8000",
        'ENTRYPOINT ["/run.sh"]',
    ):
        if required not in text:
            fail(f"Dockerfile missing: {required}")
    for legacy in ("nginx:1.27-alpine", "apache2-utils", "EXPOSE 8080"):
        if legacy in text:
            fail(f"legacy nginx packaging remains in Dockerfile: {legacy}")
    if "chown -R yyb:yyb /app/resource" not in text:
        fail("resource tree must be writable by yyb user")


def validate_runtime() -> None:
    text = require_file(ADDON / "run.sh")

    for name in ("db", "avatars", "qr"):
        if "/data/${name}" not in text or name not in text:
            fail(f"runtime persistence missing /data/{name}")

    for endpoint in ("/addons", "/addons/self/info"):
        if endpoint not in text:
            fail(f"Supervisor discovery endpoint missing: {endpoint}")

    if "tr '_' '-'" not in text:
        fail("Supervisor slug-to-DNS conversion is missing")
    if "unset SUPERVISOR_TOKEN" not in text:
        fail("Supervisor token must be removed before YYB-Go starts")
    if "YYB_AUTH_DRIVER=sqlite" not in text:
        fail("HAOS wrapper must use upstream SQLite auth by default")
    if "YYB_ADMIN_USER" not in text or "YYB_ADMIN_PASSWORD" not in text:
        fail("upstream native admin bootstrap variables are not propagated")
    if "YYB_COOKIE_SECURE" not in text:
        fail("upstream cookie security option is not propagated")
    if "nginx" in text.lower() or "htpasswd" in text.lower():
        fail("legacy nginx/basic-auth runtime logic must be removed")
    if not re.search(r"-resource-root\s+/app/resource", text):
        fail("YYB resource root is not configured")
    if not re.search(r"exec\s+su-exec\s+yyb:yyb\s+/app/yyb-go", text):
        fail("run.sh must exec the single YYB-Go process as yyb user")


def validate_removed_files() -> None:
    if (ADDON / "nginx.conf").exists():
        fail("nginx.conf must be deleted in the single-container version")


def validate_docs() -> None:
    for path in (
        ROOT / "README.md",
        ADDON / "README.md",
        ADDON / "DOCS.md",
        ADDON / "CHANGELOG.md",
    ):
        text = require_file(path)
        if "Nginx Basic Auth" in text:
            fail(f"stale nginx documentation remains: {path.relative_to(ROOT)}")


if __name__ == "__main__":
    validate_repository()
    validate_config()
    validate_dockerfile()
    validate_runtime()
    validate_removed_files()
    validate_docs()
    print("OK: yyb_go_addons 1.1.0 static validation passed")
