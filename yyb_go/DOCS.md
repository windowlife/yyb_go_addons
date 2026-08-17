# YYB-Go Enhanced App 使用说明

## 1. 首次启动

安装并启动后，直接点击 **打开 Web UI**，或者访问：

```text
http://HAOS局域网IP:8000
```

1.1.0 不再使用包装层账号密码，而使用 YYB-Go 上游自己的用户系统。

如果以下两个配置都留空：

```text
yyb_admin_user
yyb_admin_password
```

首次在 Web 页面注册的账号会成为管理员。

如果希望在首次启动时直接初始化管理员，请同时填写：

```yaml
yyb_admin_user: your_admin
yyb_admin_password: your_strong_password
```

两个字段必须同时填写或同时留空。

## 2. 配置项

### `keepalive_interval`

账号保活检查间隔，默认：

```text
30m
```

设置为 `0` 可关闭后台保活。

### `keepalive_ahead`

Access Token 剩余多久时提前续期，默认：

```text
45m
```

### `ql_url`

青龙 OpenAPI 地址。

通常留空即可，Add-on 会通过 Supervisor 自动寻找同机青龙，并生成：

```text
http://<青龙HAOS内部DNS>:5700
```

也可以手工填写，例如：

```text
http://7eca76cc-qinglong:5700
```

或者填写你已有的青龙 HTTPS 地址。

### `ql_client_id`

青龙 OpenAPI Client ID。也可以在 YYB-Go Web 控制台中配置。

### `ql_client_secret`

青龙 OpenAPI Client Secret。也可以在 YYB-Go Web 控制台中配置。

### `yyb_qinglong_server`

**可选。通常不要填写。**

Add-on 会通过 `/addons/self/info` 获取自己的 Supervisor slug，并把 `_` 转成 `-`，自动生成类似：

```text
79931177-yyb-go:8000
```

该值会传给上游 `YYB_QINGLONG_SERVER`，供 YYB-Go 向青龙同步 `YYB_SERVER`。

只有自动发现失败或你明确需要覆盖地址时才填写。

### `yyb_qinglong_repo`

供 YYB-Go 的运行管理页面扫描青龙脚本目录。默认：

```text
SuperNaiBA_YYB-GO-Script,525815266_YYB-Go-Enhanced/scripts
```

多个目录使用英文逗号分隔。

### `yyb_admin_user`

可选。上游原生管理员初始化用户名。

### `yyb_admin_password`

可选。上游原生管理员初始化密码。

如果填写用户名，必须同时填写密码；反之亦然。

### `yyb_cookie_secure`

默认：

```text
false
```

你现在通过：

```text
http://HAOS_IP:8000
```

直接访问，所以保持 `false`。

只有在你自己额外配置 HTTPS 反向代理时才改为 `true`。

## 3. 端口

1.1.0 只有一个服务端口：

```text
容器 8000/tcp -> HAOS 宿主 8000/tcp
```

YYB-Go Web UI 和给青龙使用的 API 都由同一个上游服务提供。

健康检查：

```text
/health
```

## 4. 持久化

Home Assistant 为 App 提供持久化 `/data`。

启动脚本把上游三个可写目录转换为：

```text
/app/resource/db       -> /data/db
/app/resource/avatars  -> /data/avatars
/app/resource/qr       -> /data/qr
```

所以以下内容不会因为容器重建而丢失：

- 微信账号与协议数据库
- Web 用户/认证 SQLite 数据库
- 头像
- 二维码运行数据

上游其余静态资源继续来自镜像，升级时会跟随新的上游版本更新。

## 5. 青龙自动发现

启动阶段使用 Supervisor API：

```text
GET http://supervisor/addons
GET http://supervisor/addons/self/info
```

自动找到青龙和本 App 的内部 DNS 名称。

因此 HAOS 版本不需要普通 Docker Compose 的：

```text
qinglong_default
```

外部 Docker 网络。

自动发现完成后会执行：

```text
unset SUPERVISOR_TOKEN
```

然后才以低权限 `yyb` 用户启动上游进程。

## 6. 从 1.0.x 升级

旧版本配置中的：

```text
web_user
web_password
```

从 1.1.0 起不再使用。

Home Assistant 可能在升级时对旧保存选项给出一次“配置项已不存在”的提示；这是旧配置迁移提示，不代表 YYB-Go 数据丢失。保存一次新版配置即可。

如果你希望保留一个确定的管理员账号，升级前可以在新版配置中填写 `yyb_admin_user` 和 `yyb_admin_password`；否则启动后使用页面注册，第一个注册用户成为管理员。

## 7. 排错

### 日志应看到

正常启动至少应出现：

```text
[YYB-Go Add-on] 已自动发现青龙 Add-on：http://...
[YYB-Go Add-on] YYB-Go HAOS 内网地址：...:8000
[YYB-Go Add-on] 启动 YYB-Go：0.0.0.0:8000
YYB Go service listening on http://0.0.0.0:8000
```

### Web UI 打不开

确认 App 的“网络”页面显示：

```text
8000 -> 8000/tcp
```

然后使用 HAOS 的局域网 IP：

```text
http://HAOS_IP:8000
```

### 自动发现不到青龙

手工填写：

```text
ql_url
```

或者在 YYB-Go Web 控制台的面板连接设置中填写青龙地址、Client ID 和 Client Secret。

### 同步到青龙的 YYB_SERVER 地址不正确

手工填写：

```text
yyb_qinglong_server
```

格式只需要：

```text
<HAOS内部DNS名>:8000
```

不要加 `http://`。

## 8. 安全建议

上游明确说明 `/wx/*` 和 `/wxapp/*` 是供脚本调用的协议接口，不依赖浏览器登录 Cookie。

因此建议：

- 仅在可信局域网使用 HAOS 的 8000 端口。
- 不要直接把 8000 做公网端口转发。
- 如果必须远程访问，优先使用 VPN、Home Assistant 安全访问方案或你自己的 HTTPS 反向代理。

## 9. 固定上游版本

当前 App `1.1.0` 固定构建：

```text
9fc25bad7c099a861876cd78460c496df4fccc85
```

对应上游：

```text
https://github.com/525815266/YYB-Go-Enhanced
```
