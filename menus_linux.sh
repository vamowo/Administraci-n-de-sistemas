#!/bin/bash
source ./funciones_linux.sh
source ./validarip.sh 

menu_DHCP() {
  while true; do
    echo "--- MENÚ DE ADMINISTRACIÓN DHCP ---"
    echo "1) Configurar / Instalar Servicio"
    echo "2) Consultar estado en tiempo real"
    echo "3) Listar concesiones activas"
    echo "4) Desinstalar el servicio"
    echo "5) Salir"



    read -p "Seleccione una opción 1-5: " OPCION
    case $OPCION in
        1) instalar_dhcp && configurar_dhcp ;;
        2) systemctl status dhcpd --no-pager ;;
        3) listar_concesiones ;;
        4) desinstalar_dhcp ;;
        5) return ;;
        *) echo "Opción no válida." ;;
    esac
done
}
#---MENU DNS ---
menu_DNS() {
    while true; do
        echo -e "\n--- MENU ADMINISTRACION DNS  ---"
        echo "1. Verificar/Instalar Servicio e IP"
        echo "2. Dar de alta un dominio"
        echo "3. Eliminar un dominio"
        echo "4. Listar dominios configurados"
        echo "5. Salir"
        read -p "Seleccione una opción: " OPC

        case $OPC in
            1) verificar_ip_fija; instalar_bind ;;
            2) crear_dominio ;;
            3) eliminar_dominio ;;
            4) grep "zone" /etc/named.rfc1912.zones | awk '{print $2}' | tr -d '"' ;;
            5) return ;;
            *) echo "Opción no válida." ;;
        esac
    done
}