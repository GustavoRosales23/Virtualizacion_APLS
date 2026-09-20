<#
.SYNOPSIS
Busca archivos duplicados dentro de un directorio y sus subdirectorios.

.DESCRIPTION
El script analiza todos los archivos existentes dentro del directorio
indicado mediante el parametro -directorio, incluyendo sus subdirectorios.

Se considera que dos archivos estan duplicados cuando tienen el mismo
nombre y el mismo tamanio, sin importar su contenido.

Por cada archivo duplicado se muestra su nombre y los directorios en los
que fue encontrado.

.PARAMETER directorio
Ruta del directorio que se desea analizar.

La ruta puede ser relativa o absoluta y puede contener espacios.

.EXAMPLE
.\ejercicio3.ps1 -directorio ".\pruebas"

Busca archivos duplicados dentro del directorio ".\pruebas" y todos sus
subdirectorios.

.EXAMPLE
.\ejercicio3.ps1 -directorio "D:\Archivos de prueba"

Ejemplo utilizando una ruta absoluta que contiene espacios.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({
        if (-not (Test-Path -LiteralPath $_ -PathType Container)) {
            throw "El directorio '$_' no existe."
        }
        $true
    })]
    [string]$directorio
)

# =========================

function Ejercicio3 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directorio
    )

    try {
        $archivos = Get-ChildItem -LiteralPath $Directorio -File -Recurse -ErrorAction Stop
        $grupos = $archivos | Group-Object -Property Name, Length

        foreach ($grupo in $grupos) {

            if ($grupo.Count -gt 1) {
                Write-Output "FILENAME: $($grupo.Group[0].Name) SIZE: $($grupo.Group[0].Length)" -NoEnumerate
                foreach ($archivo in $grupo.Group) {
                    Write-Output $archivo.DirectoryName
                }
            }
        }
    }
    catch {
        Write-Error "Ocurrio un error al analizar el directorio: $($_.Exception.Message)"
    }
}

# =========================

Ejercicio3 -Directorio $directorio