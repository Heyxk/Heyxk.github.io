---
title: learn-golang
date: 2022-07-28 12:31:47
lastmod: 2022-07-28 12:31:47
author: "k"
description: "Golang学习笔记"
keywords: ["go", "golang"]
tags: ["learn", "go"]
categories: ["learn", "go"]
comment: true
toc: true
draft: false
---


# Golang 学习笔记


## 字符串

- 字符串可以使用range访问

```go
s := "test"
for i, v := range s {
    // the type of v is rune
    fmt.Printf("index %d, value %c")
}
```

- `s := "test"` s是常量, 无法通过下标进行修改, 需要转换成slice操作

- `s = s + s1` 此操作会生成新字符串, 使用 `strings.Join()` 效率更高


## make

- `chan` `slice` 和 `map` 引用类型使用 `make` 初始化


## new

- 值类型可使用 `new`


## fmt

- `fmr.Println` 是使用 `%v` 格式化参数, 并在最后追加换行符


## const

- 常量必须是 数字 字符串 布尔值

- 常量的值必须是能够在编译时就能够确定的; 你可以在其赋值表达式中涉及计算过程, 但是所有用于计算的值必须在编译期间就能获得


## 变量

- 变量可以编译期间就被赋值

- `:=` 是声明变量的首选形式, 但是它只能被用在函数体内, 而不可以用于全局变量的声明与赋值


## 指针

- 函数返回局部变量的地址是安全的, 如下, 指针p依然引用v, v不会被回收

```go
var p = f()

func f() *int {
    v := 1
    return &v
}
```
