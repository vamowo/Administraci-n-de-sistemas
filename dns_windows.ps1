
function Validar-IP($ip) {
    return $ip -match "^([0-9]{1,3}\.){3}[0-9]{1,3}$"
}
function Verificar-IPFija {
    $Interface = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1

    if (-not $Interface) {
        Write-Host "Error: No se detectó ninguna interfaz activa." -ForegroundColor Red
        return
    }

    $Config = Get-NetIPAddress -InterfaceAlias $Interface.Name -AddressFamily IPv4
    if ($Config.PrefixOrigin -eq "Dhcp") {
        Write-Host "No se detectó una IP fija en $($Interface.Name)." -ForegroundColor Yellow
        do {
            $IP_FIJA = Read-Host "Ingrese la IP fija para este servidor (ej. 198.100.30.10)"
        } while (-not (Validar-IP $IP_FIJA))

        $GW = Read-Host "Ingrese el Gateway"
        
        Write-Host "Configurando IP fija..."
        New-NetIPAddress -InterfaceAlias $Interface.Name -IPAddress $IP_FIJA -PrefixLength 24 -DefaultGateway $GW | Out-Null
        Write-Host "IP fija configurada: $IP_FIJA" -ForegroundColor Green
    } else {
        Write-Host "El servidor ya cuenta con una IP fija: $($Config.IPAddress)" -ForegroundColor Cyan
    }
}
function Instalar-DNS {
    $Feature = Get-WindowsFeature DNS
    if ($Feature.Installed) {
        Write-Host "El servicio DNS ya está instalado." -ForegroundColor Cyan
        $Accion = Read-Host "¿Desea reinstalar o pasar a la configuración? (r/c)"
        if ($Accion -eq "r") {
            Write-Host "Reinstalando DNS..." -ForegroundColor Yellow
            Uninstall-WindowsFeature DNS -Remove | Out-Null
            Install-WindowsFeature DNS -IncludeManagementTools | Out-Null
        }
    } else {
        Write-Host "Instalando rol DNS Server..." -ForegroundColor Yellow
        Install-WindowsFeature DNS -IncludeManagementTools | Out-Null
    }
    Write-Host "Servicio DNS listo." -ForegroundColor Green
}
function Crear-Dominio {
    $Dominio = Read-Host "Ingrese el dominio: "
    $IP_Cliente = Read-Host "Ingrese la IP :"
    $IP_Servidor = (Get-NetIPAddress -InterfaceAlias (Get-NetAdapter | Where-Object {$_.Status -eq "Up"}).Name -AddressFamily IPv4).IPAddress
    if($IP_Servidor -is [array]) { $IP_Servidor = $IP_Servidor[0] }
    if (Get-DnsServerZone -Name $Dominio -ErrorAction SilentlyContinue) {
        Write-Host "El dominio $Dominio ya existe." -ForegroundColor Red
        return
    }

    Add-DnsServerPrimaryZone -Name $Dominio -ZoneFile "$Dominio.dns"
    Start-Sleep -Seconds 1
    Add-DnsServerResourceRecordA -ZoneName $Dominio -Name "ns1" -IPv4Address $IP_Servidor
    Add-DnsServerResourceRecordA -ZoneName $Dominio -Name "www" -IPv4Address $IP_Cliente
    Add-DnsServerResourceRecordA -ZoneName $Dominio -Name "@" -IPv4Address $IP_Cliente

    Write-Host "Dominio $Dominio creado exitosamente." -ForegroundColor Green
}
function Eliminar-Dominio {
    $Dominio = Read-Host "Ingrese el dominio a eliminar"
    if (Get-DnsServerZone -Name $Dominio -ErrorAction SilentlyContinue) {
        Remove-DnsServerZone -Name $Dominio -Force
        Write-Host "Dominio $Dominio eliminado." -ForegroundColor Yellow
    } else {
        Write-Host "El dominio no existe." -ForegroundColor Red
    }
}

while ($true) {
    Write-Host " MENU ADMINISTRACION DNS " -ForegroundColor Cyan
    Write-Host "1. Verificar/Instalar Servicio e IP"
    Write-Host "2. Dar de alta un dominio"
    Write-Host "3. Eliminar un dominio"
    Write-Host "4. Listar dominios configurados"
    Write-Host "5. Salir"
    $Opc = Read-Host "Seleccione una opcion"

    switch ($Opc) {
        "1" { Verificar-IPFija; Instalar-DNS }
        "2" { Crear-Dominio }
        "3" { Eliminar-Dominio }
        "4" { 
	Write-Host "Dominios Configurados" -ForegroundColor Cyan
	Get-DnsServerZone | Where-Object { $_.IsAutoCreated -eq $false -and $_.ZoneName -ne "TrustAnchors" } | Select-Object ZoneName,ZoneType | Format-Table -AutoSize 
	}
        "5" { exit }
        Default { Write-Host "Opción no válida." }
    }
}
