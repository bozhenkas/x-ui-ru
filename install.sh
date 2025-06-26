#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Ошибка:${plain} Необходимо запускать этот скрипт от имени root!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Не удалось определить версию системы, пожалуйста, свяжитесь с автором скрипта!${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="amd64"
    echo -e "${red}Не удалось определить архитектуру, используется архитектура по умолчанию: ${arch}${plain}"
fi

echo "Архитектура: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "Это программное обеспечение не поддерживает 32-битные системы (x86), используйте 64-битную систему (x86_64). Если это ошибка, свяжитесь с автором."
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Пожалуйста, используйте CentOS 7 или более новую версию!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Пожалуйста, используйте Ubuntu 16 или более новую версию!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Пожалуйста, используйте Debian 8 или более новую версию!${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt install wget curl tar -y
    fi
}

#This function will be called when user installed x-ui out of sercurity
config_after_install() {
    echo -e "${yellow}В целях безопасности после установки/обновления необходимо обязательно изменить порт и учетные данные${plain}"
    read -p "Подтвердите продолжение?[y/n]": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "Установите имя пользователя:" config_account
        echo -e "${yellow}Ваше имя пользователя будет установлено как: ${config_account}${plain}"
        read -p "Установите пароль пользователя:" config_password
        echo -e "${yellow}Ваш пароль будет установлен как: ${config_password}${plain}"
        read -p "Установите порт для доступа к панели:" config_port
        echo -e "${yellow}Порт для доступа к панели будет установлен как: ${config_port}${plain}"
        echo -e "${yellow}Подтверждение настроек, выполняется...${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}Имя пользователя и пароль установлены${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow}Порт панели установлен${plain}"
    else
        echo -e "${red}Отменено, все параметры по умолчанию, пожалуйста, измените их как можно скорее${plain}"
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/bozhenkas/x-ui-ru/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Не удалось определить версию x-ui, возможно превышен лимит Github API, попробуйте позже или укажите версию вручную${plain}"
            exit 1
        fi
        echo -e "Обнаружена последняя версия x-ui: ${last_version}, начинаю установку"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/bozhenkas/x-ui-ru/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Не удалось скачать x-ui, убедитесь, что сервер может скачивать файлы с Github${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/bozhenkas/x-ui-ru/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "Начинаю установку x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Не удалось скачать x-ui v$1, убедитесь, что эта версия существует${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/bozhenkas/x-ui-ru/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    #echo -e "Если это новая установка, веб-порт по умолчанию ${green}54321${plain}, имя пользователя и пароль по умолчанию ${green}admin${plain}"
    #echo -e "Пожалуйста, убедитесь, что этот порт не занят другими программами, ${yellow}и что порт 54321 открыт${plain}"
    #    echo -e "Если хотите изменить порт 54321, используйте команду x-ui, также убедитесь, что новый порт открыт"
    #echo -e ""
    #echo -e "Если это обновление панели, используйте прежний способ доступа к панели"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} установка завершена, панель запущена,"
    echo -e ""
    echo -e "Использование скрипта управления x-ui: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - Показать меню управления (больше функций)"
    echo -e "x-ui start        - Запустить панель x-ui"
    echo -e "x-ui stop         - Остановить панель x-ui"
    echo -e "x-ui restart      - Перезапустить панель x-ui"
    echo -e "x-ui status       - Проверить статус x-ui"
    echo -e "x-ui enable       - Включить автозапуск x-ui"
    echo -e "x-ui disable      - Отключить автозапуск x-ui"
    echo -e "x-ui log          - Просмотреть журнал x-ui"
    echo -e "x-ui v2-ui        - Мигрировать данные аккаунтов v2-ui на этом сервере в x-ui"
    echo -e "x-ui update       - Обновить панель x-ui"
    echo -e "x-ui install      - Установить панель x-ui"
    echo -e "x-ui uninstall    - Удалить панель x-ui"
    echo -e "----------------------------------------------"
}

echo -e "${green}Начинаю установку${plain}"
install_base
install_x-ui $1
