---
title: Mac 版微信双开 4.0.6.17 版（最详细教程）
date: 2026-05-08 18:00:00
tags: [mac, tutorial]
---

## 准备工作

开始之前，先退掉你已经登录的所有微信，并用 `Cmd + Q` 彻底结束程序。

不会操作的话，直接在程序坞上找到已登录的微信，右键 → 退出。

---

## 第一步：清理旧的双开副本（没有做过的跳过）

如果你之前做过双开，或者复制过 `WeChat2.app`，需要先清理掉旧的。

打开访达 → 应用程序 → 找到 `WeChat2.app`，选中后右键 → 移到废纸篓（有的电脑会要求验证指纹或输入开机密码）。

没有做过双开的，直接跳到第二步。

---

## 第二步：复制微信应用包

打开终端，执行以下命令：

```bash
sudo cp -R /Applications/WeChat.app /Applications/WeChat2.app
```

回车后会出现 `Password` 提示。

---

## 第三步：输入开机密码

直接输入你的 Mac 开机密码。

> **注意**：输入密码时终端不会有任何显示（不会出现 `***`），这是正常的安全设计。确保输入正确后直接回车即可。

密码验证通过后，终端会回到命令等待状态。

---

## 第四步：修改应用标识符

执行以下命令（这是一整条，直接复制粘贴）：

```bash
sudo /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.tencent.xinWeChat2" /Applications/WeChat2.app/Contents/Info.plist
```

> **常见报错**：如果这步报错，通常是因为没有装 Xcode Command Line Tools。先执行 `xcode-select --install` 安装后再重试。

---

## 第五步：重签应用

执行以下命令对新副本进行代码签名：

```bash
sudo codesign --force --deep --sign - /Applications/WeChat2.app
```

回车后自动生成一行签名信息，没有报错就是成功了。

---

## 第六步：打开原始微信

在应用程序中找到原始的微信，手动双击打开并登录。

---

## 第七步：命令启动第二个微信

执行以下命令打开第二个微信：

```bash
nohup /Applications/WeChat2.app/Contents/MacOS/WeChat >/dev/null 2>&1 &
```

两个微信就都成功打开了。

---

## 第八步：固定第二个微信到程序坞

在程序坞上找到第二个微信的图标，右键 → 选项 → 在程序坞中保留。

以后就可以直接从程序坞点击打开第二个微信，不需要再输命令了。
