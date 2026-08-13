# YYB-Go Enhanced Add-on 使用说明

## 1. 首次安装

安装后先进入 **配置** 页面。

必须设置：

```yaml
web_password: 你的强密码
```

默认 Web 用户名：

```text
admin
```

启动后点击 **打开 Web UI**。默认宿主端口为 `8000`，实际入口由 Supervisor 的网络设置决定。

## 2. 配置项

### `web_user`

Nginx Basic Auth 用户名，默认：

```text
admin
```

### `web_password`

Nginx Basic Auth 密码。首次启动前必须设置。

### `keepalive_interval`

对应上游 `YYB_KEEPALIVE_INTERVAL`，默认：

```text
30m
```

上游支持将该值设为 `0` 关闭后台保活。

### `keepalive_ahead`

对应上游 `YYB_KEEPALIVE_AHEAD`，默认：

```text
45m
```

### `ql_url`

青龙 OpenAPI 地址。

通常可以留空。Add-on 会向 Supervisor 查询当前已安装应用，自动寻找名称或 slug 中包含 `QingLong`、`qinglong` 或 `青龙` 的应用，然后使用：

```text
http://<HAOS内部DNS名>:5700
```

如果自动发现失败，可以手工填写。

例如（仅示例，以你系统实际内部名称为准）：

```text
http://a1b2c3d4-qinglong:5700
```

也可以进入 YYB-Go Web 控制台，在“青龙连接设置”中保存地址、Client ID 和 Client Secret。上游逻辑会优先使用数据库中保存的设置。

### `ql_client_id`

可选。青龙 OpenAPI Client ID。

### `ql_client_secret`

可选。青龙 OpenAPI Client Secret。

### `yyb_qinglong_server`

通常留空。

Add-on 会通过：

```text
http://supervisor/addons/self/info
```

读取自己的 Supervisor slug，并按 Home Assistant 的内部 DNS 规则将 `_` 替换为 `-`，自动生成：

```text
<本Add-on内部DNS名>:8000
```

该值传给上游 `YYB_QINGLONG_SERVER`，用于 YYB-Go 向青龙生成/同步 `YYB_SERVER`。

若自动读取失败，可手工填写。

### `yyb_qinglong_repo`

供 YYB-Go 的青龙运行管理功能发现脚本目录，默认：

```text
SuperNaiBA_YYB-GO-Script,525815266_YYB-Go-Enhanced/scripts
```

## 3. 端口设计

### Web UI

容器：

```text
8080/tcp
```

默认映射到 HAOS 宿主：

```text
8000/tcp
```

该入口经过 Nginx Basic Auth。

### YYB-Go 内部 API

容器：

```text
8000/tcp
```

该端口**没有**配置 Supervisor 宿主端口映射，因此不会直接暴露到局域网，但其他 HAOS Add-on 可以通过内部 DNS 访问。

青龙脚本最终使用的形式类似：

```text
YYB_SERVER=<YYB-Go内部DNS名>:8000@OpenID
```

## 4. 持久化

Home Assistant 会为 Add-on 提供持久化 `/data`。

本封装将上游三个可写目录映射为：

```text
/app/resource/db      -> /data/db
/app/resource/avatars -> /data/avatars
/app/resource/qr      -> /data/qr
```

所以：

- Add-on 重启不会丢账号数据库。
- Add-on 升级不会丢二维码/头像等运行数据。
- 上游 `resource/templates` 等只读资源仍随新镜像更新。

## 5. 青龙自动发现原理

Home Assistant 的 Add-on 内部网络名称由 Supervisor 生成。GitHub 仓库安装的 Add-on 通常不是简单的 `qinglong`，而是带仓库标识。

为了读取已安装应用列表，本 Add-on 使用 `hassio_role: manager`。该权限只用于启动阶段的自动发现；发现完成后启动脚本会立即移除 `SUPERVISOR_TOKEN`，不会将 Supervisor Token 传给 YYB-Go 上游进程。

启动脚本使用 Supervisor API：

```text
GET http://supervisor/addons
```

找出青龙的完整 slug，然后把 `_` 转为 `-` 作为内部 DNS hostname。

因此不再需要普通 Docker Compose 部署里的：

```text
qinglong_default
```

外部 Docker 网络。

## 6. 数据迁移

如果你以前使用普通 Docker Compose YYB-Go，可以先停止旧服务，再备份：

```text
data/db
data/avatars
data/qr
```

HAOS Add-on 首次正常启动后，需要迁移时再将对应内容恢复到本 Add-on 的 `/data` 数据目录。不要在旧服务和 HAOS Add-on 同时运行并写同一份 SQLite 数据库。

## 7. 排错

### Web UI 打不开

查看 Add-on 日志，应至少出现：

```text
启动 YYB-Go 后端：0.0.0.0:8000
启动 Nginx Web UI：0.0.0.0:8080
```

### Basic Auth 一直失败

修改 `web_user` / `web_password` 后重启 Add-on。每次启动都会重新生成 `/etc/nginx/auth/htpasswd`。

### 自动发现不到青龙

日志会出现：

```text
未能通过 Supervisor 自动发现青龙
```

这时直接填写 `ql_url`，或在 YYB-Go Web 控制台保存青龙连接信息。

### 青龙能连接 YYB-Go，但一键同步进去的地址不对

填写 `yyb_qinglong_server` 为本 Add-on 的实际内部 DNS 名加 `:8000`。

Home Assistant 内部 DNS 名的规则是 Supervisor 完整 slug 中的 `_` 替换为 `-`。

## 8. 上游版本

当前 Add-on `1.0.0` 固定构建：

```text
dd0081ef393a3d3024b145dd038ea1192fdc00c5
```

对应上游仓库：

```text
https://github.com/525815266/YYB-Go-Enhanced
```

固定 revision 的目的是确保同一个 Add-on 版本不会因为上游 `main` 变化而构建出不同内容。
