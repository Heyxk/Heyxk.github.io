---
title: 使用Docker来部署Hexo
---

### 用Docker部署Hexo

不得不说，docker真是一把利器，对于我这种强迫症和纠结症患者来说，简直就是福音！

今天就来记录一下使用docker部署hexo的过程。

[本文参考链接](https://fedoryx.github.io/%E5%88%A9%E7%94%A8-GitHub-Hexo-Docker-%E5%BF%AB%E9%80%9F%E6%9E%84%E5%BB%BA%E7%8B%AC%E7%AB%8B%E5%8D%9A%E5%AE%A2-MAC%E7%AF%87/)

**方式一**
docker镜像只包含基础服务，不包含项目

新建目录`blog-hexo`

```shell
mkdir blog-hexo
```

新建`Dockerfile`

```shell
vim Dockerfile
```

文件如下：

```dockerfile
FROM mhart/alpine-node

WORKDIR /app

RUN apk --update --no-progress add git \
 && npm install -g hexo-cli

VOLUME ["/app"]

EXPOSE 4000

CMD ["hexo", "server"]
```

生成镜像：

```shell
docker build -t cutekk/blog-hexo .
```

使用镜像运行一个数据卷容器，初始化Hexo项目目录

```shell
docker run --name hexo-data \
-v $PWD/app:/app \
cutekk/blog-hexo \
sh -c "hexo init . \
&& npm install \
&& npm install hexo-generator-sitemap --save \
&& npm install hexo-generator-feed --save \
&& npm install hexo-deployer-git --save"

```
这一步之后将会在当前目录下产生一个data文件夹，该文件夹即是项目初始化的文件夹

```shell
➜  /home/ubuntu/code/docker/blog-hexo ls app
_config.yml  db.json  node_modules  package.json  package-lock.json  public  scaffolds  source  themes  yarn.lock
```
然后运行一个服务容器

```dockerfile
docker run -d -p 4000:4000 --name hexo --volumes-from hexo-data cutekk/blog-hexo
```
此时服务已经运行，可 `curl localhost:4000` 查看结果。

新增文章

```shell
docker exec -it hexo hexo new "My New Post"
```
会在 `app/source/_post/` 下生成一个 `My-New-Post.md` 文件。

生成静态文件

```shell
docker exec -it hexo hexo g
```
会生成 `app/public` 文件夹，将生成的静态文件放在该目录下。

部署文件

```shell
docker exec -it hexo hexo d
```
在部署之前首先要编辑 `app/_config.yml` 文件。
```yaml
# You can use this:
deploy:
  type: git
  repo: https://github.com/Heyxk/Heyxk.github.io.git
  branch: master
  name: Heyxk
  email: [email]
  message: [message]
  extend_dirs: [extend directory]
```
==注意==：由于这里用的repo地址是https的，所以在部署的时候需要手动输入github用户名和密码。如果不想手动输入，那么需要使用ssh的，这时还需要ssh秘钥，可以将主机的
 `~/.ssh` 文件夹mount到容器的 `/root/.ssh` ，这时容器可以使用主机的秘钥和github通信。这时可能会用到openssh，如果需要openssh依赖，可在Dockerfile `RUN` 命令后加上 `RUN apk --update --no-progress add openssh`

**方式二**
这种方式是将项目直接init到镜像中，将关键的目录挂在到主机上
```dockerfile
FROM mhart/alpine-node

WORKDIR /app

RUN apk --update --no-progress add git \
 && npm install hexo-cli -g \
 && hexo init . \
 && npm install \
 && npm install hexo-generator-sitemap --save \
 && npm install hexo-generator-feed --save \
 && npm install hexo-deployer-git --save

VOLUME ["/app/source", "/app/themes", "/app/scaffolds", "/app/_config.yml"]

EXPOSE 4000

CMD ["hexo", "server"]
```
这种方式生成镜像之后会在镜像中的 `/app` 目录下初始化项目，生成的镜像要比之前大。
在运行容器的时候，要将已有的对应文件放到将要mount的主机目录中，例如放到 `/app` 文件夹下对应的地方

```shell
docker run -d -p 4000:4000 \
-v $PWD/app/source:/app/source \
-v $PWD/app/themes:/app/themes \
-v $PWD/app/scaffolds:/app/scaffolds \
-v $PWD/app_config.yml:/app/_config.yml \
cutekk/blog-hexo
```
如果主机目录中对应文件夹为空，那么mount之后，主机目录会覆盖容器目录，导致容器目录相应目录也为空，可能会导致服务无法启动，所以要确保有相应文件在主机目录中。


