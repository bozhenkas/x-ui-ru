#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#Add some basic function here
function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}
# check root
[[ $EUID -ne 0 ]] && LOGE "Ошибка:  Необходимо запускать этот скрипт от имени root!\n" && exit 1

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
    LOGE "Не удалось определить версию системы, пожалуйста, свяжитесь с автором скрипта!\n" && exit 1
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
        LOGE "Пожалуйста, используйте CentOS 7 или более новую версию!\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        LOGE "Пожалуйста, используйте Ubuntu 16 или более новую версию!\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        LOGE "Пожалуйста, используйте Debian 8 или более новую версию!\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [по умолчанию $2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Перезапустить панель? Перезапуск панели также перезапустит xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Нажмите Enter для возврата в главное меню: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/bozhenkas/x-ui-ru/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "Эта функция принудительно переустановит последнюю версию, данные не будут потеряны. Продолжить?" "n"
    if [[ $? != 0 ]]; then
        LOGE "Отменено"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/bozhenkas/x-ui-ru/master/install.sh)
    if [[ $? == 0 ]]; then
        LOGI "Обновление завершено, панель автоматически перезапущена "
        exit 0
    fi
}

uninstall() {
    confirm "Вы уверены, что хотите удалить панель? xray также будет удален." "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop x-ui
    systemctl disable x-ui
    rm /etc/systemd/system/x-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/x-ui/ -rf
    rm /usr/local/x-ui/ -rf

    echo ""
    echo -e "Удаление успешно. Если вы хотите удалить этот скрипт, после выхода выполните ${green}rm /usr/bin/x-ui -f${plain}"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "Вы уверены, что хотите сбросить имя пользователя и пароль на admin?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -username admin -password admin
    echo -e "Имя пользователя и пароль сброшены на ${green}admin${plain}, теперь перезапустите панель"
    confirm_restart
}

reset_config() {
    confirm "Вы уверены, что хотите сбросить все настройки панели? Данные аккаунта не будут потеряны, имя пользователя и пароль не изменятся." "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "Все настройки панели сброшены на значения по умолчанию. Теперь перезапустите панель и используйте порт ${green}54321${plain} для доступа к панели."
    confirm_restart
}

check_config() {
    info=$(/usr/local/x-ui/x-ui setting -show true)
    if [[ $? != 0 ]]; then
        LOGE "get current settings error,please check logs"
        show_menu
    fi
    LOGI "${info}"
}

set_port() {
    echo && echo -n -e "Введите номер порта [1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        LOGD "Отменено"
        before_show_menu
    else
        /usr/local/x-ui/x-ui setting -port ${port}
        echo -e "Порт успешно установлен. Теперь перезапустите панель и используйте новый порт ${green}${port}${plain} для доступа к панели."
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        LOGI "Панель уже запущена, повторный запуск не требуется. Для перезапуска выберите соответствующую опцию."
    else
        systemctl start x-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            LOGI "Панель успешно запущена"
        else
            LOGE "Не удалось запустить панель, возможно, запуск занял больше двух секунд. Пожалуйста, проверьте логи позже."
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        LOGI "Панель уже остановлена, повторная остановка не требуется"
    else
        systemctl stop x-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            LOGI "Панель и xray успешно остановлены"
        else
            LOGE "Не удалось остановить панель, возможно, остановка заняла больше двух секунд. Пожалуйста, проверьте логи позже."
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart x-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        LOGI "Панель и xray успешно перезапущены"
    else
        LOGE "Не удалось перезапустить панель, возможно, запуск занял больше двух секунд. Пожалуйста, проверьте логи позже."
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status x-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable x-ui
    if [[ $? == 0 ]]; then
        LOGI "Автозапуск x-ui успешно включен"
    else
        LOGE "Не удалось включить автозапуск x-ui"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable x-ui
    if [[ $? == 0 ]]; then
        LOGI "Автозапуск x-ui успешно отключен"
    else
        LOGE "Не удалось отключить автозапуск x-ui"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u x-ui.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

migrate_v2_ui() {
    /usr/local/x-ui/x-ui v2-ui

    before_show_menu
}

install_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
    before_show_menu
}

update_shell() {
    wget -O /usr/bin/x-ui -N --no-check-certificate https://github.com/bozhenkas/x-ui-ru/raw/master/x-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        LOGE "Не удалось загрузить скрипт, проверьте подключение к Github"
        before_show_menu
    else
        chmod +x /usr/bin/x-ui
        LOGI "Скрипт успешно обновлен, перезапустите скрипт" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status x-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled x-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        LOGE "Панель уже установлена, не устанавливайте повторно"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        LOGE "Пожалуйста, сначала установите панель"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
    0)
        echo -e "Статус панели: ${green}запущена${plain}"
        show_enable_status
        ;;
    1)
        echo -e "Статус панели: ${yellow}не запущена${plain}"
        show_enable_status
        ;;
    2)
        echo -e "Статус панели: ${red}не установлена${plain}"
        ;;
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Автозапуск: ${green}включен${plain}"
    else
        echo -e "Автозапуск: ${red}отключен${plain}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "xray статус: ${green}запущен${plain}"
    else
        echo -e "xray статус: ${red}не запущен${plain}"
    fi
}

ssl_cert_issue() {
    echo -E ""
    LOGD "******Использование******"
    LOGI "Этот скрипт будет использовать скрипт Acme для получения сертификата, используйте следующие условия:"
    LOGI "1. Знаете электронную почту, зарегистрированную в Cloudflare"
    LOGI "2. Знаете Cloudflare Global API Key"
    LOGI "3. Домен уже разрешен в Cloudflare"
    LOGI "4. Этот скрипт получает сертификат по умолчанию, установленный в каталог /root/cert"
    confirm "Я подтверждаю вышеуказанное содержание[y/n]" "y"
    if [ $? -eq 0 ]; then
        cd ~
        LOGI "Установка скрипта Acme"
        curl https://get.acme.sh | sh
        if [ $? -ne 0 ]; then
            LOGE "Не удалось установить скрипт acme"
            exit 1
        fi
        CF_Domain=""
        CF_GlobalKey=""
        CF_AccountEmail=""
        certPath=/root/cert
        if [ ! -d "$certPath" ]; then
            mkdir $certPath
        else
            rm -rf $certPath
            mkdir $certPath
        fi
        LOGD "Пожалуйста, установите домен:"
        read -p "Input your domain here:" CF_Domain
        LOGD "Ваш домен установлен:${CF_Domain}"
        LOGD "Пожалуйста, установите API ключ:"
        read -p "Input your key here:" CF_GlobalKey
        LOGD "Ваш API ключ:${CF_GlobalKey}"
        LOGD "Пожалуйста, установите электронную почту:"
        read -p "Input your email here:" CF_AccountEmail
        LOGD "Ваша электронная почта:${CF_AccountEmail}"
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        if [ $? -ne 0 ]; then
            LOGE "Не удалось изменить значение по умолчанию CA на Lets'Encrypt, скрипт выходит"
            exit 1
        fi
        export CF_Key="${CF_GlobalKey}"
        export CF_Email=${CF_AccountEmail}
        ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} --log
        if [ $? -ne 0 ]; then
            LOGE "Не удалось выпустить сертификат, скрипт выходит"
            exit 1
        else
            LOGI "Сертификат успешно выпущен, установка..."
        fi
        ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} -d *.${CF_Domain} --ca-file /root/cert/ca.cer \
        --cert-file /root/cert/${CF_Domain}.cer --key-file /root/cert/${CF_Domain}.key \
        --fullchain-file /root/cert/fullchain.cer
        if [ $? -ne 0 ]; then
            LOGE "Не удалось установить сертификат, скрипт выходит"
            exit 1
        else
            LOGI "Сертификат успешно установлен, включен автоматический обновление..."
        fi
        ~/.acme.sh/acme.sh --upgrade --auto-upgrade
        if [ $? -ne 0 ]; then
            LOGE "Не удалось установить автоматическое обновление, скрипт выходит"
            ls -lah cert
            chmod 755 $certPath
            exit 1
        else
            LOGI "Сертификат успешно установлен и включен автоматический обновление, подробная информация ниже"
            ls -lah cert
            chmod 755 $certPath
        fi
    else
        show_menu
    fi
}

show_usage() {
    echo "Использование скрипта управления x-ui: "
    echo "------------------------------------------"
    echo "x-ui              - показать меню управления (больше функций)"
    echo "x-ui start        - запустить панель x-ui"
    echo "x-ui stop         - остановить панель x-ui"
    echo "x-ui restart      - перезапустить панель x-ui"
    echo "x-ui status       - посмотреть статус x-ui"
    echo "x-ui enable       - включить автозапуск x-ui"
    echo "x-ui disable      - отключить автозапуск x-ui"
    echo "x-ui log          - посмотреть логи x-ui"
    echo "x-ui v2-ui        - мигрировать аккаунты v2-ui в x-ui"
    echo "x-ui update       - обновить панель x-ui"
    echo "x-ui install      - установить панель x-ui"
    echo "x-ui uninstall    - удалить панель x-ui"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}Скрипт управления панелью x-ui${plain}
  ${green}0.${plain} Выход из скрипта
————————————————
  ${green}1.${plain} Установить x-ui
  ${green}2.${plain} Обновить x-ui
  ${green}3.${plain} Удалить x-ui
————————————————
  ${green}4.${plain} Сбросить имя пользователя и пароль
  ${green}5.${plain} Сбросить настройки панели
  ${green}6.${plain} Установить порт панели
  ${green}7.${plain} Просмотреть текущие настройки панели
————————————————
  ${green}8.${plain} Запустить x-ui
  ${green}9.${plain} Остановить x-ui
  ${green}10.${plain} Перезапустить x-ui
  ${green}11.${plain} Просмотреть статус x-ui
  ${green}12.${plain} Просмотреть логи x-ui
————————————————
  ${green}13.${plain} Включить автозапуск x-ui
  ${green}14.${plain} Отключить автозапуск x-ui
————————————————
  ${green}15.${plain} Установить BBR (последнее ядро)
  ${green}16.${plain} Получить SSL сертификат (acme)
 "
    show_status
    echo && read -p "Введите выбор [0-16]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        check_uninstall && install
        ;;
    2)
        check_install && update
        ;;
    3)
        check_install && uninstall
        ;;
    4)
        check_install && reset_user
        ;;
    5)
        check_install && reset_config
        ;;
    6)
        check_install && set_port
        ;;
    7)
        check_install && check_config
        ;;
    8)
        check_install && start
        ;;
    9)
        check_install && stop
        ;;
    10)
        check_install && restart
        ;;
    11)
        check_install && status
        ;;
    12)
        check_install && show_log
        ;;
    13)
        check_install && enable
        ;;
    14)
        check_install && disable
        ;;
    15)
        install_bbr
        ;;
    16)
        ssl_cert_issue
        ;;
    *)
        LOGE "Введите корректное число [0-16]"
        ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
    "start")
        check_install 0 && start 0
        ;;
    "stop")
        check_install 0 && stop 0
        ;;
    "restart")
        check_install 0 && restart 0
        ;;
    "status")
        check_install 0 && status 0
        ;;
    "enable")
        check_install 0 && enable 0
        ;;
    "disable")
        check_install 0 && disable 0
        ;;
    "log")
        check_install 0 && show_log 0
        ;;
    "v2-ui")
        check_install 0 && migrate_v2_ui 0
        ;;
    "update")
        check_install 0 && update 0
        ;;
    "install")
        check_uninstall 0 && install 0
        ;;
    "uninstall")
        check_install 0 && uninstall 0
        ;;
    *) show_usage ;;
    esac
else
    show_menu
fi
