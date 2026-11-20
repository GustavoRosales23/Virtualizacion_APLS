<#
.SYNOPSIS
    Consulta datos de personajes y peliculas de Star Wars desde SWAPI.
.DESCRIPTION
    Realiza consultas a la API de SWAPI para obtener informacion detallada
    de personajes y peliculas segun los IDs numericos ingresados. Puede
    especificarse solo buscar por personajes o solo por películas,
    pero debe buscarse por alguno de los dos o ambos.
.PARAMETER people
    Arreglo de IDs numericos para consultar personajes (ej: 1, 2, 3).
.PARAMETER film
    Arreglo de IDs numericos para consultar peliculas (ej: 1, 2, 3).
.EXAMPLE
    ./ejercicio5.ps1 -people 1, 2 -film 1.
    Consulta los personajes con ID 1 y 2, y la pelicula con ID 1.
#>

<#Grupo 6. Integrantes:
 -Conforti, Luis Alberto
 -Lista, Matias Josue
 -Porras, Federico Emanuele
 -Rosales, Gustavo Mauricio
#>

Param(
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int[]] $people,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int[]] $film
)

if ($people.Count -eq 0 -and $film.Count -eq 0) {
    Write-Error "Debe especificar al menos uno de los parámetros: -people o -film"
    exit 1
}

# Hacemos uso de variable global para cachear los datos (en diccionario).
if(-not $Global:RespuestaCache){
    $Global:RespuestaCache=@{}
}

function ConsultarAPI($url, $id) {

    if (-not $Global:RespuestaCache.ContainsKey($url)) {

        try {
            $Global:RespuestaCache[$url] = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
        }
        catch {
            $statusCode = [int]$_.Exception.Response.StatusCode

            if ($statusCode -eq 404) {
                Write-Host "El ID $id es inexistente."
            }
            elseif ($statusCode -ge 400 -and $statusCode -lt 600) {
                Write-Host "Error en la solicitud. Código HTTP: $statusCode."
            }
            else {
                Write-Host "Error en la solicitud: $($_.Exception.Message)."
            }

            return $false
        }
    }

    return $true
}

function MostrarRespuesta($id) {
    $respuesta = $Global:RespuestaCache[$url]
        
    Write-Host "ID: $id"
    $respuesta.result.properties.psobject.properties | ForEach-Object { 
        " $($_.Name): $($_.Value)" 
    }
    Write-Host "`n"
}

if ($people.Count) {
    Write-Host "Personajes:`n"
    
    foreach ($personaje in $people){

        $url="https://www.swapi.tech/api/people/$personaje"

        if (ConsultarAPI $url $personaje) {
            MostrarRespuesta $personaje
        }
    }
}

if ($film.Count) {
    Write-Host "`nPeliculas:`n"

    foreach ($pelicula in $film){
        
        $url="https://www.swapi.tech/api/films/$pelicula"

        if (ConsultarAPI $url $pelicula) {
            MostrarRespuesta $pelicula
        }
    }
}