#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "yyb_go"
EXPECTED_REF = "dd0081ef393a3d3024b145dd038ea1192fdc00c5"


def fail(message: str) -> None:
    raise AssertionError(message)


def require_file(path: Path) -> str:
    if not path.is_file():
        fail(f"missing required file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


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

    if cfg["slug"] != "yyb_go":
        fail("slug must stay yyb_go because runtime DNS documentation depends on it")

    if sorted(cfg["arch"]) != ["aarch64", "amd64"]:
        fail("arch must contain exactly aarch64 and amd64")

    if cfg.get("hassio_api") is not True:
        fail("hassio_api must be enabled for Supervisor discovery")
    if cfg.get("hassio_role") != "manager":
        fail("hassio_role must be manager so /addons discovery is permitted")

    ports = cfg.get("ports", {})
    if ports.get("8080/tcp") != 8000:
        fail("8080/tcp must default-map to host port 8000")
    if "8000/tcp" in ports:
        fail("backend port 8000 must not be published to the HAOS host")

    if cfg.get("webui") != "http://[HOST]:[PORT:8080]/":
        fail("webui must target the authenticated nginx port")

    schema = cfg.get("schema", {})
    if schema.get("web_password") != "password":
        fail("web_password must use Home Assistant password schema")
    if cfg.get("options", {}).get("web_password", "not-null") is not None:
        fail("web_password must be mandatory before first start")


def validate_dockerfile() -> None:
    text = require_file(ADDON / "Dockerfile")
    if f"ARG YYB_REF={EXPECTED_REF}" not in text:
        fail("Dockerfile is not pinned to the expected upstream revision")
    if "FROM golang:1.23-alpine AS build" not in text:
        fail("Go 1.23 builder stage is missing")
    if "FROM nginx:1.27-alpine" not in text:
        fail("Nginx runtime stage is missing")
    if "EXPOSE 8080 8000" not in text:
        fail("expected internal ports are not documented by EXPOSE")


def validate_runtime() -> None:
    text = require_file(ADDON / "run.sh")

    for path in ("/data/db", "/data/avatars", "/data/qr"):
        # The script generates /data/${name}; ensure the data root and names exist.
        if "/data/${name}" not in text or name_from_path(path) not in text:
            fail(f"runtime persistence missing {path}")

    for endpoint in ("/addons", "/addons/self/info"):
        if endpoint not in text:
            fail(f"Supervisor discovery endpoint missing: {endpoint}")

    if "tr '_' '-'" not in text:
        fail("Supervisor slug-to-DNS conversion is missing")
    if "unset SUPERVISOR_TOKEN" not in text:
        fail("Supervisor token must be removed before upstream processes start")

    if not re.search(r"-resource-root\s+/app/resource", text):
        fail("YYB resource root is not configured")


def name_from_path(path: str) -> str:
    return path.rsplit("/", 1)[-1]


def validate_nginx() -> None:
    text = require_file(ADDON / "nginx.conf")
    for expected in (
        "listen 8080;",
        'auth_basic "YYB Go";',
        "proxy_pass http://127.0.0.1:8000;",
        "location = /addon-health",
        "auth_basic off;",
    ):
        if expected not in text:
            fail(f"nginx.conf missing: {expected}")


def validate_docs() -> None:
    for path in (
        ROOT / "README.md",
        ADDON / "README.md",
        ADDON / "DOCS.md",
        ADDON / "CHANGELOG.md",
    ):
        require_file(path)


if __name__ == "__main__":
    validate_repository()
    validate_config()
    validate_dockerfile()
    validate_runtime()
    validate_nginx()
    validate_docs()
    print("OK: yyb_go_addons static validation passed")
