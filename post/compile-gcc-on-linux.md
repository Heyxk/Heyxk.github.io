---
date: 2022-09-27 13:33:25
title: "linux降低gcc版本, 高版本gcc(gcc10.3.1)下编译低版本gcc(gcc4.8.5), 设置gcc版本共存"
author: "k"
description: "linux降低gcc版本, 高版本gcc(gcc10.3.1)下编译低版本gcc(gcc4.8.5), 设置gcc版本共存"
keywords: ["linux", "gcc", "gcc降版本", "编译gcc", "gcc4.8.5"]
tags: ["linux", "gcc"]
categories: ["linux"]
comment: true
toc: true
draft: false
---

<!-- # linux降低gcc版本, 高版本gcc(gcc10.3.1)下编译低版本gcc(gcc4.8.5), 设置gcc版本共存 -->

### gcc4.8.5 源码下载
```bash
wget ftp://ftp.gnu.org/gnu/gcc/gcc-4.8.5/gcc-4.8.5.tar.gz
tar xzf gcc-4.8.5.tar.gz
```

### 安装静态库
```bash
yum install libstdc++-static
```

### 下载依赖
```bash
cd gcc-4.8.5
./contrib/download_prerequisites
```

### 编译
```bash
mkdir build
cd build
# 生成makefile, 这些参数可以用已有的gcc参数 gcc -v 可用看到, 也可以自己修改需要的参数
# prefix指定安装路径
../configure --prefix=/opt/gcc4.8.5 --enable-bootstrap --enable-shared --enable-threads=posix --enable-checking=release --with-system-zlib --enable-__cxa_atexit --disable-libunwind-exceptions --enable-gnu-unique-object --enable-linker-build-id --with-linker-hash-style=gnu --enable-languages=c,c++ --enable-plugin --enable-initfini-array --disable-libgcj --enable-gnu-indirect-function --with-tune=generic --disable-multilib --with-arch_32=x86-64 --build=x86_64-linux-gnu

# 16线程编译, 编译过程耗时较长
make -j16

# 安装
make install
```

### 错误解决
#### 错误1
```shell
In file included from ../../gcc/cp/except.c:1008:
cfns.gperf:101:1: error: ‘const char* libc_name_p(const char*, unsigned int)’ redeclared inline with ‘gnu_inline’ attribute
cfns.gperf:26:14: note: ‘const char* libc_name_p(const char*, unsigned int)’ previously declared here
cfns.gperf:26:14: warning: inline function ‘const char* libc_name_p(const char*, unsigned int)’ used but never defined
make[3]: *** [Makefile:1059: cp/except.o] Error 1
make[3]: Leaving directory '/root/gcc-4.8.5-fixed/build/gcc'
make[2]: *** [Makefile:4163: all-stage1-gcc] Error 2
make[2]: Leaving directory '/root/gcc-4.8.5-fixed/build'
make[1]: *** [Makefile:20822: stage1-bubble] Error 2
make[1]: Leaving directory '/root/gcc-4.8.5-fixed/build'
make: *** [Makefile:892: all] Error 2
```
[patch地址](https://gcc.gnu.org/git/?p=gcc.git;a=commitdiff;h=ec1cc0263f156f70693a62cf17b254a0029f4852)

#### 错误2
```shell
In file included from ../../../libgcc/unwind-dw2.c:405:0:
./md-unwind-support.h: In function ‘x86_64_fallback_frame_state’:
./md-unwind-support.h:65:47: error: dereferencing pointer to incomplete type
       sc = (struct sigcontext *) (void *) &uc_->uc_mcontext;
                                               ^
make[3]: *** [../../../libgcc/shared-object.mk:14: unwind-dw2.o] Error 1
make[3]: Leaving directory '/root/gcc-4.8.5-fixed/build/x86_64-linux-gnu/libgcc'
make[2]: *** [Makefile:16943: all-stage1-target-libgcc] Error 2
make[2]: Leaving directory '/root/gcc-4.8.5-fixed/build'
make[1]: *** [Makefile:20822: stage1-bubble] Error 2
make[1]: Leaving directory '/root/gcc-4.8.5-fixed/build'
make: *** [Makefile:892: all] Error 2
```
[patch地址](https://gcc.gnu.org/git/?p=gcc.git;a=commitdiff;h=16b277761b432510ad6dcf72d877ae72b5f0a4b7)


#### 错误3
```shell
../../../../libsanitizer/asan/asan_linux.cc: In function ‘bool __asan::AsanInterceptsSignal(int)’:
../../../../libsanitizer/asan/asan_linux.cc:95:20: error: ‘SIGSEGV’ was not declared in this scope
   return signum == SIGSEGV && flags()->handle_segv;
                    ^
../../../../libsanitizer/asan/asan_linux.cc:96:1: warning: control reaches end of non-void function [-Wreturn-type]
 }
 ^
make[4]: *** [Makefile:441: asan_linux.lo] Error 1
make[4]: Leaving directory '/root/gcc-4.8.5-fixed/build/x86_64-linux-gnu/libsanitizer/asan'
make[3]: *** [Makefile:326: all-recursive] Error 1
make[3]: Leaving directory '/root/gcc-4.8.5-fixed/build/x86_64-linux-gnu/libsanitizer'
make[2]: *** [Makefile:15546: all-stage1-target-libsanitizer] Error 2
make[2]: Leaving directory '/root/gcc-4.8.5-fixed/build'
make[1]: *** [Makefile:20822: stage1-bubble] Error 2
make[1]: Leaving directory '/root/gcc-4.8.5-fixed/build'
make: *** [Makefile:892: all] Error 2
```
[patch地址](https://patchwork.ozlabs.org/project/gcc/patch/6824253.3U2boEivI2@devpool21)


#### 错误4
```shell
../../../../libsanitizer/tsan/tsan_platform_linux.cc: In function ‘int __tsan::ExtractResolvFDs(void*, int*, int)’:
../../../../libsanitizer/tsan/tsan_platform_linux.cc:295:16: error: ‘statp’ was not declared in this scope
   __res_state *statp = (__res_state*)state;
                ^
../../../../libsanitizer/tsan/tsan_platform_linux.cc:295:37: error: expected primary-expression before ‘)’ token
   __res_state *statp = (__res_state*)state;
                                     ^
../../../../libsanitizer/tsan/tsan_platform_linux.cc:295:38: error: expected ‘;’ before ‘state’
   __res_state *statp = (__res_state*)state;
                                      ^
make[4]: *** [Makefile:475: tsan_platform_linux.lo] Error 1
make[4]: Leaving directory '/root/gcc-4.8.5-fixed/build/x86_64-linux-gnu/libsanitizer/tsan'
make[3]: *** [Makefile:326: all-recursive] Error 1
make[3]: Leaving directory '/root/gcc-4.8.5-fixed/build/x86_64-linux-gnu/libsanitizer'
make[2]: *** [Makefile:15546: all-stage1-target-libsanitizer] Error 2
make[2]: Leaving directory '/root/gcc-4.8.5-fixed/build'
make[1]: *** [Makefile:20822: stage1-bubble] Error 2
make[1]: Leaving directory '/root/gcc-4.8.5-fixed/build'
make: *** [Makefile:892: all] Error 2
```
[patch地址](https://gcc.gnu.org/git/?p=gcc.git;a=commitdiff;h=144e36a796e9f293817c6d0a3413fa3fcc51c7ad)


#### ARM平台编译问题
arm平台上编译会因为依赖版本低, 导致编译失败
```diff
- MPFR=mpfr-2.4.2
- GMP=gmp-4.3.2
- MPC=mpc-0.8.1
+ MPFR=mpfr-4.1.0
+ GMP=gmp-6.2.1
+ MPC=mpc-1.2.1
```
修改`contrib/download_prerequisites` 文件, 升级依赖版本即可


### gcc版本共存环境变量配置
#### 切换gcc版本到gcc4.8.5

##### 关键配置
- `PATH` , 配置gcc命令的路径, 若指定gcc版本, 需将gcc路径配置在系统原有PATH之前
```shell
# gcc
GCCDIR=/opt/gcc4.8.5
# path
PATH=$GCCDIR/bin:$PATH
export PATH
```
- `LIBRARY_PATH` , 该环境变量配置程序编译时库查找路径
```shell
LIBRARY_PATH=$GCCDIR/lib64:$LIBRARY_PATH
export LIBRARY_PATH
```
- `LD_LIBRARY_PATH`, 该环境变量配置程序运行时库查找路径
```shell
LD_LIBRARY_PATH=$GCCDIR/lib64:$LD_LIBRARY_PA
export LD_LIBRARY_PATH
```


### 提供一份修改好的代码

[gcc-4.8.5-fixed](https://github.com/Heyxk/gcc-4.8.5-fixed)
