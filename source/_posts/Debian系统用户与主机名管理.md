---
title: Debian 系统用户与主机名管理
date: 2026-05-08 17:00:00
tags: [linux, debian, system-admin]
---

> 本文基于与 Claude Code 的对话整理而成。

## 一、修改主机名

修改主机名最直接的方式是使用 `hostnamectl` 命令：

```bash
sudo hostnamectl set-hostname your-new-hostname
```

执行后需要重启网络服务使变更生效：

```bash
sudo systemctl restart networking
```

**注意**：重启网络服务这一步在 SSH 远程连接（如 Xshell）中容易导致会话假死，建议直接在虚拟机终端中操作。如果必须远程操作，可以合并成一条命令或在 tmux/screen 会话中执行。

最后重启系统确保所有服务都使用新的主机名：

```bash
sudo reboot
```

除了 `hostnamectl`，也可以直接编辑 `/etc/hostname` 文件，但 `hostnamectl` 会同步更新 `/etc/hostname` 和内核中的运行时主机名，更加可靠。

---

## 二、创建新用户

### 1. 使用 adduser 创建用户

Debian 推荐使用 `adduser` 而非 `useradd`——前者是交互式的 Perl 脚本，会自动创建用户主目录、复制骨架文件、并提示设置密码。

```bash
sudo adduser test
```

执行后会依次提示：
- 输入并确认密码
- 填写用户全名、房间号、工作电话等（可直接回车跳过）

`adduser` vs `useradd` 是 Debian 系一个常见的混淆点。`useradd` 是底层二进制命令，行为精简但需要手动指定 `-m` 才会创建主目录。`adduser` 是 Debian 对其的封装，默认行为更友好。日常管理优先用 `adduser`，脚本中两者均可。

### 2. 将用户加入 sudo 组

```bash
sudo usermod -aG sudo test
```

参数说明：`-a`（append）确保追加到附加组而非覆盖，`-G` 指定附加组。如果漏掉 `-a`，用户会被从其他附加组中移除，可能导致权限异常。这条命令的效果等价于将该用户提升为管理员。

### 3. 验证 sudo 权限

```bash
sudo -l -U test
```

输出末尾若显示 `(ALL : ALL) ALL`，说明该用户已拥有完整的 sudo 权限。

`sudo -l` 列出当前用户可以执行哪些命令，加上 `-U` 可以指定查看其他用户。这个命令在排查权限问题时非常实用。

---

## 三、删除用户

删除用户同时清理其主目录：

```bash
sudo deluser --remove-home test
```

`deluser` 同样来自 Debian 的工具链（对应 `userdel`）。`--remove-home` 会一并删除用户主目录和邮件 spool。如果用户仍有运行中的进程，建议先 `pkill -u test` 再删除。如需保留用户数据，去掉 `--remove-home` 即可，主目录会保留在 `/home/test`。

---

## 四、补充：SSH 配置

修改主机名后，如果该机器通过 SSH 对外提供服务，别忘了检查 SSH 配置：

```bash
vim /etc/ssh/sshd_config
```

与主机名直接相关的一般不需要改，但如果你修改主机名是为了配合内网 DNS 或证书体系，可能需要同步调整 SSH 的 `ListenAddress` 或其他相关配置项。

> 本文内容基于 Claude AI 对话整理生成，适用于 Debian 及 Ubuntu 等衍生发行版。操作涉及系统级变更，建议在测试环境中先行验证。
