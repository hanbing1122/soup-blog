---
title: 小米临时 Root 漏洞深度分析
date: 2026-05-08 15:00:00
tags: [security, android, selinux, analysis]
---

> 本文基于与 Claude Code 的多轮安全研究对话整理而成，标注 🤖 的部分为 AI 分析内容。

## 一、背景知识：Android 上的 SELinux

### 什么是 SELinux

SELinux（Security-Enhanced Linux）是一套**强制访问控制（MAC）**机制，由 NSA 开发，后被整合进 Linux 内核。Android 从 4.3 开始引入，4.4 起全面强制执行。

🤖 **AI 分析**：传统 Linux 用的是 DAC（自主访问控制）——文件所有者说了算。SELinux 在此之上加了一层：即使是 root（uid=0），也受 SELinux 策略约束。这是理解整个漏洞链条的基础——即使拿到了 uid=0，如果 SELinux 域受限，很多操作仍然会被拒绝。

### SELinux 的工作模式

| 模式 | 行为 |
|------|------|
| **Enforcing** | 违规操作直接拒绝 + 记录日志（生产设备默认） |
| **Permissive** | 只记录日志，不拦截（调试用） |

🤖 **关键洞察**：Enforcing 模式下，即使是 root 进程访问不该访问的文件，也会被 SELinux 拒绝。这是为什么「关闭 SELinux」是整个提权链条中不可或缺的一环。

### Android 的安全域体系

Android 的每一个进程和文件都有 SELinux 标签（label），格式为 `user:role:type:sensitivity`，其中最关键的是 `type` 字段。

进程示例：

| 域 | 描述 |
|----|------|
| `untrusted_app` | 普通第三方 App |
| `shell` | adb shell |
| `system_server` | 系统服务 |
| `isolated_app` | WebView 渲染进程（完全沙盒） |

---

## 二、小米临时 Root 的真实原理

🤖 **AI 分析**：很多人以为小米的「临时 Root」是厂商主动开放的能力，但实际情况恰恰相反——它是两个独立漏洞的组合利用，属于真正意义上的安全漏洞，而非厂商「留的后门」。这两个漏洞缺一不可——单独使用任何一个都无法完成提权。

### 漏洞结构总览

```
[漏洞一] Fastboot ABL 参数注入 → 关闭 SELinux
         +
[漏洞二] mqsas Binder 服务     → 以 root 执行任意命令
         =
[完整 Root]
```

### 漏洞一：Fastboot ABL 参数注入

**漏洞位置**：ABL（Android Bootloader）的 `LinuxLoader.efi` 中，fastboot 命令分发循环

**触发命令**：
```bash
fastboot oem set-gpu-preemption-value 0 androidboot.selinux=permissive
```

🤖 **漏洞原理**：这是一个经典的「命令参数注入」。ABL 本意是接收一个 GPU 抢占值（如 `0`），但由于参数解析循环在遇到第一个非空格字符后立即退出，字符串中间的空格和后面拼接的 `androidboot.selinux=permissive` 完全未被检查，被一起拼接进了内核启动参数。

**后果**：一次注入 = SELinux 从 Enforcing 降级为 Permissive。用户无感知——设置界面仍显示「Enforcing」，因为 UI 读的是运行时状态，而该注入在 init 早期就已生效。

### 漏洞二：mqsas Binder 服务

**服务身份**：`miui.mqsas.IMQSNative`，以 root（uid=0）权限运行，是小米 HyperOS 自带的系统级诊断服务。

**核心缺陷**：`BnMQSNative::onTransact` 是一个包含 22 个 case 的 switch 函数，映射了 22 个 AIDL 接口方法。其中 **case 21（captureLogByRunCommand）** 接受任意命令名和参数，无白名单/黑名单过滤。

**调用方式**：
```bash
adb shell service call miui.mqsas.IMQSNative 21 \
  i32 1 s16 "ksud" i32 1 s16 'late-load' \
  s16 '/sdcard/ksulog.txt' i32 60
```

🤖 **AI 分析**：这个接口本质上是把一个 root shell 包装成 Binder API 对外提供——任何能连接到这个服务的调用者都能以 root 身份执行任意命令。设计意图是「让售后工程师能远程采集诊断日志」，但实现上完全没有任何调用者身份校验。

### 为什么要两个漏洞组合

| | 单独使用 | 缺陷 |
|------|---------|------|
| 仅 fastboot 注入 | SELinux 已关闭 | 没有执行权限，拿不到 root shell |
| 仅调用 mqsas | uid=0 执行命令 | SELinux Enforcing 下层权限受限 |
| **两者组合** | ✓ SELinux Permissive + ✓ root 执行权限 | **完整 root 能力** |

### 完整利用链

```
[Fastboot 阶段]
fastboot oem set-gpu-preemption-value 0 androidboot.selinux=permissive
  └→ ABL 参数注入，SELinux → Permissive

fastboot continue
  └→ 正常启动系统，但 SELinux 已是 Permissive

[系统运行阶段]
adb push ksud /data/local/tmp/
  └→ 推送 KernelSU 守护程序

service call miui.mqsas.IMQSNative 21 ...
  └→ 以 uid=0 执行 ksud，加载 KernelSU 内核模块
       └→ 获得完整 root 管理能力
```

🤖 **为什么是「临时」的**：KernelSU 内核模块只加载在内存里，重启后消失；SELinux 状态随内核重置；每次开机都需要重新走一遍整个利用链。

### 漏洞修复

🤖 小米已在澎湃 OS 3.0.301 测试版中完整封堵：
- 修复了 Fastboot 命令参数过滤
- 修复了 mqsas 服务权限校验
- 新增 efisp 分区签名校验

**2026 年 2 月及以上安全补丁的设备，漏洞入口已被彻底堵死。**

---

## 三、iOS 有类似漏洞吗？

🤖 **AI 分析**：这个对比非常有意思。iOS 历史上确实存在结构上类似的漏洞，但漏洞层级和影响面完全不同。

### checkm8：iOS 的 BootROM 级漏洞

checkm8 利用的是 **BootROM（SecureROM）** 中的 USB 代码 use-after-free 漏洞。BootROM 是设备开机时最先执行的代码，**固化在芯片中，无法通过软件更新修补**。

### 两者对比

| | 小米（fastboot + mqsas） | iOS（checkm8） |
|------|------|------|
| **漏洞层级** | ABL 软件层 + 系统服务层 | BootROM 硬件层 |
| **漏洞类型** | 参数注入 + 权限校验缺失 | USB 代码 use-after-free |
| **能否打补丁** | ✅ 已修复 | ❌ 硬件固化，永不可修 |
| **需要物理接触** | ✅ USB + fastboot | ✅ USB + DFU 模式 |
| **能否远程利用** | ❌ 不能 | ❌ 不能 |
| **影响范围** | 特定小米高通机型 | iPhone 4S ~ iPhone X（数亿台） |

### iOS 为什么没有「类 mqsas」的系统服务漏洞？

🤖 三个关键原因：
1. **iOS 没有暴露给 adb shell 的高权限系统服务**——所有守护进程通过 XPC 通信，每个服务都有严格的 entitlement 检查
2. **沙盒 + entitlement 体系比 SELinux 更细粒度**，且没有「permissive 模式」
3. **签名验证从 BootROM 贯穿整个启动链**，没有 ABL 那种「oem 自定义命令解析」入口

---

## 四、小米为什么会犯 mqsas 这个错？

🤖 **AI 分析**：这个问题值得从工程和组织角度深入探讨。不是小米独有的问题，而是 Android 厂商定制层的通病。

### 技术上犯了三个错

**错误 1：任意命令执行，没有白名单**

`captureLogByRunCommand` 的设计本意是让售后工程师采集日志，但实现上是透传任意字符串给 shell 执行。正确的做法应该是枚举允许执行的命令集合（logcat、bugreport、dmesg），而不是把 root shell 包装成 API 对外提供。

**错误 2：以 root 运行，没有降权**

整个 MQSNative 服务进程跑在 uid=0 下。正确做法是服务本身跑在低权限域，对需要高权限的操作做精确的 capability 授权。

**错误 3：调用者身份校验缺失**

SELinux 策略做了一半——限制了普通 App，但没有限制 adb shell。正确做法是在 Binder 服务内部用 `Binder.getCallingUid()` 检查调用方，或通过 SELinux 策略精确限定哪些域可以调用这个接口。

### 流程上为什么没被发现

**开发文化**： MIUI 早期基因是「快速迭代、功能优先」。诊断服务这类内部工具被视为「only 内部用，不对外」，写代码的人根本没有把它当攻击面来考虑。

**威胁模型盲区**：开发者的隐性假设是「这个接口只有售后系统会调用」，但没有在代码层面强制执行。设计时的假设和实现时的约束之间存在断层——这是非常常见的工程错误。

**SELinux 事后补**：Android 厂商定制系统的普遍问题是新功能先做，SELinux 策略跟着补，而且往往为了让功能跑通而写得过于宽松。对应组件通常是一些负责系统稳定性监控、性能优化的系统级组件，安全审查不一定覆盖。

**安全测试缺位**：QA 测的是「功能是否正常」（能不能跑日志），不会测「攻击者如果这样调用会怎样」。安全团队的渗透测试往往聚焦用户态攻击面，内部诊断组件不一定纳入范围。

### 这不是小米独有的问题

```
高通 com.qti.diagservices   → 历史上也出过类似问题
三星 RIL 相关服务           → 多次暴露高权限接口滥用
MediaTek 工厂模式           → 出厂测试接口在零售设备上保留
```

🤖 **根本原因**：诊断/运维需求 vs. 安全边界之间的张力在厂商定制层没有被认真处理。AOSP 本身没有这个问题——这个洞是厂商自己加的。每一步单独看都是可以理解的工程妥协，但叠在一起就成了完整的提权路径。

---

## 五、总结与思考

🤖 **AI 总结**：这个案例给安全工程的启示：

1. **内部工具也是攻击面**：任何以 root 运行、接受外部输入的服务，无论设计意图多么「内部」，都必须做调用者身份校验和输入过滤
2. **SELinux 不是万能的**：策略写得宽松等于没写；关闭 SELinux 本身就是最大的安全漏洞
3. **安全需要贯穿开发全流程**：从威胁建模、代码审查、到针对性的渗透测试——尤其是厂商定制层，因为 AOSP 本身经过 Google 的严格审查，而厂商加的东西往往审查不足
4. **便利性和安全性之间的平衡必须在前端解决**：不能在代码层面留一个「方便售后」的 root 后门然后指望靠 SELinux 补救

> 🤖 本文内容基于 Claude AI 对话分析生成，仅供安全研究学习参考。漏洞细节已在最新系统版本中修复。
