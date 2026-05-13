---
date: 2022-09-27 13:28:22
title: "linux下new/malloc内存分配失败问题分析 - mmap系统调用返回ENOMEM"
author: "k"
description: "linux下new/malloc内存分配失败问题分析 - mmap系统调用返回ENOMEM"
keywords: ["linux", "C/C++", "mmap", "ENOMEM", "new", "malloc"]
tags: ["linux", "C/C++"]
categories: ["C/C++"]
comment: true
toc: true
draft: false
---

<!-- # linux下new/malloc内存分配失败问题分析 - mmap系统调用返回ENOMEM -->
## 问题背景
公司新产品需要高性能业务平台, 需要对现有的平台进行性能优化, 进行一系列优化后, 性能提升50%左右, 但是做性能测试时发现, 进程存在使用 `new/malloc` 分配内存时失败的情况, 导致进程coredump, 无法完成稳定性行测试, 于是通过 `valgrind` 和 `strace` 等工具分析定位高负载情况下, 进程分配内存失败问题.

## 问题分析过程

### review优化代码
在做性能测试时, 数据是通过将量打到本机cpu消耗70%时的数据作为对比数据, 使用优化后的版本进行70%cpu压测时, 跑一段时间后, 进程会报告内存分配失败问题. 遇到该问题时首先想到, 可能是优化部分代码有问题, 毕竟做了多线程优化, 可能是有数据竞争问题, 导致跑一段时间内存被破坏了, 这么怀疑的原因是, *使用优化前版本跑70%cpu压测稳定24小时不会出现此问题* , 于是乎, 对代码进行review, 翻来覆去看了几遍, 没发现有异常地方.

### 降低gcc版本
进行过代码review之后, 没有发现有问题的地方. 于是想到另一个方面, 本次优化还有一个变化是迁移了系统, 从centos迁移到了openEuler系统, openEuler系统的gcc(gcc10)版本比之前使用的
gcc(4.8.5)高出很多, 由于平台代码历史有二十多年, 所以使用的还是`gnu++98` 标准写的, 其中的有些语法在高版本上编译不过, 需要修改, 还有很多写法不规范的地方, 在gcc10开启 `-O2` 优化下, 进程会重启, 例如非 `void` 函数没写返回值等. 所以怀疑是gcc版本太高, 代码里不规范的地方太多, 没有修改完, 所以运行会有问题, 因此在openEuler系统上编译了gcc4.8.5, 使用低版本gcc进行代码编译, 废了一番劲编译好gcc之后, 使用低版本gcc编译平台代码, 进行性能测试, 发现还是会出现内存分配失败的情况, 这么看来, 该问题和gcc版本没有关系.

### 分析core文件
尝试过回退gcc版本后问题依旧, 于是还是来分析core文件, 分析core文件发现几个现象:
- 出core的地方不同
- 几乎都是关于内存分配的地方
core一例
```shell
[Current thread is 1 (Thread 0x7f0d967fc640 (LWP 55019))]
(gdb) bt
#0  0x00007f0dfc9951be in TemplateClass::TemplateClass (this=0x10) at TemplateClass.hpp:54
#1  0x00007f0dfc997878 in UEInstance::UEInstance (this=0x10) at UEInstance.hpp:11
#2  0x00007f0dfc998fdf in __gnu_cxx::new_allocator<UEInstance>::construct (this=0x7f0d967faf67, __p=0x10, __val=...)
    at /opt/gcc4.8.5/include/c++/4.8.5/ext/new_allocator.h:130
#3  0x00007f0dfc993a10 in std::list<UEInstance, std::allocator<UEInstance> >::_M_create_node (this=0x232488e8,
    __x=...) at /opt/gcc4.8.5/include/c++/4.8.5/bits/stl_list.h:487
#4  0x00007f0dfc991c19 in std::list<UEInstance, std::allocator<UEInstance> >::_M_insert (this=0x232488e8,
    __position=..., __x=...) at /opt/gcc4.8.5/include/c++/4.8.5/bits/stl_list.h:1553
#5  0x00007f0dfc99030e in std::list<UEInstance, std::allocator<UEInstance> >::push_back (this=0x232488e8, __x=...)
    at /opt/gcc4.8.5/include/c++/4.8.5/bits/stl_list.h:1016
#6  0x00007f0dfc97e005 in SessionProcess::createUEInstance (this=0x23248700, ueName=Calling) at SessionProcess.C:854
```

```shell
(gdb) bt
#0  ___pthread_mutex_trylock (mutex=mutex@entry=0x28e8) at pthread_mutex_trylock.c:34
#1  0x00007f3c10ea81e4 in malloc_mutex_trylock_final (mutex=0x28a8) at include/jemalloc/internal/mutex.h:157
#2  malloc_mutex_lock (mutex=0x28a8, tsdn=0x7f3bb93febf0) at include/jemalloc/internal/mutex.h:216
#3  je_tcache_arena_associate (tsdn=0x7f3bb93febf0, tcache_slow=0x7f3bb93fecf0, tcache=0x7f3bb93fef48, arena=0x0) at src/tcache.c:588
#4  0x00007f3c10ea959e in arena_choose_impl (arena=0x0, internal=false, tsd=0x7f3bb93febf0) at include/jemalloc/internal/jemalloc_internal_inlines_b.h:60
#5  arena_choose (arena=0x0, tsd=0x7f3bb93febf0) at include/jemalloc/internal/jemalloc_internal_inlines_b.h:88
#6  je_tsd_tcache_data_init (tsd=tsd@entry=0x7f3bb93febf0) at src/tcache.c:740
#7  0x00007f3c10ea9753 in je_tsd_tcache_enabled_data_init (tsd=tsd@entry=0x7f3bb93febf0) at src/tcache.c:644
#8  0x00007f3c10eab1b9 in tsd_data_init (tsd=0x7f3bb93febf0) at src/tsd.c:244
#9  je_tsd_fetch_slow (tsd=0x7f3bb93febf0, minimal=minimal@entry=false) at src/tsd.c:311
#10 0x00007f3c10e53823 in tsd_fetch_impl (init=true, minimal=false) at include/jemalloc/internal/tsd.h:422
#11 tsd_fetch () at include/jemalloc/internal/tsd.h:448
#12 imalloc (dopts=<synthetic pointer>, sopts=<synthetic pointer>) at src/jemalloc.c:2681
#13 je_malloc_default (size=32) at src/jemalloc.c:2722
#14 0x000000000070df73 in mynew (size=32) at unix/memtest.C:30
#15 0x0000000000aea452 in TAs_slp::run (this=0x7f3bc24b1200, ptr=0x2281e770 <buffer_TMsg+1200>) at lib/as_slp.C:126
#16 0x00000000006587c8 in CWorkerThread::run (this=0x7f3bc553a020) at scmectrl/threadCom.C:149
#17 0x0000000000656b5a in CThread::ThreadFunction (point=0x7f3bc553a020) at scmectrl/threadBase.C:33
#18 0x00007f3c10ad132a in start_thread (arg=<optimized out>) at pthread_create.c:443
#19 0x00007f3c10b53370 in clone3 () at ../sysdeps/unix/sysv/linux/x86_64/clone3.S:81
(gdb) f 15
#15 0x0000000000aea452 in TAs_slp::run (this=0x7f3bc24b1200, ptr=0x2281e770 <buffer_TMsg+1200>) at lib/as_slp.C:126
warning: Source file is more recent than executable.
Python Exception <class 'UnicodeDecodeError'>: 'utf-8' codec can't decode byte 0xbd in position 4955: invalid start byte
126                     cm = new TComponentManager(this);
(gdb)
```

看了几百个core, 发生错误的地方不尽相同, 没有发现明显的规律, 这使得问题分析变得困难起来, 因为之前就有定位过一个类似的情况: 进程在随机的地方coredump, 没有规律, 最后找了很久才找到是业务使用了已销毁的元素, 导致内存被破坏, 这种难点在于进程不会在代码有问题的地方重启, 而是继续跑一段时间, 访问到了被破坏的内存, 才会重启.
还是怀疑到了修改的代码身上, 但是对修改的代码反复检查, 实在是找不到值得怀疑的地方.
于是观察进程重启时的情况, 发现以下几个现象:
- 进程重启的数据cpu占用会迅速上升, 内存占用会迅速上升
- 进程报告分配内存失败时, 内存剩余还很多, 不是内存用尽问题

基于这两个现象, 使用valgrind跟踪进程运行情况, 未发现进程有内存泄漏的情况.

没有好的思路, 只能去网上检索相关问题, 大概找到了一下几个会影响进程申请内存的配置
- ulimit -v
> 虚拟内存限制, 该配置会影响进程虚拟地址空间的大小, 如果过小的话, 虚拟地址空间不足, 会导致申请不到内存问题
- overcommit_memory
> 0 表示内核将检查是否有足够的可用内存供应用进程使用, 如果有足够的可用内存, 内存申请允许, 否则, 内存申请失败, 并把错误返回给应用进程.
> 1 表示内核允许分配所有的物理内存, 而不管当前的内存状态如何.
> 2 表示内核允许分配超过所有物理内存和交换空间总和的内存.

检查系统设置的虚拟内存限制为`unlimited`, `overcommit_memory` 配置为0, 遂将`overcommit_memory` 修改为1, 测试问题依旧.

经过以上分析后, 已有情况如下:
**配置:**
```shell
$ ulimit -a
real-time non-blocking time  (microseconds, -R) unlimited
core file size              (blocks, -c) unlimited
data seg size               (kbytes, -d) unlimited
scheduling priority                 (-e) 0
file size                   (blocks, -f) unlimited
pending signals                     (-i) 127250
max locked memory           (kbytes, -l) 64
max memory size             (kbytes, -m) unlimited
open files                          (-n) 32768
pipe size                (512 bytes, -p) 8
POSIX message queues         (bytes, -q) 819200
real-time priority                  (-r) 0
stack size                  (kbytes, -s) 8192
cpu time                   (seconds, -t) unlimited
max user processes                  (-u) 127250
virtual memory              (kbytes, -v) unlimited
file locks                          (-x) unlimited

$ cat /proc/sys/vm/overcommit_memory
1
```
**现象:**
- 内存充足, new/malloc失败
- 同等压力下进程数少更容易出现
- 启动终端下ulimit无限制

### 缩小问题范围
分析到这里, 并没有其他好的思路, 于是准备缩小问题范围.
检查问题是新引入还是旧版本就存在: 由于之前测试过程中, 一直采用的是cpu压测到70%, 但是存在的问题是, 旧版本性能跑不到新版本的量, 既然是存在内存分配问题, 那么如果将旧版本压测到新版本的量, 是否会出现此问题呢?, 于是马上进行了测试, 果然, 旧版本压力上去后, 也出现了这个情况, 且core基本类似. 说明该问题是一直存在的问题, 只是以前没有跑到那么大量, 没有出现而已. 至此已经可以排除优化代码问题.

同时, 根据这个现象, 检查了系统上其他进程, 并没有出现此现象.

接下来手动写了测试代码, 测试不停分配内存, 看是否能分配完主机内存, 结果是测试代码能完全分配主机内存, 这现象说明主机配置没问题, 是进程本身问题.

于是怀疑是否是某些编译参数导致进程有限制?
首先想到的是进程架构, 检查发现编译时, 指定了 `-m64`, 编译的是64位进程, 不存在32位进程的虚拟地址空间限制.

### strace跟踪
经过上述分析, 虽然问题缩小了范围, 但是仍然不好分析, 于是使用strace跟踪系统调用, 看出问题时的情况

```log
60122 18:03:29.113460 mmap(NULL, 8388608, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS|MAP_NORESERVE, -1, 0 <unfinished ...>
52927 18:03:29.113508 <... futex resumed>) = 0 <0.000051>
60122 18:03:29.113636 <... mmap resumed>) = -1 ENOMEM (Cannot allocate memory) <0.000165>
```

使用strace跟踪进程系统调用发下, 在申请内存时, 系统调用mmap返回了 `ENOMEM` 错误, 提示无法分配内存

#### linux动态内存管理
两种动态内存管理的方法: 堆内存分配和mmap的内存分配, 此两种分配方法都是通过相应的Linux 系统调用来进行动态内存管理的. 具体使用哪一种方式分配, 根据glibc的实现, 主要取决于所需分配内存的大小.

**用brk实现进程里堆内存分配**
在glibc中，当进程所需要的内存较小时, 小于128k的内存, 使用brk分配内存, 将_edata往高地址推(只分配虚拟空间，不对应物理内存(因此没有初始化)，第一次读/写数据时，引起内核缺页中断，内核才分配对应的物理内存，然后虚拟地址空间建立映射关系), 但是堆分配出来的内存空间, 系统一般不会回收, 只有当进程的堆大小到达最大限额时或者没有足够连续大小的空间来为进程继续分配所需内存时, 才会回收不用的堆内存. 在这种方式下, glibc会为进程堆维护一些固定大小的内存池以减少内存碎片.

**使用mmap的内存分配**
在glibc中, 一般在比较大的内存分配时使用mmap系统调用, 它以页为单位来分配内存的(在Linux中, 一般一页大小定义为4K), 这不可避免会带来内存浪费, 但是当进程调用free释放所分配的内存时, glibc会立即调用unmmap, 把所分配的内存空间释放回系统.

> https://blog.csdn.net/yusiguyuan/article/details/39496057
> https://www.cnblogs.com/Courage129/p/14232306.html
> https://www.cnblogs.com/Courage129/p/14231781.html
> https://www.cnblogs.com/arnoldlu/p/12156368.html


从strace跟踪结果看, 是mmap系统调用返回了错误, 因此继续分析失败原因
查了一圈资料, `max_map_count` 参数可能会导致mmap返ENOMEM, 于是尝试调大该值, 测试仍没有效果.
> This file contains the maximum number of memory map areas a process may have. Memory map areas are used as a side-effect of calling malloc, directly by mmap and mprotect, and also when loading shared libraries.
> While most applications need less than a thousand maps, certain programs, particularly malloc debuggers, may consume lots of them, e.g., up to one or two maps per allocation.
> The default value is 65536.

分析到这里, 再次失去了方向, 为啥有大量可用内存, 地址空间未限制, 但是进程无法分配到内存呢?

### 继续尝试
分析到这里, 感觉能用的办法都用了, 但是仍找不到问题, 于是乎, 我在代码入口处加了个分配内存测试的代码, 死循环分配, 观察下现象, 结果让人眼前一亮, 感觉看到了希望的曙光, 即使是不要业务, 单单内存分配, 进程也会在分配几百M后出现分配失败的问题, 这一下就让问题范围缩小到极致, 之前怀疑可能是内存破坏导致, 但是由于要性能测试时才会出现, 所以没有好方法跟踪到重启时的内存情况, 这个测试结果说明跟跑业务没关系, 在加上之前单独写了测试代码, 测试能够分配完所有内存, 这就让问题变得清晰起来, 为啥只有这个进程有内存限制, 但是测试进程没有呢, 于是马上想到, 之前查看的所有ulimit配置都是只看了启动终端下的结果, 没有看进程实际的limits, 果断查了正在重启的进程limits
```shell
$ cat /proc/14402/limits
Limit                     Soft Limit           Hard Limit           Units
Max cpu time              unlimited            unlimited            seconds
Max file size             unlimited            unlimited            bytes
Max data size             900000000            unlimited            bytes
Max stack size            8388608              unlimited            bytes
Max core file size        unlimited            unlimited            bytes
Max resident set          unlimited            unlimited            bytes
Max processes             4096                 31152                processes
Max open files            65536                65536                files
Max locked memory         65536                65536                bytes
Max address space         unlimited            unlimited            bytes
Max file locks            unlimited            unlimited            locks
Max pending signals       31152                31152                signals
Max msgqueue size         819200               819200               bytes
Max nice priority         0                    0
Max realtime priority     0                    0
Max realtime timeout      unlimited            unlimited            us
scpas@eb60159>
```

果然一看结果, 和shell中设置的data size不一致, 启动进程的shell中设置的是unlimited, 但是进程的值限制到了900000000
通过prlimit命令修改了进程的data size, 果然, 进程不再重启, 问题解决
```shell
prlimit -d=unlimited:unlimited -p 14402
```

但是为啥进程没有继承shell的ulimit配置, 而是被限制到了900000000呢, 思考了一下进程启动方式, 平台的进程是通过一个守护进程`init` 启动, 肯定是跟该进程有关, 于是尝试手动在终端下启动主进程, 查看果然, data size未unlimited, 内存分配没有问题.

于是立马把守护进程代码翻出来检查, 终于找到了罪魁祸首:
```C++
int setLimit()
{
    struct rlimit x;
    int ret;
    ret = getrlimit(RLIMIT_CORE, &x);
    x.rlim_cur = x.rlim_max;
    ret = setrlimit(RLIMIT_CORE, &x);
    ret = getrlimit(RLIMIT_DATA, &x);
    x.rlim_cur = 900000000;
    ret = setrlimit(RLIMIT_DATA, &x);
    return ret;
}
```

`init` 进程在fork子进程时, 修改了data size的大小, 导致子进程的值和shell下的不同, 将改修改注释掉之后, 测试问题解决, 至此, 终于是找到了问题的原因, 短短的一行代码, 花了大功夫进行定位, 由于代码历史悠久, 缺乏文档, 很多问题定位极其困难.
