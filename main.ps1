. .\mainmenus.ps1
while ($true) {
    Write-Host "`n--- MENU DE PRACTICAS ---" -ForegroundColor Cyan
    Write-Host "1.DHCP"
    Write-Host "2.DNS"
    Write-Host "3.Salir"
    
    $opcion = Read-Host "Seleccione una opcion 1-5"

    switch ($opcion) {
        "1" { DHCP_P}
        "2" { DNS_P }
        "3" { exit }
        Default { Write-Host "Opcion invalida" }
    }
    Read-Host "Presione Enter para continuar.."
}
