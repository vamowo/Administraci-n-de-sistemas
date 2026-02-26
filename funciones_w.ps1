# --- FUNCIONES DNS ---

function Validar-IP($ip) {
    return $ip -match "^([0-9]{1,3}\.){3}[0-9]{1,3}$"
}

function Verificar-IPFija {
    $Interface = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
    if (-not $Interface) { Write-Host "Error: No hay interfaz activa." -ForegroundColor Red; return }

    $Config = Get-NetIPAddress -InterfaceAlias $Interface.Name -AddressFamily IPv4
    if ($Config.PrefixOrigin -eq "Dhcp") {
        do { $IP_FIJA = Read-Host "Ingrese la IP fija para este servidor" } while (-not (Validar-IP $IP_FIJA))
        $GW = Read-Host "Ingrese el Gateway"
        New-NetIPAddress -InterfaceAlias $Interface.Name -IPAddress $IP_FIJA -PrefixLength 24 -DefaultGateway $GW | Out-Null
    }
}

function Instalar-DNS {
    $Feature = Get-WindowsFeature DNS
    if ($Feature.Installed) {
        $Accion = Read-Host "¿Desea reinstalar (r) o continuar (c)?"
        if ($Accion -eq "r") {
            Uninstall-WindowsFeature DNS -Remove | Out-Null
            Install-WindowsFeature DNS -IncludeManagementTools | Out-Null
        }
    } else {
        Install-WindowsFeature DNS -IncludeManagementTools | Out-Null
    }
}

function Configurar-NuevoDominio {
    $Dominio = Read-Host "Ingrese el dominio"
    $IP_Cliente = Read-Host "Ingrese la IP del cliente"
    $IP_Servidor = (Get-NetIPAddress -InterfaceAlias (Get-NetAdapter | Where-Object {$_.Status -eq "Up"}).Name -AddressFamily IPv4).IPAddress
    if($IP_Servidor -is [array]) { $IP_Servidor = $IP_Servidor[0] }

    if (Get-DnsServerZone -Name $Dominio -ErrorAction SilentlyContinue) {
        Write-Host "El dominio ya existe." -ForegroundColor Red; return
    }

    Add-DnsServerPrimaryZone -Name $Dominio -ZoneFile "$Dominio.dns"
    Start-Sleep -Seconds 1
    Add-DnsServerResourceRecordA -ZoneName $Dominio -Name "ns1" -IPv4Address $IP_Servidor
    Add-DnsServerResourceRecordA -ZoneName $Dominio -Name "www" -IPv4Address $IP_Cliente
    Add-DnsServerResourceRecordA -ZoneName $Dominio -Name "@" -IPv4Address $IP_Cliente
    Write-Host "Dominio creado con éxito." -ForegroundColor Green
}

function Listar-Dominios {
    Write-Host "Dominios Configurados" -ForegroundColor Cyan
    Get-DnsServerZone | Where-Object { $_.IsAutoCreated -eq $false -and $_.ZoneName -ne "TrustAnchors" } | Select-Object ZoneName,ZoneType | Format-Table -AutoSize
}
#---FUNCIONES DHCP----

function Obtener-Configuracion {
    # Esta función agrupa toda la entrada de datos
    $config = @{}
    $config.scopeName = Read-Host "Nombre del Ambito"
    $config.ipIni = Read-Host "IP Inicial"
    $config.ipFin = Read-Host "IP Final"
    $config.gw = Read-Host "Gateway (Opcional)"
    $config.dns1 = Read-Host "DNS Primario (Opcional)"
    $config.dns2 = Read-Host "DNS Secundario (Opcional)"
    $config.lease = Read-Host "Segundos de concesion (min 30)"
    return $config
}

function Instalar-Servicio {
    $feature = Get-WindowsFeature -Name DHCP
    if($feature.Installed) {
        Write-Host "El servicio DHCP ya esta instalado"
        $accion = Read-Host "Desea reinstalar o seguir a la configuracion? (r/c)"
        if ($accion -eq "r") {
            Remove-WindowsFeature -Name DHCP -ErrorAction SilentlyContinue
            Install-WindowsFeature -Name DHCP -IncludeManagementTools
        }
    } else {
        Install-WindowsFeature -Name DHCP -IncludeManagementTools -ErrorAction SilentlyContinue
    }
}

function Ejecutar-Configuracion {
    Instalar-Servicio
    $cfg = Obtener-Configuracion
    $interfaceName = "Ethernet 2"
    $interface = Get-NetAdapter -Name $interfaceName -ErrorAction SilentlyContinue
    Remove-NetIPAddress -InterfaceAlias $interface.Name -Confirm:$false -ErrorAction SilentlyContinue
    Set-NetIPInterface -InterfaceAlias $interface.Name -DHCP Disabled 
    New-NetIPAddress -InterfaceAlias $interface.Name -IPAddress $cfg.ipIni -PrefixLength 24 | Out-Null
    

    $redBase = $cfg.ipIni.Substring(0,$cfg.ipIni.LastIndexOf('.'))
    $octIni = ($cfg.ipIni -split '\.')[3]
    $ipInicioClientes = "$redBase.$([int]$octIni + 1)"
    
    Remove-DhcpServerv4Scope -ScopeId "$redBase.0" -Force -ErrorAction SilentlyContinue
    Add-DhcpServerv4Scope -Name $cfg.scopeName -StartRange $ipInicioClientes -EndRange $cfg.ipFin -SubnetMask 255.255.255.0 -LeaseDuration ([TimeSpan]::FromSeconds($cfg.lease))
    
    if ($cfg.gw) { Set-DhcpServerv4OptionValue -OptionId 3 -Value $cfg.gw }
    
    $listaDns = @()
    if ($cfg.dns1) { $listaDns += $cfg.dns1 }
    if ($cfg.dns2) { $listaDns += $cfg.dns2 }
    if ($listaDns.Count -gt 0) { Set-DhcpServerv4OptionValue -OptionId 6 -Value $listaDns -Force }
    
    Restart-Service DHCPServer
    Write-Host "Configuracion completada."
}