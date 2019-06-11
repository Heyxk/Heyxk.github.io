---
title: 小米6提取微信聊天记录
---

### 通过MI6本地备份提取聊天记录

要导出微信安卓客户端的聊天记录，首先得找到聊天记录的数据库。
安卓客户端的聊天记录储存在私有目录 `/data/data/com.tencent.mm/MicroMsg` 下，这个目录需要root权限才能进去，但是，那样太太太麻烦了，好在我们MI6有本地备份的功能，利用这个功能。我们轻而易举就可以获得数据库。

##### 需要的工具

[此处下载](https://github.com/Heyxk/notes/tree/master/resource/wechat-tools)

##### 环境

需要安装Java环境，未安装可以搜索Java安装

#### 提取数据库

1. 首先到手机:设置->更多设置->备份和重置->本地备份 里面点击新建备份，选择软件程序中的微信进行备份

    <img src="https://raw.githubusercontent.com/Heyxk/notes/master/static/images/wechat/01.png" width="200" hegiht="100" align=center />

    <img src="https://raw.githubusercontent.com/Heyxk/notes/master/static/images/wechat/02.png" width="200" hegiht="100" align=center />

2. 然后到文件管理 `/内部储存设备/MIUI/backup/ALLBackup/` 下将备份的文件夹复制到电脑

    <img src="https://raw.githubusercontent.com/Heyxk/notes/master/static/images/wechat/03.png" width="200" align=center />

3. 接下来是从备份的文件中提取微信聊天记录，通过`WinHex`软件查看备份包信息，发现miui备份包是在原生安卓的备份基础上多加了一个文件头。选中多余的文件头，按`delete`键删除，点击保存。修改后的文件就是标准的原生安卓备份文件。

    <img src="https://raw.githubusercontent.com/Heyxk/notes/master/static/images/wechat/04.png" width="400" align=center />

    <img src="https://raw.githubusercontent.com/Heyxk/notes/master/static/images/wechat/05.png" width="400" align=center />

4. 接下来，将修改后的`com.tencent.mm.bak` 处理成原文件，首先将`abe.jar`复制到和`com.tencent.mm.bak`同一个文件夹下
   终端执行：

  ```bash
java -jar abe.jar unpack com.tencent.mm.bak mm.tar
  ```
会生成一个mm.tar文件，用解压软件将这个包解压，会得到一个`apps`文件夹，`apps`文件夹下面有`com.tencent.mm`文件夹，聊天记录数据库就存在`apps/com.tencent.mm/r/MicroMsg/` 下，打开文件夹会发现里面有32位字符(MD5值)的文件夹(登录过多个用户的有多个)，打开此文件夹其中`EnMicroMsg.db`就是要找的数据库文件。

<img src="https://raw.githubusercontent.com/Heyxk/notes/master/static/images/wechat/06.jpg" width="400" align=center/>

<img src="https://raw.githubusercontent.com/Heyxk/notes/master/static/images/wechat/07.jpg" width="400" align=center/>

#### 生成数据库密码

找到聊天数据库了，但是目前还不能得到聊天记录，因为这个数据库是`sqlcipher`加密数据库，需要密码才能打开。

数据库密码有很多种生成方式：

1. 手机`IMEI`+`uin`(微信用户id `userinformation`) 将拼接的字符串[MD5加密](http://tool.chinaz.com/tools/md5.aspx)取前7位

   >如`IMEI`为`123456`，`uin`为`abc`，则拼接后的字符串为`123456abc` 将此字符串用[MD5加密](http://tool.chinaz.com/tools/md5.aspx)(32位)后
   >
   >为`df10ef8509dc176d733d59549e7dbfaf` 那么前7位`df10ef8` 就是数据库的密码，由于有的手机是双卡，有多个`IMEI`，或者当手机获取不到`IMEI`时会用默认字符串`1234567890ABCDEF`来代替，由于种种原因，并不是所有人都能得出正确的密码，此时我们可以换一种方法。

2. 反序列化`CompatibleInfo.cfg`和`systemInfo.cfg` 

   > 不管是否有多个`IMEI` ，或者是微信客户端没有获取到`IMEI`，而使用默认字符串代替，微信客户端都会将使用的信息保存在`MicroMsg`文件夹下面的`CompatibleInfo.cfg`和`systemInfo.cfg`文件中，可以通过这两个文件来得到正确的密码，但是这两个文件需要处理才能看到信息。

3. 使用hook方式得到数据库的密码，这个方法最有效[参考](https://blog.csdn.net/qq_24280381/article/details/73521836)

4. 暴力破解

  ...

##### 使用反序列化的方式获得密码

由于我的手机有多个`IMEI`码，试了半天出来的密码都不对，故使用此方法来得到密码。
首先将`CompatibleInfo.cfg`和`systemInfo.cfg`以及`EnMicroMsg.db`复制出来，将下面这段代码保存到`IMEI.java`文件

```java
import java.io.FileInputStream;
import java.io.ObjectInputStream;
import java.security.MessageDigest;
import java.util.HashMap;
public class IMEI {
 public static void main(String[] args) {
  try {
   ObjectInputStream in = new ObjectInputStream(new FileInputStream(
     args[0]));
   Object DL = in.readObject();
   HashMap hashWithOutFormat = (HashMap) DL;
   ObjectInputStream in1 = new ObjectInputStream(new FileInputStream(
     args[1]));
   Object DJ = in1.readObject();
   HashMap hashWithOutFormat1 = (HashMap) DJ;
   String s = String.valueOf(hashWithOutFormat1.get(Integer
     .valueOf(258))); // 取手机的IMEI
   System.out.println("The IMEI is : " + s);
   String uin = String.valueOf(hashWithOutFormat.get(Integer.valueOf(1)));
   System.out.println("The uin is : " + uin);
   s = s + uin; //合并到一个字符串
   s = encode(s); // hash
   System.out.println("The Key is : " + s.substring(0, 7));
   in.close();
   in1.close();
  } catch (Exception e) {
   e.printStackTrace();
  }
 }
 public static String encode(String content)
  {
   try {
    MessageDigest digest = MessageDigest.getInstance("MD5");
    digest.update(content.getBytes());
    return getEncode32(digest);
    }
   catch (Exception e)
   {
    e.printStackTrace();
   }
   return null;
  }
  private static String getEncode32(MessageDigest digest)
  {
   StringBuilder builder = new StringBuilder();
   for (byte b : digest.digest())
   {
    builder.append(Integer.toHexString((b >> 4) & 0xf));
    builder.append(Integer.toHexString(b & 0xf));
   }
    return builder.toString();

  }
}


```

将这段代码保存到`IMEI.java`文件，将三个文件放在相同目录下
终端运行

```bash
javac IMEI.java
java IMEI systemInfo.cfg CompatibleInfo.cfg
```

运行完成后就会得到密码
[参考链接](http://www.intohard.com/article-331-1.html)

<img src="https://raw.githubusercontent.com/Heyxk/notes/master/static/images/wechat/08.jpg" width="400" align=center />

#### 解密数据库

Windows用户可以使用`sqlcipher.exe`软件来查看数据库
打开数据库，输入密码，就可以查看数据库中的表
文字聊天记录储存在`message`表中，可以选中表，点击软件的右上角file-export导出表到`csv`文件，可以通过Excell查看表中的信息
执行这段命令可以查看制定对象的聊天记录

```bash
select datetime(subStr(cast(m.createTime as text),1,10),'unixepoch', 'localtime') as theTime,case m.isSend when 0 then r.nickname when 1 then '我'end as person,m.content from message m inner join rcontact r on m.talker = r.username where m.type=1 and r.nickname = '对方微信昵称'
```




Linux用户可以使用`sqlcipher`来解密

```bash
sudo apt-get update

sudo apt-get install sqlcipher

sqlcipher EnMicroMsg.db 'PRAGMA key = "yourkey"; PRAGMA cipher_use_hmac = off; PRAGMA kdf_iter = 4000; ATTACH DATABASE "decrypted_database.db" AS decrypted_database KEY "";SELECT sqlcipher_export("decrypted_database");DETACH DATABASE decrypted_database;' 

```


执行上面的命令之后会得到一个解密后的数据库`decrypted_database.db`，可以使用数据库软件查看

<img src="https://raw.githubusercontent.com/Heyxk/notes/master/static/images/wechat/09.jpg" width="400" align=center />

得到数据库之后可以分析一下你的聊天记录，顺便制作一个词云来给你的心上人看一下你们都聊了啥:eyes:

看了一下我和女票日消息数走势，最多一天竟然发了809条:joy:

<img src="https://raw.githubusercontent.com/Heyxk/notes/master/static/images/wechat/days-messages.png" width="800" align=center/>
