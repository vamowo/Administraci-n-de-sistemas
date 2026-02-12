#!/bin/bash
source validarip.sh
mostrar_menu() {
    echo "   MENÚ DE ADMINISTRACIÓN DHCP "
    echo "1) Configurar / Instalar Servicio"
    echo "2) Consultar estado en tiempo real"
    echo "3) Listar concesiones (Leases) activas"
    echo "4) Desinstalar el servicio"
    echo "5) Salir"
}

while true; do
    mostrar_menu
    read -p "Seleccione una opción 1-5: " OPCION

    case $OPCION in
        1)
            echo "Verificando si el servicio ya esta instalado..."
            REINSTALAR="n"
            if rpm -q dhcp-server &> /dev/null; then
                echo "El servicio DHCP ya está instalado."
                read -p "¿Desea reinstalar o seguir a la configuración? (r/c): " ACCION
                if [ "$ACCION" == "r" ]; then
                    dnf reinstall -y dhcp-server
                    REINSTALAR="s"
                fi
            else
                echo "Instalando DHCP Server..."
                dnf install -y dhcp-server
                REINSTALAR="s"
            fi

            echo "INICIO DE CONFIGURACIÓN"
            read -p "Nombre descriptivo del Ámbito (Scope): " SCOPE_NAME

              IPS_PROHIBIDAS="0.0.0.0 1.0.0.0 127.0.0.0 127.0.0.1 255.255.255.255"
            while true; do
 		 read -p "Introduce la IP Inicial del rango: " IP_INI
                ES_PROHIBIDA=false
                for ip in $IPS_PROHIBIDAS; do
                    [[ "$IP_INI" == "$ip" ]] && ES_PROHIBIDA=true
                done

                if validarip "$IP_INI" && [ "$ES_PROHIBIDA" = false ]; then
                    break
                else
                    echo "Esta IP no se puede usar o es reservada, ingrese una nueva."
                fi
            done
            while true; do
                read -p "Introduce la IP Final del rango: " IP_FIN
                ES_PROHIBIDA=false
                for ip in $IPS_PROHIBIDAS; do
                    [[ "$IP_FIN" == "$ip" ]] && ES_PROHIBIDA=true
                done

                if validarip "$IP_FIN" && [ "$ES_PROHIBIDA" = false ]; then
                    OCT_INI=$(echo $IP_INI | cut -d. -f4)
                    OCT_FIN=$(echo $IP_FIN | cut -d. -f4)
                    if [ "$OCT_FIN" -gt "$OCT_INI" ]; then
                        break
                    else
                        echo "Error: La IP final debe ser mayor a la IP inicial ($IP_INI)."
                    fi
                else
                    echo "Esta IP no se puede usar, ingrése una nueva."
                fi
            done

            read -p "Introduce la Puerta de Enlace (Opcional): " GW_OPT
            read -p "Introduce el Servidor DNS (Opcional): " DNS_OPT

            while true; do
 	     read -p "Introduce el Tiempo de concesión en segundos (mínimo 30): " LEASE_TIME
                if [[ "$LEASE_TIME" =~ ^[0-9]+$ ]] && [ "$LEASE_TIME" -ge 30 ]; then
                    break
                else
                    echo "Debe ingresar mas de 30 segundos de tiempo."
                fi
            done

            RED_BASE=$(echo $IP_INI | cut -d. -f1-3)
            PRIMER_OCTETO=$(echo $IP_INI | cut -d. -f4)
            IP_SERVIDOR=$IP_INI
            IP_INICIO_CLIENTES=$((PRIMER_OCTETO + 1))

            echo "Configurando Servidor con IP: $IP_SERVIDOR"
            nmcli con mod "Conexión cableada 1" ipv4.addresses "$IP_SERVIDOR/24" ipv4.method manual
            nmcli con up "Conexión cableada 1"
            # Configuracion del archivo dhcpd.conf
            echo "option domain-name \"$SCOPE_NAME\";" > /etc/dhcp/dhcpd.conf
            [ -n "$DNS_OPT" ] && echo "option domain-name-servers $DNS_OPT;" >> /etc/dhcp/dhcpd.conf

            echo "default-lease-time $LEASE_TIME;" >> /etc/dhcp/dhcpd.conf
            echo "max-lease-time $((LEASE_TIME * 2));" >> /etc/dhcp/dhcpd.conf
            echo "authoritative;" >> /etc/dhcp/dhcpd.conf

            echo "subnet $RED_BASE.0 netmask 255.255.255.0 {" >> /etc/dhcp/dhcpd.conf
            echo "  range $RED_BASE.$IP_INICIO_CLIENTES $IP_FIN;" >> /etc/dhcp/dhcpd.conf
            [ -n "$GW_OPT" ] && echo "  option routers $GW_OPT;" >> /etc/dhcp/dhcpd.conf
            echo "}" >> /etc/dhcp/dhcpd.conf

            dhcpd -t &> /dev/null && systemctl restart dhcpd
            systemctl enable dhcpd

            echo "Servicio configurado correctamente y en ejecucion"
            echo "(Presiona Ctrl+C para detener el monitoreo )"
            tail -f /var/log/messages | grep --line-buffered -E "DHCPACK|DHCPOFFER"
            ;;

        2)
            echo "Estado del servicio DHCP:"
            systemctl status dhcpd --no-pager
            ;;
        3)
            echo "Listando equipos conectados (concesiones):"
            if [ -f /var/lib/dhcpd/dhcpd.leases ]; then
                cat /var/lib/dhcpd/dhcpd.leases | grep "lease\|hostname"
            else
                echo "No hay archivo de concesiones aún."
            fi
            ;;
        4)
            read -p "¿Está seguro de desinstalar DHCP? (s/n): " CONF
            if [ "$CONF" == "s" ]; then
                systemctl stop dhcp-server
                dnf remove -y dhcp-server
                echo "Servicio desinstalado."
            fi
            ;;
        5)
            echo "Saliendo..."
            exit 0
            ;;
        *)
            echo "Opción no válida."
            ;;
    esac
    echo ""
    read -p "Presione Enter para continuar..."
done
