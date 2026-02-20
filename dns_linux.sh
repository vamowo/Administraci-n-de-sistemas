#!/bin/bash
source validarip.sh
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

    # Agregar a named.rfc1912.zones
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

    # 2. Crear archivo de zona
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

while true; do
    echo -e "\n MENU ADMINISTRACION DNS "
    echo "1. Verificar/Instalar Servicio e IP"
    echo "2. Dar de alta un dominio"
    echo "3. Eliminar un dominio"
    echo "4. Listar dominios configurados"
    echo "5. Salir"
    read -p "Seleccione una opcion: " OPC

    case $OPC in
        1) verificar_ip_fija; instalar_bind ;;
        2) crear_dominio ;;
        3) eliminar_dominio ;;
        4) grep "zone" /etc/named.rfc1912.zones | awk '{print $2}' | tr -d '"' ;;
        5) exit 0 ;;
        *) echo "Opción no válida." ;;
    esac
done
