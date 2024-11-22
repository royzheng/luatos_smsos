# LuatOS 短信/通话转发 远程短信发送
* 支持短信收取并转发到TG
* 支持指定手机向设备里的手机号发送指令，让设备里的手机发送短信
* 支持来电信息通知(Air780E不支持,Air780EPV支持)
### TG渠道使用指南
- 众所周知的原因，TG API不采用特殊手段联不通，所以我们这里实用Cloudflare worker新建一个worker并绑定自己的域名进行api转发(详见tg.worker.js说明)
- 复制tg.main.lua成main.lua，并修改luatsms.sim_number,luatsms.tg_chat_id,luatsms.api_url,luatsms.control_phones四个参数值
- 远程短信功能接收来自luatsms.control_phones的短信指令，发送远程短信的指令为 msg**分隔符**要发送的手机号**分隔符**内容，比如msg#10086#ye命令的意思就是指示向10086发送一条短信，内容为ye。比如msg@10086@ye也是同样的指令，即**分隔符**以msg后的第一个字符为准，这样可以灵活的发送短信，比如现在要求你发送 abc#123 到 10086，那么我们可以用msg,10086,abc#123来方便实现。

### 企业微信渠道使用指南
- 企业微信后台->我的企业->微信插件，使用你的微信关注
- 登录企业微信，创建内部群群聊（没人的话随便新增2个员工，反正不需要走登录激活等手续，创建完群聊可以踢掉并删除），并新增机器人，获取webhook地址(填入到luatsms.api_url)。
- 复制weixin.main.lua成main.lua，并修改luatsms.sim_number,luatsms.api_url,luatsms.control_phones三个参数值
- 短信功能同上

### 产品选型
- 目前试用下来，只用了air780E和air780EPV（都是在合宙天猫店购买的usb款，非常方便跟u盘一样），air780E支持中国移动和中国联通，只支持短信收发，不支持来电通知。air780EPV支持三网短信收发，同时也接收来电通知。

### 烧录指南
* 使用windows下载[LuatOS Tools](https://wiki.luatos.com/pages/tools.html)
* 打开LuatOS Tools后会自动下载一些Core之类的文件
* 点开项目管理测试，然后Core选择相应的文件:Air780E在resource/LuatOS_Air780E/core_vxxx/xxxxx_FULL.soc文件,Air780EPV需要自己手动去[这里](https://gitee.com/openLuat/LuatOS/releases/download/v1002.ec7xx.release/core_V1002.zip)下载(解压后选择LuatOS-SoC_V1002_EC718PV.soc)
* 新建项目，把main.lua拖进去
* 点击下载底层和脚本，等提示要求插入时，按住硬件的按钮别松开插进去，等待烧录完成后松开即可。
* 下次修改脚本仅需要勾选下EC免BOOT方案，然后点击下载脚本即可修改。