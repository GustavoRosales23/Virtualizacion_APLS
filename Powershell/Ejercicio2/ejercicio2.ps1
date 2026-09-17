<#
.Synopsis
   Multiplica o traspone una matriz a partir de un archivo de texto
.DESCRIPTION
   Multiplica o traspone una matriz a partir de un archivo de texto
.EXAMPLE
   pwsh ejercicio2.ps1 -matriz "test/matriz.txt" -separador '|' -trasponer
.EXAMPLE
   pwsh ejercicio2.ps1 -matriz "test/matriz.txt" -separador '|' -producto -5
.INPUTS
   -matriz     MATRIZ_PATH  indica la ruta al archivo con la matriz
   -separador  SEPARADOR    indica el separador de cada columna en la matriz. No puede contener números, guiones o puntos.
   -producto   ESCALAR      indica el valor por el que se multiplica la matriz. No puede usarse con -trasponer
   -trasponer  Traspone     la matriz. No puede usarse con -producto
.OUTPUTS
   Matriz modificada: se guarda un archivo con el formato salida.{nombre_original_de_la_matriz} que contiene la matriz modificada.
#>


[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true)]
	[ValidateNotNullOrEmpty()]
	[string] $matriz,

	[Parameter(Mandatory=$false)]
	[ValidateNotNullOrEmpty()]
	[Decimal] $producto,

	[Parameter(Mandatory=$false)]
	[ValidateNotNullOrEmpty()]
	[switch] $trasponer,

	[Parameter(Mandatory=$true)]
	[ValidateNotNullOrEmpty()]
	[ValidateScript({
		if ($_ -match '[0-9.-]') {
			throw 'El separador no puede contener puntos, guiones, o números.'
		}
		return $true;
	})]
	[string] $separador
)

function Error-Y-Exit() {
	param([string]$mensaje)
	Write-Host -Message $mensaje -ForeGroundColor Red
	exit 1
}

function Mostrar-Matriz() {
	param([object[]]$Matriz)

	foreach ($fila in $Matriz) {
		Write-Output ($fila -join $separador)
	}

}

$tieneProducto = $PSBoundParameters.ContainsKey('producto')
$tieneTrasponer = $PSBoundParameters.ContainsKey('trasponer')

if (-not $tieneProducto -and -not $tieneTrasponer) {
	Error-Y-Exit "Se debe utilizar -producto o -transponer."
}

if ($tieneProducto -and $tieneTrasponer) {
	Error-Y-Exit "No se puede utilizar -producto y -transponer al mismo tiempo."
}

if (-not (Test-Path -Path $matriz -PathType Leaf)) {
	Error-Y-Exit "La ruta a la matriz es inexistente."
}

$matriz_txt = Get-Content "$matriz"

if (! [bool] $matriz_txt) {
	Error-Y-Exit "El archivo $matriz está vacío."
}


# Parseo de la Matriz!
$matriz2D = @()
$columnas = $null;

foreach ($linea in $matriz_txt) {
	
	$valores = $linea.split($separador)

	if ($null -eq $columnas) {

		$columnas = $valores.Length
	} elseif ($columnas -ne $valores.length) {

		Error-Y-Exit "La matriz es inválida, no tiene la misma cantidad de elementos por fila"
	}

	$valoresDecimales = foreach ($valorStr in $valores) {

		$valor = $valorStr -as [decimal]

		if ($null -eq $valor) {
			Error-Y-Exit "La matriz es inválida, contiene elementos que no son números."
		}

		$valor # Inserta valor convertido a decimal en $valoresDecimales
	}
	
	$matriz2D += ,$valoresDecimales

}
$filas = $matriz2D.Length

Write-Host "Matriz ingresada: " -ForeGroundColor Yellow

Mostrar-Matriz $matriz2D

Write-Host ""

# Armamos la ruta al archivo destino
$directorio = [System.IO.Path]::GetDirectoryName($matriz)
if ("" -eq $directorio) {
	$directorio = "./"
}
$nombreArchivo = [System.IO.Path]::GetFileName($matriz)
$nuevaRuta = Join-Path $directorio "salida.$nombreArchivo"

if ($producto) {

	Write-Host "Matriz multiplicada por ${producto}: " -ForeGroundColor Green
	
	for ($i = 0; $i -lt $filas; $i++) {
		
		for ($j = 0; $j -lt $columnas; $j++) {

			$matriz2D[$i][$j] *= $producto;
		}
	}

	Mostrar-Matriz $matriz2D | Tee-Object -FilePath $nuevaRuta
} else {
	# Trasponer

	Write-Host "Matriz Traspuesta: " -ForeGroundColor Green
	# Inicializar matriz con dimensiones invertidas
	$matrizT = New-Object 'object[]' $columnas
	for ($i = 0; $i -lt $columnas; $i++) {
			$matrizT[$i] = New-Object 'object[]' $filas
	}
	
	for ($i = 0; $i -lt $filas; $i++) {
		for ($j = 0; $j -lt $columnas; $j++) {
			$matrizT[$j][$i] = $matriz2D[$i][$j]
		}
	}

	Mostrar-Matriz $matrizT | Tee-Object -FilePath $nuevaRuta
}