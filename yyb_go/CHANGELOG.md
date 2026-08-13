# Changelog

## 1.0.0

- 首个 Home Assistant OS / Supervisor Add-on 包装版本。
- 固定 YYB-Go Enhanced 上游 revision `dd0081ef393a3d3024b145dd038ea1192fdc00c5`。
- 将 Go 后端与 Nginx Basic Auth 前端合并到单一 Add-on 容器。
- 将数据库、头像、二维码目录持久化到 `/data`。
- 自动通过 Supervisor API 发现青龙 Add-on。
- 自动推导本 Add-on 的 HAOS 内部 DNS 地址供 `YYB_QINGLONG_SERVER` 使用。
- 支持 `amd64`、`aarch64`。
