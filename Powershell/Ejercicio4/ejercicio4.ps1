<#
.SYNOPSIS
    Detecta, resguarda y elimina archivos duplicados dentro de un directorio.
.DESCRIPTION
    Monitorea un directorio y sus subdirectorios detectando la creación / movimiento de archivos duplicados.
    Si encuentra algún duplicado, lo registra en un log, lo comprime y resguarda en un comprimido para luego eliminarlo.
.PARAMETER directorio
    El directorio a monitorear (junto con sus subdirectorios). Debe existir previo a la ejecución del script.
.PARAMETER salida
    El directorio donde se guardaran las copias de los archivos que se detecten como duplicados en el directorio monitoreado. 
    Puede no existir previo a la ejecución del script.
.PARAMETER kill
    Un flag que indica que se debe detener el monitoreo del directorio provisto.
.EXAMPLE
   ./ejercicio4.ps1 -directorio ./test -salida ./backup
   (Para iniciar el monitoreo)
.EXAMPLE
   ./ejercicio4.ps1 -directorio ./test -kill
   (Para detener el monitoreo)
#>
param(
    [Parameter(Mandatory=$true, ParameterSetName="Salida")]
    [Parameter(Mandatory=$true, ParameterSetName="Kill")]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        if (-not (Test-Path -LiteralPath $_ -PathType Container)) {
            throw "El directorio '$_' no existe."
        }
        $true
    })]
    [string]$directorio,

    [Parameter(Mandatory=$true, ParameterSetName="Salida")]
    [ValidateNotNullOrEmpty()]
    [string]$salida,

    [Parameter(Mandatory=$true, ParameterSetName="Kill")]
    [switch]$kill,

    # Solo utilizado por el propio script para lanzar el daemon.
    [switch]$daemon
)

# ---------------------------------------------------------
# Preparación
# ---------------------------------------------------------

$directorio = (Resolve-Path $directorio).Path

# Se obtiene el pidfile, hasheando el nombre del directorio monitoreado.
$hash = [System.BitConverter]::ToString(
    [System.Security.Cryptography.MD5]::Create().ComputeHash(
        [System.Text.Encoding]::UTF8.GetBytes($directorio)
    )
).Replace("-", "").ToLower()

$tempDir = [System.IO.Path]::GetTempPath()
$pidFile = Join-Path $tempDir "monitoreo_$hash.pid"

# ---------------------------------------------------------
# Finalizar daemon
# ---------------------------------------------------------

if ($kill) {

    if (-not (Test-Path $pidFile)) {
        Write-Error "No hay un monitoreo ejecutándose sobre este directorio."
        exit 1
    }

    $pidDaemon = Get-Content $pidFile

    if (Get-Process -Id $pidDaemon -ErrorAction SilentlyContinue) {
        Stop-Process -Id $pidDaemon
        Write-Host "Monitoreo finalizado. PID: $pidDaemon"
    }
    else {
        Write-Error "El proceso asociado al monitoreo ya no existe."
    }

    Remove-Item $pidFile -Force
    exit 0
}

# ---------------------------------------------------------
# Iniciar daemon
# ---------------------------------------------------------

if (-not $daemon) {

    if (-not $salida) {
        Write-Error "Debe indicar el directorio de salida."
        exit 1
    }

    # Comprobar si ya existe un daemon para ESTE directorio.
    if (Test-Path $pidFile) {

        $pidDaemon = Get-Content $pidFile

        if (Get-Process -Id $pidDaemon -ErrorAction SilentlyContinue) {
            Write-Error "Ya existe un monitoreo ejecutándose sobre este directorio."
            exit 1
        }

        # El PID quedó obsoleto.
        Remove-Item $pidFile -Force
    }

    # Crear directorio de salida.
    New-Item -ItemType Directory -Path $salida -Force | Out-Null
    $salida = (Resolve-Path $salida).Path

    # Ruta del propio script.
    $script = $MyInvocation.MyCommand.Path

    # Obtener la ruta del ejecutable de PowerShell actual.
    $powerShellExe = (Get-Process -Id $PID).Path

    # Argumentos para iniciar el daemon.
    $argumentos = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$script`"",
        "-directorio", "`"$directorio`"",
        "-salida", "`"$salida`"",
        "-daemon"
    )

    # Parámetros comunes.
    $parametros = @{
        FilePath = $powerShellExe
        ArgumentList = $argumentos
        PassThru = $true
    }

    # Ocultar la ventana únicamente en Windows.
    if ($IsWindows) {
        $parametros.WindowStyle = "Hidden"
    }

    $proceso = Start-Process @parametros

    # Guardar PID asociado a este directorio.
    $proceso.Id | Set-Content $pidFile

    Write-Host "Monitoreo iniciado. PID: $($proceso.Id)"

    exit 0
}

# ---------------------------------------------------------
# Código del daemon
# ---------------------------------------------------------

# Se incluye el hash del directorio en el nombre
# por si dos directorios usan el mismo directorio de salida.
$log = Join-Path $salida "monitoreo_$hash.log"

$datos = @{
    directorio = $directorio
    salida = $salida
    log = $log
}

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $directorio
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

$accion = {

    $archivo = $Event.SourceEventArgs.FullPath
    $directorio = $Event.MessageData.directorio
    $salida = $Event.MessageData.salida
    $log = $Event.MessageData.log

    function Write-Log($mensaje) {
        Add-Content $log "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $mensaje"
    }

    # Puede haber sido eliminado por un evento anterior (Created + Changed).
    if (-not (Test-Path -LiteralPath $archivo -PathType Leaf)) {
        return
    }

    $info = Get-Item -LiteralPath $archivo

    $duplicados = Get-ChildItem -LiteralPath $directorio -File -Recurse |
        Where-Object {
            $_.Name -eq $info.Name -and
            $_.Length -eq $info.Length -and
            $_.FullName -ne $info.FullName
        }

    if (-not $duplicados) {
        return
    }

    Write-Log "Duplicado detectado: $archivo"

    $backup = Join-Path $salida "$(Get-Date -Format 'yyyyMMdd-HHmmss-fff').zip"

    $ok = $false
    $fsOrigen = $null; $fsZip = $null; $zip = $null; $entrada = $null

    try {
        $fsOrigen = [System.IO.File]::Open($archivo, 'Open', 'Read', 'ReadWrite')

        $fsZip = [System.IO.File]::Open($backup, 'Create', 'ReadWrite', 'None')
        $zip = New-Object System.IO.Compression.ZipArchive($fsZip, [System.IO.Compression.ZipArchiveMode]::Create)

        $entrada = $zip.CreateEntry($info.Name).Open()
        $fsOrigen.CopyTo($entrada)

        $ok = $true
    }
    catch {
        Write-Log "ERROR creando backup: $($_.Exception.Message)"
    }
    finally {
        if ($entrada)   { $entrada.Dispose() }
        if ($zip)       { $zip.Dispose() }
        if ($fsZip)     { $fsZip.Dispose() }
        if ($fsOrigen)  { $fsOrigen.Dispose() }
    }

    if (-not $ok) {
        Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
        return
    }

    Write-Log "Backup creado: $backup"

    try {
        Remove-Item -LiteralPath $archivo -ErrorAction Stop
        Write-Log "Archivo eliminado: $archivo"
    }
    catch {
        Write-Log "ERROR eliminando archivo: $($_.Exception.Message)"
    }
}

Register-ObjectEvent $watcher Created -Action $accion -MessageData $datos | Out-Null
Register-ObjectEvent $watcher Renamed -Action $accion -MessageData $datos | Out-Null
Register-ObjectEvent $watcher Changed -Action $accion -MessageData $datos | Out-Null

try {
    while ($true) {
        Wait-Event -Timeout 1 | Out-Null
    }
}
finally {
    Get-EventSubscriber | Unregister-Event
    Get-Job | Remove-Job -Force
    $watcher.Dispose()

    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
}