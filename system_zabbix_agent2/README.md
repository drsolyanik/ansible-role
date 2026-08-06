system_zabbix_agent2
=========
Ansible-роль для автоматизированного развертывания, настройки по принципам **Zero Trust**, создания TLS PSK шифрования и автоматической регистрации **Zabbix Agent 2** на серверах под управлением **Astra Linux 1.8** и **Debian 12** через Zabbix API.

## **Окружение и зависимости**

Роль протестирована и валидирована на строго зафиксированном стеке:

|**Компонент**|**Версия**|**Примечание**|
|---|---|---|
|**Ansible Core**|`2.19.10`|Требуемый оркестратор на Control Node|
|**Коллекция `community.zabbix`**|`4.1.1`|Прямое взаимодействие с Zabbix API|
|**Zabbix Server**|`7.0.24`|Целевой сервер мониторинга|
|**Целевые ОС**|**Astra Linux 1.8**, **Debian 12**|Операционные системы целевых хостов|

Установка зависимостей роли из `requirements.yml`:

```
ansible-galaxy collection install -r requirements.yml --force
```

Содержимое `requirements.yml`:

```
---
collections:
  - name: community.zabbix
    version: "4.1.1"
```

## **Ключевые архитектурные особенности**

- **Безопасность по принципу Zero Trust:** Активация глобального запрета выполнения `DenyKey=*` с явным разрешением только проверенных метрик из белого списка `AllowKey`.
    
- **Автоматический полный цикл TLS PSK:** Генерация 256-битного PSK-ключа (`openssl rand -hex 32`), установка прав `0640` (`root:zabbix`), безопасное считывание без утечки в логи (`no_log`) и передача секрета в Zabbix API.
    
- **Автоматическая ротация PSK:** Возможность принудительного обновления ключей шифрования «на лету» через внеочередной запуск с флагом `-e "zabbix_agent_regenerate_psk=true"`.
    
- **Прямое декларирование в Zabbix API:** Регистрация хостов, привязка сетевых интерфейсов, объединенный импорт базовых и кастомных групп/шаблонов (`union`) через модуль `community.zabbix.zabbix_host` на Zabbix Server.
    
- **Safety First & Атомарность:**
    
    - Проверка валидности синтаксиса конфигурации самим бинарником `/usr/sbin/zabbix_agent2 -c %s -t system.uptime` перед применением.
        
    - Валидация правил `sudoers` через `/usr/sbin/visudo -cf %s`.
        
    - Пропуск фазы инсталляции при наличии готового бинарного файла (`ansible.builtin.stat`).
        
- **Очистка Legacy:** Автоматический purge старой версии `zabbix-agent` (v1) с зачисткой файлов `/etc/zabbix/zabbix_agentd.conf` для исключения конфликтов портов (`10050/TCP`).
    

## **Настройка доступа на Zabbix Server**

Для работы взаимодействия Ansible с Zabbix API на стороне Zabbix Server 7.0.24 настраиваются учетные данные:

1. **User Role:** `Ansible Automation Role` (Тип: `Admin`).
    
    - **Разрешенные методы API:** `host.create`, `host.get`, `host.massupdate`, `host.update`, `hostgroup.get`, `hostinterface.get`, `template.get`.
        
2. **User Group:** `Ansible Automation Group`.
    
    - **Host permissions:** Read-write на целевые группы.
        
    - **Template permissions:** Read-write на целевые шаблоны.
        
3. **User & API Token:** Пользователь `ansible-api`, для которого генерируется бессрочный API Token и сохраняется в Vault.
    

## **Пример переопределения переменных (`inventory/host_vars/zabbix.yml`)**

Пример конфигурации для узла Zabbix Server, где требуется замыкание на loopback, дополнительный IP, кастомные SSL-метрики и расширение шаблонов:

```
---
# Сеть и идентификация
zabbix_agent_server: "127.0.0.1,10.0.2.13"
zabbix_agent_server_active: "127.0.0.1,10.0.2.13"

# Пользовательские метрики (UserParameter)
zabbix_agent_user_parameters_custom:
  - name: "cert.ssl.discovery"
    command: "/usr/bin/bash /etc/zabbix/scripts/cert_ssl_discovery.sh"
  - name: "cert.ssl.get[*]"
    command: "/usr/bin/bash /etc/zabbix/scripts/ssl_check_legacy.sh \"$1\" \"$2\" \"$3\""

# Белый список ключей (обязателен при DenyKey=*)
zabbix_agent_allow_key_custom:
  - "cert.ssl.discovery"
  - "cert.ssl.get[*]"

# Расширение групп и шаблонов в Zabbix API
zabbix_agent_extra_groups:
  - "Zabbix servers"
  - "Virtual machines"

zabbix_agent_extra_templates:
  - "Custom SSL certificates Monitoring"
  - "Zabbix server health"
```

## **Сценарии промышленного запуска**

- **Сценарий А: Первичный ввод нового сервера в эксплуатацию**
    
    ```
    ansible-playbook site.yml -t baseline -l "astra-test.sdr.lan"
    ```
    
- **Сценарий Б: Сплошное обновление конфигурации по всей инфраструктуре**
    
    ```
    ansible-playbook site.yml -t zabbix_agent
    ```
    
- **Сценарий В: Избирательное обслуживание отдельных контуров**
    
    ```
    ansible-playbook site.yml -t zabbix_agent -l "dmz_servers"
    # или прямой запуск целевого плейбука:
    ansible-playbook playbooks/04_zabbix_agent.yml -l "db_servers"
    ```
    
- **Сценарий Г: Принудительная ротация TLS PSK-ключей шифрования**
    
    ```
    ansible-playbook site.yml -t zabbix_agent -l "sec_servers" -e "zabbix_agent_regenerate_psk=true"
    ```
    

## **Правовой статус, участие ИИ и Лицензия**

**Авторские права и статус разработки**

- **Автор разработки:** Соляник Дмитрий Романович.
    
- **Правовой статус:** Данная роль разработана автором лично, во внерабочее время, на собственном оборудовании, вне рамок трудовых обязанностей и без использования служебной информации или ресурсов каких-либо работодателей. Разработка является полностью независимой личной интеллектуальной собственностью автора.
    
**Раскрытие информации об использовании ИИ**

- В процессе проектирования, оптимизации проверок, рефакторинга кода, написания Jinja2-шаблонов и составления технической документации к данной роли в качестве инженерного и архитектурного соавтора привлекались инструменты искусственного интеллекта.
    
**Лицензирование**

- Проект распространяется под свободной лицензией **MIT**. Код предоставляется по принципу AS IS, без каких-либо гарантий. Любое физическое или юридическое лицо имеет право свободно использовать, копировать, модифицировать, объединять, публиковать и распространять данную роль как в некоммерческих, так и в коммерческих целях.
