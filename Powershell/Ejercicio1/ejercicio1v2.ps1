<#
.SYNOPSIS
Procesa las jugadas de distintas agencias de loteria y obtiene las jugadas
con 5, 4 o 3 aciertos.

.DESCRIPTION
El script procesa todos los archivos CSV de jugadas ubicados en el directorio
indicado mediante el parametro -directorio.

Cada archivo CSV representa una agencia y debe contener las jugadas con el
siguiente formato:

    id,n1,n2,n3,n4,n5

El script compara los numeros de cada jugada con los numeros almacenados en
NumerosGanadores.csv y clasifica las jugadas que tengan 5, 4 o 3 aciertos.

El resultado se genera en formato JSON.

La salida puede mostrarse por pantalla utilizando -pantalla o guardarse en
un archivo utilizando -archivo. Estos parametros son mutuamente excluyentes.

.PARAMETER directorio
Ruta del directorio que contiene los archivos CSV correspondientes a las
agencias.

La ruta puede ser relativa o absoluta y puede contener espacios.

.PARAMETER archivo
Ruta completa del archivo JSON donde se guardara el resultado.

Debe incluir tanto la ruta como el nombre del archivo.

Este parametro no puede utilizarse junto con -pantalla.

.PARAMETER pantalla
Indica que el resultado debe mostrarse por pantalla en formato JSON.

Cuando se utiliza este parametro no se genera un archivo de salida.

Este parametro no puede utilizarse junto con -archivo.

.PARAMETER rutaGanadores
Ruta del archivo CSV que contiene los 5 numeros ganadores.

Este parametro es opcional.

Si no se especifica, el script busca un archivo llamado
"NumerosGanadores.csv" en el directorio actual de ejecucion.

.EXAMPLE
.\ejercicio1v2.ps1 -directorio ".\Jugadas" -pantalla

Procesa los archivos CSV ubicados en ".\Jugadas" y muestra el resultado
en formato JSON por pantalla.

.EXAMPLE
.\ejercicio1v2.ps1 -directorio ".\Jugadas" -archivo ".\resultado.json"

Procesa los archivos CSV ubicados en ".\Jugadas" y guarda el resultado
en el archivo ".\resultado.json".

.EXAMPLE
.\ejercicio1v2.ps1 -directorio "D:\Jugadas de loteria" -pantalla

Ejemplo utilizando una ruta absoluta que contiene espacios.

.EXAMPLE
.\ejercicio1v2.ps1 -directorio ".\Jugadas" -rutaGanadores ".\Ganadores.csv" -pantalla

Procesa las jugadas utilizando el archivo ".\Ganadores.csv" como archivo
de numeros ganadores.

.NOTES
El archivo NumerosGanadores.csv debe contener exactamente 5 numeros
separados por coma.

Los archivos de las agencias no deben contener encabezado.

El nombre de cada archivo CSV se utiliza como identificador de la agencia.
#>

[CmdletBinding(DefaultParameterSetName = "Pantalla")]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({
        if (-not (Test-Path -LiteralPath $_ -PathType Container)) {
            throw "El directorio '$_' no existe."
        }
        $true
    })]
    [string]$directorio,

    [Parameter(Mandatory = $true, ParameterSetName = "Archivo")]
    [ValidateNotNullOrEmpty()]
    [string]$archivo,

    [Parameter(Mandatory = $true, ParameterSetName = "Pantalla")]
    [switch]$pantalla,

    [Parameter(Mandatory = $false)]
    [ValidateScript({
        if (-not (Test-Path -LiteralPath $_ -PathType Leaf)) {
            throw "El archivo de numeros ganadores '$_' no existe."
        }
        $true
    })]
    [string]$rutaGanadores
)

# =========================

function Contar-Apariciones {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$NumerosJugada,

        [Parameter(Mandatory = $true)]
        [string[]]$NumerosGanadores
    )

    $cantidad = 0

    for ($i = 0; $i -lt $NumerosGanadores.Count; $i++) {
        if ($NumerosJugada[$i] -eq $NumerosGanadores[$i]) {
            $cantidad++
        }
    }

    return $cantidad
}

function Ejercicio1 {
    [CmdletBinding(DefaultParameterSetName = "Pantalla")]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.IO.FileInfo]$ArchivoEntrada,

        [Parameter(Mandatory = $true)]
        [string]$Directorio,

        [Parameter(Mandatory = $true)]
        [string]$RutaGanadores,

        [Parameter(Mandatory = $true, ParameterSetName = "Archivo")]
        [string]$ArchivoSalida,

        [Parameter(Mandatory = $true, ParameterSetName = "Pantalla")]
        [switch]$MostrarPantalla
    )

    begin {

        if (-not (Test-Path -LiteralPath $RutaGanadores -PathType Leaf)) {
            throw "No se encontró el archivo NumerosGanadores.csv en '$RutaGanadores'."
        }

        $contenidoGanadores = (Get-Content -LiteralPath $RutaGanadores -Raw).Trim()
        $numerosGanadores = $contenidoGanadores -split ','

        if ($numerosGanadores.Count -ne 5) {
            throw "NumerosGanadores.csv debe contener exactamente 5 números separados por coma."
        }

        $resultado = [ordered]@{
            "5_aciertos" = @()
            "4_aciertos" = @()
            "3_aciertos" = @()
        }
    }

    process {

        $agencia = [System.IO.Path]::GetFileNameWithoutExtension($ArchivoEntrada.Name)

        foreach ($linea in Get-Content -LiteralPath $ArchivoEntrada.FullName) {
            if ([string]::IsNullOrWhiteSpace($linea)) {
                continue
            }

            $campos = $linea -split ','

            # Formato esperado: id,n1,n2,n3,n4,n5
            if ($campos.Count -ne 6) {
                Write-Warning "Se omite una línea inválida en '$($ArchivoEntrada.Name)': $linea"
                continue
            }

            $numeroJugada = $campos[0]
            $numerosJugada = $campos[1..5]

            $cantidadAciertos = Contar-Apariciones `
                -NumerosJugada $numerosJugada `
                -NumerosGanadores $numerosGanadores

            if ($cantidadAciertos -ge 3) {
                $jugadaEncontrada = [PSCustomObject]@{
                    agencia = $agencia
                    jugada  = $numeroJugada
                }

                switch ($cantidadAciertos) {
                    5 { $resultado["5_aciertos"] += $jugadaEncontrada }
                    4 { $resultado["4_aciertos"] += $jugadaEncontrada }
                    3 { $resultado["3_aciertos"] += $jugadaEncontrada }
                }
            }
        }
    }

    end {

        $json = $resultado | ConvertTo-Json -Depth 5

        if ($PSCmdlet.ParameterSetName -eq "Archivo") {
            $json | Set-Content -LiteralPath $ArchivoSalida -Encoding UTF8
        }
        elseif ($PSCmdlet.ParameterSetName -eq "Pantalla") {
            $json
        }
    }
}

# =========================

if (-not $rutaGanadores) {
    $nombreArchivoGanadores = "NumerosGanadores.csv"
    $rutaGanadores = Join-Path -Path (Get-Location) -ChildPath $nombreArchivoGanadores
}

$archivosJugadas = Get-ChildItem -LiteralPath $directorio -Filter "*.csv" -File |
    Where-Object { $_.Name -ne $nombreArchivoGanadores } # Por si esta en la misma carpeta

if ($PSCmdlet.ParameterSetName -eq "Archivo") {
    $archivosJugadas | Ejercicio1 `
        -Directorio $directorio `
        -RutaGanadores $rutaGanadores `
        -ArchivoSalida $archivo
}
elseif ($PSCmdlet.ParameterSetName -eq "Pantalla") {
    $archivosJugadas | Ejercicio1 `
        -Directorio $directorio `
        -RutaGanadores $rutaGanadores `
        -MostrarPantalla
}
