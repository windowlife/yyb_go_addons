# YYB-Go Enhanced App 使用说明

## 1. 首次启动

安装并启动后，直接点击 **打开 Web UI**，或者访问：

```text
http://HAOS局域网IP:8000
```

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
