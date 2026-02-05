Write-Host "INFORMACION "
Write-Host "Nombre del equipo:"
hostname
Write-Host "IP (red interna):"
(Get-NetIPAddress -AddressFamily IPv4)[0].IPAddress
Write-Host "Espacio en disco:"
Get-PSDrive C -PSProvider FileSystem
