function Consultar_API_StarWars {
    <#
    .SYNOPSIS
      Script que consulta datos a la API de StarWars.
    .DESCRIPTION
      Esta función realiza consultas a la API de SWAPI para obtener información sobre personajes y películas según los IDs ingresados.
    .PARAMETER people
      Arreglo de IDs numéricos para consultar personajes.
    .PARAMETER film
      Arreglo de IDs numéricos para consultar películas.
    .EXAMPLE
      Consultar_API_StarWars -people 1, 2 -film 1
    #>
    
    Param(
    [Parameter(Mandatory=$true)]
    [int[]] $people,

    [Parameter(Mandatory=$true)]
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
          $Global:RespuestaCache[$url]=Invoke-RestMethod -Uri $url  -Method Get

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
      
      $url="https://www.swapi.tech/api/people/$pelicula"

      if(-not $Global:RespuestaCache.ContainsKey($url)){
          $Global:RespuestaCache[$url]=Invoke-RestMethod -Uri $url  -Method Get

      }
      
      $respuesta = $Global:RespuestaCache[$url]
      
      Write-Host "ID:$pelicula"
      
      $respuesta.result.properties.psobject.properties | ForEach-Object { 
          " $($_.Name): $($_.Value)" 
      }
      Write-Host "`n"
    }

}