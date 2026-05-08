# soup的blog

基于 [Hexo](https://hexo.io) + [maoblog](https://github.com/muzuiyo/hexo-theme-maoblog) 主题搭建的个人博客。

**https://blog.soooup.org**

## 本地开发

```bash
git clone --recurse-submodules https://github.com/hanbing1122/soup-blog.git
cd soup-blog
npm install
hexo server
```

打开 http://localhost:4000

## 写文章

```bash
hexo new "文章标题"
```

文章在 `source/_posts/` 目录下，Markdown 格式。

## 部署

部署到 Cloudflare Pages：

```bash
hexo generate
npx wrangler pages deploy public --project-name=soup-blog
```

## 主题

使用 [hexo-theme-maoblog](https://github.com/muzuiyo/hexo-theme-maoblog)，通过 git submodule 管理。

```bash
# 更新主题
cd themes/maoblog && git pull && cd ../..
```
