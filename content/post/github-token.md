---
date: 2024-02-24 12:58:15
lastmod: 2024-02-24 12:58:15
title: "GitHub 不同 token 的区别和用法"
author: "k"
# weight: 1
# aliases: ["/first"]
tags: []
categories: []
draft: false
comments: true
description: ""
# hidemeta: false
# showToc: false
# TocOpen: false
# canonicalURL: "https://canonical.url/to/page"
# disableHLJS: true # to disable highlightjs
# disableShare: false
# disableHLJS: false
# hideSummary: false
# searchHidden: true
# ShowReadingTime: true
# ShowBreadCrumbs: true
# ShowPostNavLinks: true
# ShowWordCount: true
# ShowRssButtonInSectionTermList: true
# UseHugoToc: true
# cover:
#     image: "<image path/url>" # image path/url
#     alt: "<alt text>" # alt text
#     caption: "<text>" # display caption under cover
#     relative: false # when using page bundles set this to true
#     hidden: true # only hide on current single page
---

<!-- Feb 24, 2024 -->

## github 三种不同的 token

### `GITHUB_TOKEN`

该 token 为用于 GitHub actions 的内置 token, 运行 actions 自动生成，可用于对执行 actions 的仓库进行访问操作，直接使用 `secrets.GITHUB_TOKEN` 即可在 GitHub actions 中使用。

GitHub Actions 使用方式：

```yaml
- name: Deploy
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }} # 另外还支持 deploy_key 和 personal access token (https://github.com/peaceiris/actions-gh-pages#readme)
```

### `deploy_key`

该 key 针对仓库，是公钥加私钥形式，可使用 SSH key, 配置方式如下

1. 生成 SSH Key
打开 terminal 输入下面的命令生成 id_rsa 和 id_rsa.pub 文件：

```bash
ssh-keygen -t rsa -C me@xxx.com
```

其中 <me@xxx.com> 就是 GitHub 账号的邮箱。
2. 填写 Deploy Keys 和 Secrets

打开源码仓库，在设置中找到「Secrets」

> 第 1/3 步：添加 DEPLOY_KEY 内容是 id_rsa 文件的全部内容。
>
> 第 2/3 步：添加 EMAIL 内容是 GitHub 邮箱。
>
> 第 3/3 步：添加 NAME 内容是 GitHub 账号名。

打开 deploy 目标仓库，在设置中找到「Deploy Keys」

> 第 1/1 步：添加 deploy_key.pub 内容是 id_rsa.pub 文件的全部内容。

GitHub Actions 使用方式：

```yaml
- name: Deploy
        uses: peaceiris/actions-gh-pages@v3
        with:
          deploy_key: ${{ secrets.DEPLOY_KEY }} # 另外还支持 github_token 和 personal_token (https://github.com/peaceiris/actions-gh-pages#readme)
```

### `personal access token`

token 的生成需要到这里：个人头像 -> Settings -> Developer settings -> Personal access tokens，点击 Generate new token。这一步需要输入密码，然后可以根据需要定制 token 的权限

该 token 的权限最大，可对账户进行操作，在生成时可以选在 token 的权限范围，越小越好。

GitHub Actions 使用方式 (将生成的 token 添加到对应仓库的 secret 中):

```yaml
- name: Deploy
        uses: peaceiris/actions-gh-pages@v3
        with:
          personal_token: ${{ secrets.PERSONAL_ACCESS_KEY_TO_DEPLOY_BLOG }} # 另外还支持 github_token 和 deploy_key (https://github.com/peaceiris/actions-gh-pages#readme)
```
