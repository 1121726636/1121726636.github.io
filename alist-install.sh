#!/bin/bash
clear
echo
NOTE='\033[36m
==========================================================================
\r\n                        Alist 一键部署脚本\r\n
  Alist是一款阿里云盘的目录文件列表程序，后端基于golang最好的http框架gin\r
  前端使用vue和ant design\r  项目地址：https://github.com/Xhofe/alist\r\n
                                         Script by 大白一号 www.cooluc.com
==========================================================================
\033[0m';
echo -e "$NOTE";
platform=`arch`
if [ "$(id -u)" != "0" ]; then
  echo
  echo "出错了，请使用 root 权限重试！"
  echo
  exit 1;
elif [ "$platform" != "x86_64" ];then
  echo
  echo -e "\033[31m出错了\033[0m，一键安装目前只支持 x86_64 平台。\r\n其它平台请参考：\033[36mhttps://www.nn.ci/archives/alist.html\033[0m"
  echo
  exit 1;
elif ! command -v systemctl >/dev/null 2>&1; then
  echo
  echo -e "\033[31m出错了\033[0m，无法确定你当前的Linux发行版。\r\n建议参考Alist官方安装教程：\033[36mhttps://www.nn.ci/archives/alist.html\033[0m"
  echo
  exit 1;
else
  if command -v netstat >/dev/null 2>&1; then
    check_port=`netstat -lnp|grep 5244|awk '{print $7}'|awk -F/ '{print $1}'`
  else
    echo "端口检查 ..."
    if command -v yum >/dev/null 2>&1; then
      yum install net-tools -y >/dev/null 2>&1
      check_port=`netstat -lnp|grep 5244|awk '{print $7}'|awk -F/ '{print $1}'`
    else
      apt-get update >/dev/null 2>&1
      apt-get install -y net-tools >/dev/null 2>&1
      check_port=`netstat -lnp|grep 5244|awk '{print $7}'|awk -F/ '{print $1}'`
    fi
  fi
fi

echo "获取 Alist 版本信息 ..."

# Github 镜像
mirror="https://download.fastgit.org"

# 获取Alist版本
latest_version=`curl -s "https://api.github.com/repos/Xhofe/alist/releases/latest"|grep "tag_name"|head -n 1|awk -F ":" '{print $2}'|sed 's/\"//g;s/,//g;s/ //g'`;
web_version=`curl -s "https://api.github.com/repos/Xhofe/alist-web/releases/latest"|grep "tag_name"|head -n 1|awk -F ":" '{print $2}'|sed 's/\"//g;s/,//g;s/ //g'`;

# 获取公网IP
myip=`curl -s http://ip.3322.org`;

# 如果无法获取Alist版本号，则指定一个存在的版本，防止国内服务器无法通过GitHub Api获取版本号导致下载失败
if [ -z "$latest_version" ];then
  latest_version=v1.0.4
fi
if [ -z "$web_version" ];then
  web_version=v1.0.4
fi

CHECK() (
if [ $check_port ];then
  kill -9 $check_port
fi
if [ ! -d "/opt/alist/" ];then
  mkdir -p /opt/alist
else
  rm -rf /opt/alist && mkdir -p /opt/alist
fi
)

INSTALL() (
# 下载 Alist 后端程序
echo
echo "下载 Alist $latest_version ..."
if curl --help | grep progress-bar >/dev/null 2>&1; then
  curl -L $mirror/Xhofe/alist/releases/download/$latest_version/alist_"$latest_version"_linux_amd64.tar.gz -o /tmp/alist.tar.gz --progress-bar
else
  curl -L $mirror/Xhofe/alist/releases/download/$latest_version/alist_"$latest_version"_linux_amd64.tar.gz -o /tmp/alist.tar.gz
fi
tar zxf /tmp/alist.tar.gz -C /opt/alist/
if [ -d /opt/alist/linux_amd64 ];then
  mv /opt/alist/linux_amd64/alist /opt/alist/
  rm -rf /opt/alist/linux_amd64
else
  echo "下载 alist_"$latest_version"_linux_amd64.tar.gz 失败！"
  exit 1;
fi

# 下载 Alist 前端web
echo "下载 Alist-web $web_version ..."
if curl --help | grep progress-bar >/dev/null 2>&1; then
  curl -L $mirror/Xhofe/alist-web/releases/download/"$web_version"/refs.tags."$web_version".tar.gz -o /tmp/alist-web.tar.gz --progress-bar
else
  curl -L $mirror/Xhofe/alist-web/releases/download/"$web_version"/refs.tags."$web_version".tar.gz -o /tmp/alist-web.tar.gz
fi
tar zxf /tmp/alist-web.tar.gz -C /opt/alist/
if [ ! -d /opt/alist/dist ];then
  echo
  echo "下载 refs.tags."$web_version".tar.gz 失败！"
  exit 1;
fi

# 创建 systemd
cat >/lib/systemd/system/alist.service <<EOF
[Unit]
Description=Alist service
Wants=network.target
Before=network.target network.service

[Service]
Type=simple
WorkingDirectory=/opt/alist
ExecStart=/opt/alist/alist
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
# 添加开机启动
systemctl daemon-reload
systemctl enable alist >/dev/null 2>&1

# 删除下载缓存
rm -f /tmp/alist.tar.gz /tmp/alist-web.tar.gz
)

INSTALL_DEV() (
echo
echo "安装 Alist 开发版 ..."
echo
# git
if ! command -v git >/dev/null 2>&1; then
  if command -v yum >/dev/null 2>&1; then
    yum install git -y
  else
    apt-get update
    apt-get install -y git
  fi
fi
if ! cat ~/.gitconfig | grep hub.fastgit.org >/dev/null 2>&1; then
    git config --global url.https://hub.fastgit.org.insteadof https://github.com
fi
# GCC
if ! command -v gcc >/dev/null 2>&1; then
  if command -v yum >/dev/null 2>&1; then
    yum install gcc gcc-c++ -y
  else
    apt-get update
    apt-get install -y gcc
  fi
fi

# Go
echo "下载 Go v1.16.5 ..."
if [ ! -f "/opt/go/bin/go" ];then
  if curl --help | grep progress-bar >/dev/null 2>&1; then
    curl -L https://dl.google.com/go/go1.16.5.linux-amd64.tar.gz -o /tmp/go1.16.5.linux-amd64.tar.gz --progress-bar
  else
    curl -L https://dl.google.com/go/go1.16.5.linux-amd64.tar.gz -o /tmp/go1.16.5.linux-amd64.tar.gz
  fi
  tar zxf /tmp/go1.16.5.linux-amd64.tar.gz -C /opt/
  export PATH="/opt/go/bin:$PATH"
else
  export PATH="/opt/go/bin:$PATH"
fi
export GOPROXY="https://mirrors.aliyun.com/goproxy/"

# nodejs
echo "下载 Nodejs v14.17.1 ..."
if [ ! -f "/opt/node/bin/node" ];then
  if curl --help | grep progress-bar >/dev/null 2>&1; then
    curl -L https://npm.taobao.org/mirrors/node/v14.17.1/node-v14.17.1-linux-x64.tar.xz -o /tmp/node-v14.17.1-linux-x64.tar.xz --progress-bar
  else
    curl -L https://npm.taobao.org/mirrors/node/v14.17.1/node-v14.17.1-linux-x64.tar.xz -o /tmp/node-v14.17.1-linux-x64.tar.xz
  fi
  tar xf /tmp/node-v14.17.1-linux-x64.tar.xz -C /opt/
  mv /opt/node-v14.17.1-linux-x64 /opt/node
  export PATH="/opt/node/bin:$PATH"
else
  export PATH="/opt/node/bin:$PATH"
fi
npm --registry https://registry.npm.taobao.org install express

# clone alist source
echo
echo "下载 Alist 源码 ..."
git clone https://github.com/Xhofe/alist --depth=1 ~/alist
cd ~/alist
# dev identifier
sed -ri 's/VERSION = "(.*)"/VERSION = "\1-dev"/' conf/const.go
# alist build
go build
\cp -f alist /opt/alist/

# clone alist-web source
echo
echo "下载 Alist-web 源码 ..."
git clone https://github.com/Xhofe/alist-web --depth=1 ~/alist-web
cd ~/alist-web
npm install -g yarn
yarn install
yarn build
mv dist /opt/alist/

# 创建 systemd
cat >/lib/systemd/system/alist.service <<EOF
[Unit]
Description=Alist service
Wants=network.target
After=network.target network.service

[Service]
Type=simple
WorkingDirectory=/opt/alist
ExecStart=/opt/alist/alist
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
# 添加开机启动
systemctl daemon-reload
systemctl enable alist >/dev/null 2>&1

# 删除下载缓存
rm -rf /tmp/node-v14.17.1-linux-x64.tar.xz /tmp/go1.16.5.linux-amd64.tar.gz ~/alist ~/alist-web ~/go
)

INIT() (
if [ ! -f "/opt/alist/alist" ];then
  echo
  echo -e "\033[31m出错了\033[0m，当前系统未安装 Alist"
  echo
  exit 1;
else
  rm -f /opt/alist/alist.db
fi
echo
echo -n "请输入阿里云盘 refresh_token："
read REFRESH_TOKEN
cat > /opt/alist/conf.yml <<EOF
info:
  title: AList
  logo: ""
  footer_text: Xhofe's Blog
  footer_url: https://www.nn.ci
  music_img: https://img.oez.cc/2020/12/19/0f8b57866bdb5.gif
  check_update: true
  script:
  autoplay: true
  preview:
    text: [txt,htm,html,xml,java,properties,sql,js,md,json,conf,ini,vue,php,py,bat,gitignore,yml,go,sh,c,cpp,h,hpp]
server:
  address: "0.0.0.0"
  port: "5244"
  search: true
  static: dist
  site_url: '*'
  password: password
ali_drive:
  api_url: https://api.aliyundrive.com/v2
  max_files_count: 50
  drives:
  - refresh_token: $REFRESH_TOKEN
    root_folder: root
    name: home
    password: 
    hide: false
database:
  type: sqlite3
  dBFile: alist.db

EOF
systemctl restart alist

# 防火墙放行 Alist 服务端口
echo
echo "本地防火墙放行 5244 端口"
if [ -f /usr/lib/systemd/system/iptables.service ];then  # 如果服务不存在，跳过状态判断，避免下文抛出多余日志
  IPTABLES_STATUS=`systemctl status iptables`
fi
FIREWALLD_STATUS=`systemctl status firewalld`
if [[ "$IPTABLES_STATUS" =~ "active" ]];then
  WORK_PORT=`iptables-save | grep ACCEPT | grep 5244`
  if [[ -z $WORK_PORT ]];then
    iptables -A INPUT -p tcp -m tcp --dport 5244 -j ACCEPT
    service iptables save
  fi
elif [[ "$FIREWALLD_STATUS" =~ "active" ]];then
  WORK_PORT=`firewall-cmd --list-all --zone public | grep 5244/tcp`
  if [[ -z $WORK_PORT ]];then
    firewall-cmd --zone=public --add-port=5244/tcp --permanent
    firewall-cmd --reload
  fi
fi

echo "创建目录缓存..."
sleep 5 # 睡眠5秒，防止 Alist 启动后初始化未完成导致重建列表失败
curl -d '{"path":"home","password":"password","depth":3}' -H "Content-Type: application/json" -X POST http://127.0.0.1:5244/api/rebuild >/dev/null 2>&1
)

SUCCESS() (
echo
echo "Alist 安装成功！"
echo
echo -e "访问地址：\033[36mhttp://$myip:5244/\033[0m"
echo
echo -e "配置文件：\033[36m/opt/alist/conf.yml\033[0m"
echo -e "重构目录密码：\033[36mpassword\033[0m"
echo
echo -e "查看状态：\033[36msystemctl status alist\033[0m"

echo -e "启动服务：\033[36msystemctl start alist\033[0m"
echo -e "重启服务：\033[36msystemctl restart alist\033[0m"
echo -e "停止服务：\033[36msystemctl stop alist\033[0m"
echo
echo -e "温馨提示：如果端口无法正常访问，请检查 \033[36m服务器安全组、本机防火墙、Alist状态\033[0m"
echo
)

UNINSTALL() (
echo
echo "卸载 Alist ..."
echo
echo "停止进程"
systemctl disable alist >/dev/null 2>&1
systemctl stop alist >/dev/null 2>&1
echo "清除残留文件"
rm -rf /opt/alist /lib/systemd/system/alist.service
systemctl daemon-reload
echo
echo "Alist 已在系统中移除！"
echo
)

UPDATE() (
if [ ! -f /opt/alist/alist ] || [ ! -f /lib/systemd/system/alist.service ];then
  echo
  echo "系统未安装 Alist，无法进行更新操作！"
  echo
  exit 0;
fi
echo
echo -e "正在更新 Alist 最新版本：\033[36m$latest_version\033[0m"
# clean 
rm -f /tmp/alist.tar.gz /tmp/alist-web.tar.gz
systemctl stop alist
rm -rf /opt/alist/alist /opt/alist/dist

# down alist
echo
echo "下载 Alist $latest_version ..."
if curl --help | grep progress-bar >/dev/null 2>&1; then
  curl -L $mirror/Xhofe/alist/releases/download/$latest_version/alist_"$latest_version"_linux_amd64.tar.gz -o /tmp/alist.tar.gz --progress-bar
else
  curl -L $mirror/Xhofe/alist/releases/download/$latest_version/alist_"$latest_version"_linux_amd64.tar.gz -o /tmp/alist.tar.gz
fi
tar zxf /tmp/alist.tar.gz -C /opt/alist/
if [ -d /opt/alist/linux_amd64 ];then
  mv /opt/alist/linux_amd64/alist /opt/alist/
  rm -rf /opt/alist/linux_amd64
else
  echo "下载 alist_"$latest_version"_linux_amd64.tar.gz 失败！"
  exit 1;
fi

# down web
echo "下载 Alist-web $web_version ..."
if curl --help | grep progress-bar >/dev/null 2>&1; then
  curl -L $mirror/Xhofe/alist-web/releases/download/"$web_version"/refs.tags."$web_version".tar.gz -o /tmp/alist-web.tar.gz --progress-bar
else
  curl -L $mirror/Xhofe/alist-web/releases/download/"$web_version"/refs.tags."$web_version".tar.gz -o /tmp/alist-web.tar.gz
fi
tar zxf /tmp/alist-web.tar.gz -C /opt/alist/
if [ ! -d /opt/alist/dist ];then
  echo
  echo "下载 refs.tags."$web_version".tar.gz 失败！"
  exit 1;
fi
systemctl start alist
echo
echo "更新成功"
echo
)

echo
echo -e " 正式版：Alist 项目推送的稳定版本（推荐使用）\r\n 开发版：Alist 项目最新源码编译安装，安装耗时较长"
echo
echo "> 请选择："
echo
echo -e " 1 - 安装 Alist 正式版（最新版本：\033[36m$latest_version\033[0m）" 
echo -e " 2 - 安装 Alist 开发版" 
echo " 3 - 卸载 Alist"
echo
echo " 4 - 重置 conf.yml 配置"
if [ -f "/opt/alist/alist" ];then
  local_version=`/opt/alist/alist -version | awk -F: '{print $2}'`
  echo -e " 5 - 更新 Alist 正式版 （已安装版本：\033[36m$local_version\033[0m）"
fi
echo
echo -n "请输入："
read mode
case $mode in
[1]|[1-5]) ;;
*) echo -e '\n ...输入错误.';exit 0;;
esac
if [ -z $mode ];then
  echo -e '\n ...输入错误.';exit 0;
else
  if [[ $mode == "1" ]];then
    CHECK
    INSTALL
    INIT
    if [ -f "/opt/alist/alist" ];then
      SUCCESS
    else
      echo -e "\033[31m 安装失败\033[0m"
    fi
  elif [[ $mode == "2" ]];then
    CHECK
    INSTALL_DEV
    INIT
    if [ -f "/opt/alist/alist" ];then
      SUCCESS
    else
      echo -e "\033[31m 安装失败\033[0m"
    fi
  elif [[ $mode == "3" ]];then
    UNINSTALL
  elif [[ $mode == "4" ]];then
    INIT
  elif [[ $mode == "5" ]];then
    UPDATE
  fi
fi
