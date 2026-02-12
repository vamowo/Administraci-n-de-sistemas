function Mostrar-Menu {
    Write-Host " "
    Write-Host "--- MENU DE ADMINISTRACION DHCP ---" -ForegroundColor Cyan
    Write-Host "1 Configurar e Instalar Servicio"
    Write-Host "2 Consultar estado en tiempo real"
    Write-Host "3 Listar concesiones activas"
    Write-Host "4 Desinstalar el servicio"
    Write-Host "5 Salir"
}

$IPS_PROHIBIDAS = @("0.0.0.0", "1.0.0.0", "127.0.0.0", "127.0.0.1", "255.255.255.255")

while ($true) {
    Mostrar-Menu
    $opcion = Read-Host "Seleccione una opcion 1-5"

    if ($opcion -eq "1") {
        Write-Host "Instalando DHCP..."
        Install-WindowsFeature -Name DHCP -IncludeManagementTools -ErrorAction SilentlyContinue

        $scopeName = Read-Host "Nombre del Ambito"
        
        while ($true) {
            $ipIni = Read-Host "IP Inicial"
            if ($ipIni -in $IPS_PROHIBIDAS) { Write-Host "IP Prohibida" }
            elseif ($ipIni -as [ipaddress]) { break }
        }

        while ($true) {
            $ipFin = Read-Host "IP Final"
            $octIni = ($ipIni -split '\.')[3]
            $octFin = ($ipFin -split '\.')[3]
            if ([int]$octFin -gt [int]$octIni) { break }
            else { Write-Host "La IP final debe ser mayor" }
        }

        $gw = Read-Host "Gateway (Opcional)"
        $dns = Read-Host "DNS (Opcional)"
        $lease = Read-Host "Segundos de concesion (min 30)"

        $interface = Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object -First 1
        New-NetIPAddress -InterfaceAlias $interface.Name -IPAddress $ipIni -PrefixLength 24 -ErrorAction SilentlyContinue

        $redBase = $ipIni.Substring(0,$ipIni.LastIndexOf('.'))
        $ipInicioClientes = "$redBase.$([int]$octIni + 1)"
        
        Add-DhcpServerv4Scope -Name $scopeName -StartRange $ipInicioClientes -EndRange $ipFin -SubnetMask 255.255.255.0 -LeaseDuration ([TimeSpan]::FromSeconds($lease))
        
        if ($gw) { Set-DhcpServerv4OptionValue -OptionId 3 -Value $gw }
        if ($dns) { Set-DhcpServerv4OptionValue -OptionId 6 -Value $dns }

        Restart-Service DHCPServer
        Write-Host "Configuracion completada."
    }
    elseif ($opcion -eq "2") { Get-Service DHCPServer }
    elseif ($opcion -eq "3") { Get-DhcpServerv4Scope | Get-DhcpServerv4Lease }
    elseif ($opcion -eq "4") { Uninstall-WindowsFeature -Name DHCP }
    elseif ($opcion -eq "5") { break }
    else { Write-Host "Opcion invalida" }

    Read-Host "Presione Enter para continuar"
}