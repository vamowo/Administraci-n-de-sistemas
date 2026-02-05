#!/bin/bash
echo "INFORMACION"
echo "Nombre del equipo:$(hostname)"
echo "IP (red interna):"$(ip addr show enp0s8 | grep -w 'inet'| awk '{print $2}')
echo "Espacio en disco:"
df -h / | tail -n 1 | awk '{print "Total: "$2" | Usado "$3" | Libre: "$4}'
