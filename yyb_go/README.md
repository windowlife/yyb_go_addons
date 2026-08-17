# YYB-Go Enhanced

这是 `YYB-Go Enhanced` 的 Home Assistant OS / Supervisor App 封装。

## 1.1.0 主要特点

- 跟随上游单容器架构，只运行一个 YYB-Go 进程。
- 容器直接监听 `8000`，HAOS 默认映射到宿主 `8000`。
- 使用上游原生登录、注册、管理员和会话管理。
- Web 认证数据与微信协议数据一起持久化在 `/data/db`。
- `avatars`、`qr` 同样使用 `/data` 持久化。
- 自动通过 Supervisor API 发现同机青龙 App。
- 自动推导 YYB-Go 自己的 HAOS 内部 DNS 地址，供青龙 `YYB_SERVER` 使用。
- 支持 `amd64` 与 `aarch64`。

完整配置与排错说明请查看 [DOCS.md](DOCS.md)。
