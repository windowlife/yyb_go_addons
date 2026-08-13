# YYB-Go Enhanced

这是 `YYB-Go Enhanced` 的 Home Assistant OS / Supervisor Add-on 封装。

## 主要特点

- 将上游 `yyb-go` 后端和 `yyb-web` Nginx 合并为一个 HAOS Add-on 容器。
- Web UI 保留 Nginx Basic Auth。
- 后端 `8000` 端口仅用于 HAOS 内部网络，不映射到宿主机。
- `db`、`avatars`、`qr` 使用 `/data` 持久化。
- 自动通过 Supervisor API 发现同机青龙 Add-on。
- 自动计算 YYB-Go 自己的 HAOS 内部 DNS 地址，供青龙 `YYB_SERVER` 使用。
- 支持 `amd64` 和 `aarch64`。

完整配置与排错说明请查看 [DOCS.md](DOCS.md)。
