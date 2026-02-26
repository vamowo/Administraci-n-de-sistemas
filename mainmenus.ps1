. .\funciones_w.ps1
. .\validarip.ps1

function DHCP_P {
while ($true) {
    Write-Host "`n--- MENU DE ADMINISTRACION DHCP ---" -ForegroundColor Cyan
    Write-Host "1 Configurar e Instalar Servicio"
    Write-Host "2 Consultar estado en tiempo real"
    Write-Host "3 Listar concesiones activas"
    Write-Host "4 Desinstalar el servicio"
    Write-Host "5 Salir"
    
    $opcion = Read-Host "Seleccione una opcion 1-5"

    switch ($opcion) {
        "1" { Ejecutar-Configuracion }
        "2" { Get-Service DHCPServer }
        "3" { Get-DhcpServerv4Scope | Get-DhcpServerv4Lease }
        "4" { Uninstall-WindowsFeature -Name DHCP }
        "5" { return }
        Default { Write-Host "Opcion invalida" }
    }
    Read-Host "Presione Enter para continuar.."
}
}

function DNS_P {
while ($true) {
    Write-Host "`n--- MENU ADMINISTRACION DNS ---" -ForegroundColor Cyan
    Write-Host "1. Verificar/Instalar Servicio e IP"
    Write-Host "2. Dar de alta un dominio"
    Write-Host "3. Eliminar un dominio"
    Write-Host "4. Listar dominios configurados"
    Write-Host "5. Salir"
    
    $Opc = Read-Host "Seleccione una opcion"

    switch ($Opc) {
        "1" { Verificar-IPFija; Instalar-DNS }
        "2" { Configurar-NuevoDominio }
        "3" { 
            $Dom = Read-Host "Dominio a eliminar"
            if (Get-DnsServerZone -Name $Dom -ErrorAction SilentlyContinue) { 
                Remove-DnsServerZone -Name $Dom -Force 
            } else { Write-Host "No existe." -ForegroundColor Red }
        }
        "4" { Listar-Dominios }
        "5" { return }
        Default { Write-Host "Opción no válida." }
    }
    Read-Host "Presione Enter para continuar.."
}
}