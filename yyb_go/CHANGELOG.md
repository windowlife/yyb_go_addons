# Changelog

## 1.1.1

- 升级版本号，方便haos拉取最新代码。

## 1.1.0

- 跟随上游单容器部署架构。
- 删除包装层额外 Web 反向代理进程，YYB-Go 直接监听 `8000`。
- HAOS 网络改为 `8000/tcp -> 8000`。
- 使用上游原生登录、注册、管理员和会话管理。
- 新增可选 `yyb_admin_user`、`yyb_admin_password` 与 `yyb_cookie_secure` 配置。
- `yyb_qinglong_server` 改为真正的可选覆盖参数，正常情况下由 Supervisor 自动推导。
- 保留青龙自动发现、`YYB_QINGLONG_SERVER` 自动生成和 `/data` 持久化。
- 运行时只保留单个 YYB-Go 进程，启动准备完成后以 `yyb` 用户运行。

## 1.0.0

- 首个 Home Assistant OS / Supervisor App 包装版本。
- 固定 YYB-Go Enhanced 上游 revision `dd0081ef393a3d3024b145dd038ea1192fdc00c5`。
- 旧版使用 Go 后端与额外 Nginx 认证前端组合运行。
- 将数据库、头像、二维码目录持久化到 `/data`。
- 自动通过 Supervisor API 发现青龙 App。
- 自动推导本 App 的 HAOS 内部 DNS 地址供 `YYB_QINGLONG_SERVER` 使用。
- 支持 `amd64`、`aarch64`。
