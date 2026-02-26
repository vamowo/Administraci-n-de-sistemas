#!/bin/bash
source ./menus_linux.sh
main_P() {
    while true; do
        echo -e "\n--- MENU DE PRACTICAS  ---"
        echo "1. DHCP"
        echo "2. DNS"
        echo "3. Salir"
        read -p "Seleccione una opción: " OPC

        case $OPC in
            1) menu_DHCP;;
            2) menu_DNS ;;
            3) exit 0 ;;
            *) echo "Opción no válida." ;;
        esac
    done
}
main_P