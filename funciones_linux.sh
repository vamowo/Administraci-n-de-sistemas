#!/bin/bash
source ./validarip.sh
instalar_dhcp() {
    echo "Verificando si el servicio ya está instalado..."
    if rpm -q dhcp-server &> /dev/null; then
        read -p "El servicio ya existe. ¿Desea reinstalar? (s/n): " ACCION
        if [ "$ACCION" == "s" ]; then
            dnf reinstall -y dhcp-server &> /dev/null
        fi
    else
        echo "Instalando DHCP Server..."
        dnf install -y dhcp-server &> /dev/null
    fi
}
pedir_ip() {
    local PROMPT=$1
    local IP_MINIMA=$2
    local IPS_PROHIBIDAS="0.0.0.0 1.0.0.0 127.0.0.0 127.0.0.1 255.255.255.255"
    
    while true; do
        read -p "$PROMPT" IP_INPUT
        if ! validarip "$IP_INPUT"; then
            echo "Formato de IP inválido."
            continue
        fi

        local ES_PROHIBIDA=false
        for ip in $IPS_PROHIBIDAS; do
            [[ "$IP_INPUT" == "$ip" ]] && ES_PROHIBIDA=true
        done

        if [ "$ES_PROHIBIDA" = true ]; then
            echo "La IP $IP_INPUT es reservada o prohibida."
            continue
        fi

        if [ -n "$IP_MINIMA" ]; then
            local OCT_INI=$(echo $IP_MINIMA | cut -d. -f4)
            local OCT_FIN=$(echo $IP_INPUT | cut -d. -f4)
            if [ "$OCT_FIN" -le "$OCT_INI" ]; then
                echo "La IP final debe ser mayor a la inicial ($IP_MINIMA)."
                continue
            fi
        fi
        echo "$IP_INPUT"
        break
    done
}
configurar_dhcp() {
    echo "--- INICIO DE CONFIGURACIÓN ---"
    read -p "Nombre descriptivo del Ámbito (Scope): " SCOPE_NAME
    
    # Llamadas a la función de validación
    IP_INI=$(pedir_ip "Introduce la IP Inicial del rango: ")
    IP_FIN=$(pedir_ip "Introduce la IP Final del rango (debe ser mayor a $IP_INI): " "$IP_INI")
    
    read -p "Introduce la Puerta de Enlace (Opcional): " GW_OPT
    read -p "Introduce el Servidor DNS Primario (Opcional): " DNS1
    read -p "Introduce el Servidor DNS Secundario (Opcional): " DNS2
    
    while true; do
        read -p "Introduce el Tiempo de concesión en segundos (mínimo 30): " LEASE_TIME
        [[ "$LEASE_TIME" =~ ^[0-9]+$ ]] && [ "$LEASE_TIME" -ge 30 ] && break
        echo "Error: Debe ingresar un número mayor o igual a 30."
    done

    # Preparación de variables de red
    RED_BASE=$(echo $IP_INI | cut -d. -f1-3)
    PRIMER_OCTETO=$(echo $IP_INI | cut -d. -f4)
    IP_INICIO_CLIENTES=$((PRIMER_OCTETO + 1))

    # Configuración de red (nmcli)
    echo "Configurando Servidor con IP: $IP_INI"
    nmcli con mod "Conexión cableada 1" ipv4.addresses "$IP_INI/24" ipv4.method manual
    nmcli con up "Conexión cableada 1"

    # Creación del archivo dhcpd.conf
    {
        echo "option domain-name \"$SCOPE_NAME\";"
        
        # Concatenación inteligente de DNS
        DNS_STR=""
        [ -n "$DNS1" ] && DNS_STR="$DNS1"
        [ -n "$DNS2" ] && DNS_STR="${DNS_STR:+$DNS_STR, }$DNS2"
        [ -n "$DNS_STR" ] && echo "option domain-name-servers $DNS_STR;"
        
        echo "default-lease-time $LEASE_TIME;"
        echo "max-lease-time $((LEASE_TIME * 2));"
        echo "authoritative;"
        echo "subnet $RED_BASE.0 netmask 255.255.255.0 {"
        echo "  range $RED_BASE.$IP_INICIO_CLIENTES $IP_FIN;"
        [ -n "$GW_OPT" ] && echo "  option routers $GW_OPT;"
        echo "}"
    } > /etc/dhcp/dhcpd.conf

    # Aplicar cambios y monitorear
    if dhcpd -t &> /dev/null; then
        systemctl restart dhcpd
        systemctl enable dhcpd
        echo "Servicio configurado correctamente y en ejecución."
        echo "(Presiona Ctrl+C para detener el monitoreo)"
        tail -f /var/log/messages | grep --line-buffered -E "DHCPACK|DHCPOFFER"
    else
        echo "Error en la sintaxis del archivo de configuración."
    fi
}


listar_concesiones() {
    echo "Listando equipos conectados:"
    if [ -f /var/lib/dhcpd/dhcpd.leases ]; then
        awk '/^lease/ {ip=$2} /client-hostname/ {gsub(/[";]/,"",$2); print ip, $2}' /var/lib/dhcpd/dhcpd.leases
    else
        echo "No hay archivo de concesiones aún."
    fi
}

desinstalar_dhcp() {
    read -p "¿Está seguro de desinstalar DHCP? (s/n): " CONF
    if [ "$CONF" == "s" ]; then
        systemctl stop dhcpd
        dnf remove -y dhcp-server
    fi
}
#---FUNCIONES DNS---
verificar_ip_fija() {
    INTERFACE=$(nmcli -t -f DEVICE,STATE device | grep ":conectado" | cut -d: -f1 | head -n 1)

    if [ -z "$INTERFACE" ]; then
        echo "Error: No se detectó ninguna interfaz activa. Revisa la Red Interna."
        return
    fi

    METODO=$(nmcli -g ipv4.method con show "$INTERFACE")

    if [ "$METODO" != "manual" ]; then
        echo "No se detectó una IP fija configurada en $INTERFACE."
        while true; do
            read -p "Ingrese la IP fija para este servidor: " IP_FIJA
            validarip "$IP_FIJA" && break
            echo "IP inválida."
        done
        read -p "Ingrese el Gateway: " GW

        echo "Configurando IP fija en $INTERFACE..."
        nmcli con mod "$INTERFACE" ipv4.addresses "$IP_FIJA/24" ipv4.gateway "$GW" ipv4.method manual &> /dev/null
        nmcli con up "$INTERFACE" &> /dev/null
        echo "IP fija configurada: $IP_FIJA"
    else
        echo "El servidor ya cuenta con una IP fija en $INTERFACE."
    fi
}

instalar_bind() {
    if rpm -q bind &> /dev/null; then
        echo "BIND9 ya está instalado."
        read -p "¿Desea reinstalar o pasar a la configuración? (r/c): " ACCION
        if [ "$ACCION" == "r" ]; then
            echo "Reinstalando BIND9..."
            dnf reinstall -y bind bind-utils &> /dev/null
        fi
    else
        echo "Instalando BIND9 y utilerías..."
        dnf install -y bind bind-utils &> /dev/null
    fi

    sed -i 's/listen-on port 53 { 127.0.0.1; };/listen-on port 53 { any; };/' /etc/named.conf
    sed -i 's/allow-query     { localhost; };/allow-query     { any; };/' /etc/named.conf

    systemctl enable named &> /dev/null
    systemctl restart named &> /dev/null
}

crear_dominio() {
    read -p "Ingrese el dominio: " DOMINIO
    read -p "Ingrese la IP a la que resolvera: " IP_CLIENTE

    if grep -q "$DOMINIO" /etc/named.rfc1912.zones; then
        echo "El dominio $DOMINIO ya existe."
        return
    fi

    cat <<EOF >> /etc/named.rfc1912.zones
zone "$DOMINIO" IN {
    type master;
    file "$DOMINIO.zone";
    allow-update { none; };
};
EOF

    FILE="/var/named/$DOMINIO.zone"
    IP_NS=$(hostname -I | awk '{print $1}')

    cat <<EOF > $FILE
\$TTL 1D
@       IN SOA  ns1.$DOMINIO. admin.$DOMINIO. (
                                        2026021901 ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
@       IN NS   ns1.$DOMINIO.
ns1     IN A    $IP_NS
@       IN A    $IP_CLIENTE
www     IN A    $IP_CLIENTE
EOF

    chown named:named $FILE
    chmod 660 $FILE

    named-checkconf /etc/named.conf && systemctl restart named
    echo "Dominio $DOMINIO creado exitosamente apuntando a $IP_CLIENTE."
}

eliminar_dominio() {
    read -p "Ingrese el dominio a eliminar: " DOMINIO
    sed -i "/zone \"$DOMINIO\"/,/};/d" /etc/named.rfc1912.zones
    rm -f /var/named/$DOMINIO.zone
    systemctl restart named
    echo "Dominio $DOMINIO eliminado."
}
