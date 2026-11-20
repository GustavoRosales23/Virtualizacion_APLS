<#
.SYNOPSIS
    Consulta datos de personajes y peliculas de Star Wars desde SWAPI.
.DESCRIPTION
    Realiza consultas a la API de SWAPI para obtener informacion detallada
    de personajes y peliculas segun los IDs numericos ingresados.
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
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [int[]] $people,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [int[]] $film
)

#Hacemos uso de variable global para cachear los datos(en diccionario)
if(-not $Global:RespuestaCache){
    $Global:RespuestaCache=@{}
}

Write-Host "Personajes`n"
    
foreach ($personaje in $people){

    $url="https://www.swapi.tech/api/people/$personaje"

    if(-not $Global:RespuestaCache.ContainsKey($url)){
        $Global:RespuestaCache[$url]=Invoke-RestMethod -Uri $url -Method Get
    }

    $respuesta = $Global:RespuestaCache[$url]
    
    Write-Host "ID:$personaje"
    $respuesta.result.properties.psobject.properties | ForEach-Object { 
        " $($_.Name): $($_.Value)" 
    }
    Write-Host "`n"
}

Write-Host "Peliculas`n"

foreach ($pelicula in $film){
    
    $url="https://www.swapi.tech/api/films/$pelicula"

    if(-not $Global:RespuestaCache.ContainsKey($url)){
        $Global:RespuestaCache[$url]=Invoke-RestMethod -Uri $url -Method Get
    }
    
    $respuesta = $Global:RespuestaCache[$url]
    
    Write-Host "ID:$pelicula"
    
    $respuesta.result.properties.psobject.properties | ForEach-Object { 
        " $($_.Name): $($_.Value)" 
    }
    
    Write-Host "`n"
}