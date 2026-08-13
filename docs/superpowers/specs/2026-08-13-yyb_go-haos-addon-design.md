# YYB-Go Enhanced HAOS Add-on 设计规格

日期：2026-08-13

## 目标

参考你现有 `windowlife/Arcadia_addons` 已验证的“上游项目 + HAOS 包装层”思路，新建一个**独立的 YYB-Go HAOS Add-on 仓库**。该仓库只用于包装 `525815266/YYB-Go-Enhanced`，使其能直接安装在 Home Assistant OS / Supervisor 中，并与同一台 HAOS 上的青龙 Add-on 通信。

新仓库 `yyb_go_addons` 与 `Arcadia_addons` 完全独立；`Arcadia_addons` 仅作为包装思路参考，不存在目录、发布或运行时依赖。

## 已确认约束

- 保留 YYB-Go Enhanced 上游功能与 Web 控制台。
- 保留 Nginx Basic Auth，不改成 HAOS Ingress。
- HAOS Add-on 采用单容器；原 Compose 的 `yyb-go` 与 `yyb-web` 合并到一个容器运行。
- Web 对外入口使用 Nginx 8080；Go 后端继续监听容器内部 8000。
- 8000 不映射到 HAOS 主机，避免未认证 API 直接暴露到局域网。
- 青龙与 YYB-Go 都是同一台 HAOS 的 Add-on，不再使用 `qinglong_default` Docker 网络。
- YYB-Go 的可变数据持久化在 HAOS 自动提供的 `/data` 卷中。
- 上游当前没有可直接复用的发布镜像，因此包装层在 Docker 构建阶段从固定的 YYB-Go Enhanced 上游源码版本/提交构建 Go 二进制，而不是复制整个上游源码长期维护。

## 架构

```text
浏览器 / 局域网
      |
      | HAOS 映射端口，例如 8000 -> 8080
      v
+-----------------------------------+
| YYB-Go HAOS Add-on（单容器）       |
|                                   |
|  Nginx :8080                      |
|  Basic Auth                       |
|       |                           |
|       v                           |
|  127.0.0.1:8000                  |
|  YYB-Go Enhanced                 |
|       |                           |
|       +--> /data/db              |
|       +--> /data/avatars         |
|       +--> /data/qr              |
+-----------------------------------+
        |
        | HAOS 内部 Add-on 网络
        v
+-----------------------------------+
| QingLong Add-on :5700             |
+-----------------------------------+
```

## 独立仓库结构

新仓库根目录直接命名为 `yyb_go_addons`。它本身就是一个独立的 Home Assistant Add-on Repository，只包含 YYB-Go 的包装层：

```text
yyb_go_addons/
├── repository.json
├── README.md
├── yyb_go/
│   ├── config.json
│   ├── Dockerfile
│   ├── run.sh
│   ├── nginx.conf
│   ├── README.md
│   ├── DOCS.md
│   ├── icon.png
│   └── logo.png
└── docs/
    └── superpowers/specs/...
```

用户在 Home Assistant Add-on Store 中添加的是这个**独立仓库 URL**。Supervisor 扫描 `yyb_go/` 后，只显示 YYB-Go Enhanced，不会与 Arcadia 仓库发生任何关联。

## Docker 构建

使用多阶段构建：

1. Go 构建阶段使用 `golang:1.23-alpine`。
2. 从 `525815266/YYB-Go-Enhanced` 获取固定 ref/commit 的源码并编译 `./cmd/yyb-go`。
3. 运行阶段使用 Alpine（或明确版本的 HA base），安装 `nginx`、`apache2-utils`、`ca-certificates`、`wget`、`jq` 等最低依赖。
4. 把 YYB-Go 二进制和上游 `resource/` 静态资源复制进最终镜像。
5. Add-on 自己的 `run.sh` 负责读取 `/data/options.json`、初始化持久化目录、生成 htpasswd、启动 YYB-Go 和 Nginx。

上游版本必须固定，避免同一个 HAOS Add-on 版本在不同时间构建出不同代码。升级上游时同步提升 Add-on `version` 和构建 ref。

## 数据持久化

保持上游 Compose 的三个可变目录语义：

- `/app/resource/db` -> `/data/db`
- `/app/resource/avatars` -> `/data/avatars`
- `/app/resource/qr` -> `/data/qr`

启动时创建 `/data/db`、`/data/avatars`、`/data/qr`，再将 `/app/resource/` 对应路径链接到 `/data`。模板和其他只读资源仍来自镜像内 `/app/resource`。

这样 Add-on 升级/重建不会删除 SQLite、头像和二维码数据，且无需把整个 Home Assistant `/config` 映射进容器。

## 配置项

`config.json` 暴露：

- `web_user`：Basic Auth 用户名，默认 `admin`
- `web_password`：Basic Auth 密码，首次安装要求用户修改/填写
- `keepalive_interval`：默认 `30m`
- `keepalive_ahead`：默认 `45m`
- `ql_url`：青龙 OpenAPI 地址，可配置
- `ql_client_id`：可选
- `ql_client_secret`：可选，标记为密码字段（在 HAOS UI schema 能力允许范围内）
- `yyb_qinglong_server`：写入青龙环境变量时 YYB-Go 的内部服务地址
- `yyb_qinglong_repo`：默认 `SuperNaiBA_YYB-GO-Script,525815266_YYB-Go-Enhanced/scripts`

Web 端口只暴露 `8080/tcp`，默认映射宿主 `8000`，与上游默认访问习惯保持一致：

```text
http://[HOST]:[PORT:8080]/
```

## HAOS Add-on 间网络

不创建 `qinglong_default`。

Home Assistant Supervisor 的 Add-on 内部网络允许 Add-on 之间按生成的名称/别名通信。实际 DNS 名由青龙 Add-on 所在仓库标识与 slug 决定，因此 `ql_url` 不在包装层硬编码成普通 Docker Compose 的 `http://qinglong:5700`；用户可以在 Add-on 配置里填写其青龙内部地址。

YYB-Go 自身供青龙脚本访问的地址同样不能假设固定为 `yyb-go:8000`。文档将说明两种安全方式：

1. 推荐使用 Supervisor 为 YYB-Go 生成的内部 Add-on DNS 名 + `:8000`；
2. 如果用户已有可用内部 alias，则直接使用 alias + `:8000`。

8000 不映射到宿主机；只有 HAOS 内部网络能直接访问未经过 Basic Auth 的后端。

## 进程管理

`run.sh`：

1. 读取 `/data/options.json`。
2. 校验 Basic Auth 密码不为空。
3. 创建持久化目录及链接。
4. 用 `htpasswd -bcB` 生成 `/etc/nginx/auth/htpasswd`。
5. 设置 YYB-Go 所需环境变量。
6. 后台启动 `/app/yyb-go -host 0.0.0.0 -port 8000 -resource-root /app/resource ...`。
7. 等待 `/health` 成功；失败则退出，让 Supervisor 判断 Add-on 启动失败。
8. 前台启动 `nginx -g 'daemon off;'`。
9. 捕获 SIGTERM/SIGINT，结束两个进程，保证 Supervisor 停止/升级时正常退出。

Nginx 将上游 `proxy_pass http://yyb-go:8000` 改为单容器的：

```text
proxy_pass http://127.0.0.1:8000;
```

其余代理超时、请求大小和 Basic Auth 行为保持上游逻辑。

## 安全

- 对宿主只开放 Nginx 8080，不开放 Go 8000。
- Basic Auth 密码不能使用空字符串。
- 不需要 `host_network`、`privileged`、`full_access` 或 Docker API。
- 不映射 Home Assistant 主配置目录。
- 青龙 Client Secret 只通过 HAOS Add-on 配置传给后端；YYB-Go 本身仍按上游逻辑将 Web 控制台保存的青龙配置写入 SQLite。

## 兼容性

目标架构：

- `amd64`
- `aarch64`

YYB-Go 使用 `CGO_ENABLED=0` 编译，Go 与 Alpine 均支持这两个架构；最终需要在 HAOS 或等价 Builder 上分别验证构建。

## 验收标准

1. 将新的 YYB-Go HAOS Add-on 仓库 URL 加入商店后，只显示 YYB-Go Enhanced Add-on；无需添加或依赖 `Arcadia_addons`。
2. YYB-Go Add-on 可在 amd64/aarch64 目标上构建。
3. 首次启动后 `http://HAOS_IP:配置端口` 弹出 Basic Auth。
4. 登录后 Web 控制台正常，扫码页面、账号页、OpenAPI 文档可访问。
5. SQLite/头像/二维码数据在 Add-on 重启和升级后保留。
6. `http://HAOS_IP:8000` 实际访问的是 Nginx，不是未认证 Go 后端。
7. 从 YYB-Go Add-on 能通过配置的内部 `ql_url` 访问青龙 OpenAPI。
8. 从青龙 Add-on 能通过 YYB-Go 的 HAOS 内部 DNS 名访问 `http://<yyb-addon-dns>:8000/health`。
9. YYB-Go Web 控制台的一键同步能写入青龙 `YYB_SERVER`，并使用正确的 HAOS 内部地址。
10. Supervisor 停止/重启 Add-on 时两个进程都能正常结束并重新启动。

## 非目标

本次不做：

- HAOS Ingress；
- 修改 YYB-Go Enhanced 业务源码；
- 将青龙与 YYB-Go 合并成一个 Add-on；
- 暴露 Docker socket 或操作 HAOS Docker 网络；
- 自动猜测所有第三方青龙 Add-on 的 slug/DNS 名。

