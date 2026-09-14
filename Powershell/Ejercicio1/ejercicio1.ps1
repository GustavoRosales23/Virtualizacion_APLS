#Script que aplica validaciones sobre archivos CSV

function Validar_Jugadas() {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if ($_ -notlike "*.csv") {
                throw "El archivo debe tener una extensión .csv"
            }
            if (-not (Test-Path -Path $_ -PathType Leaf)) {
                throw "La ruta no existe o no es un archivo válido."
            }
            $true
        })]
        [string]$Resultados
    )

    Begin {
        
        # 1. Solicitar la cantidad de inputs
        [int]$CantidadJugadas = 0
        while ($CantidadJugadas -le 0) {
            $inputCantidad = Read-Host "Indique la cantidad de inputs de jugadas a ingresar"
            if (-not [int]::TryParse($inputCantidad, [ref]$CantidadJugadas) -or $CantidadJugadas -le 0) {
                Write-Warning "Por favor, ingrese un número entero mayor a cero."
            }
        }

        #Definir una lista de jugadas
        $Jugadas = @()

      
        for ($i = 1; $i -le $CantidadJugadas; $i++) {
            $RutaValida = $false
            
            while (-not $RutaValida) {
                $RutaInput = Read-Host "Ingrese la ruta para el input número $i"
                
   
                $RutaLimpia = $RutaInput.Trim('"')
                $NombreArchivo = Split-Path -Path $RutaLimpia -Leaf

                
                if ($NombreArchivo -notmatch '^\d+\.csv$') {
                    Write-Warning "El archivo '$NombreArchivo' debe tener un formato numérico válido (Ej: 1.csv, 2.csv)."
                    continue # Vuelve a pedir la ruta de esta jugada
                }

        
                if (-not (Test-Path -Path $RutaLimpia -PathType Leaf)) {
                    Write-Warning "La ruta '$RutaLimpia' no existe o no es un archivo válido."
                    continue # Vuelve a pedir la ruta de esta jugada
                }

                $Jugadas += $RutaLimpia
                $RutaValida = $true
            }
        }
    }

    Process {
        $UniversoJugadas = New-Object System.Collections.Generic.List[PSCustomObject]
        $numsGanadores = ([System.IO.File]::ReadAllText($Resultados).Trim() -split ',')

        foreach ($Ruta in $Jugadas) {
            $NumeroAgencia = [regex]::Match($Ruta, '\d+').Value

            foreach ($Linea in [System.IO.File]::ReadLines($Ruta)) {
                if (-not [string]::IsNullOrWhiteSpace($Linea)) {
                   
                   $Campos = $Linea.Split(',')
                   $NumeroJugada   = $Campos[0]
                   $NumerosJugados = $Campos[1..($Campos.Count - 1)]

                   $NumsAcertados = $NumerosJugados | Where-Object { $_ -in $numsGanadores }
                   $CantidadAciertos = @($NumsAcertados).Count

                   if ($CantidadAciertos -ge 3) {
                        $UniversoJugadas.Add([PSCustomObject]@{
                            agencia          = $NumeroAgencia
                            jugada           = $NumeroJugada
                            CantidadAciertos = $CantidadAciertos
                        })
                   }
                  }
                }
              }

        
        #Creacion de un Hash Map
        
        $ResultadoFinal = [ordered]@{
            "5_aciertos" = @()
            "4_aciertos" = @()
            "3_aciertos" = @()
        }

        $Agrupados = $UniversoJugadas | Group-Object CantidadAciertos

        foreach ($Grupo in $Agrupados) {
            $Clave = "$($Grupo.Name)_aciertos"
            if ($ResultadoFinal.Contains($Clave)) {
                $ResultadoFinal[$Clave] = @($Grupo.Group | Select-Object agencia, jugada)
            }
        }

        # Generación del JSON con el salto de línea para los corchetes
        $JsonFinal = $ResultadoFinal | ConvertTo-Json -Depth 5
        $JsonFinal
    }
}











