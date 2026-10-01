#!/bin/bash
# Conforti, Lista, Rosales, Porras - Grupo 6


error() {
    echo "Error: $1" >&2
    echo "Utilice '$0 --help' para obtener ayuda." >&2
    exit 1
}


mostrar_ayuda() {
    echo "Uso: $0 [-p ids] [-f ids]"
    echo "  -p, --people   IDs de personajes separados por coma"
    echo "  -f, --film     IDs de peliculas separados por coma"
    echo "  -h, --help     Muestra esta ayuda"
    echo
    echo "Ejemplo: $0 -p \"1,2\" -f \"1,2\""
}


# Parametros recibidos
people=""
films=""

while [[ $# -gt 0 ]]; do

    case "$1" in

        -p|--people)
            if [[ -z "$2" ]]; then
                error "Falta indicar los IDs de personajes."
            fi

            people="$2"
            shift 2
            ;;

        -f|--film)
            if [[ -z "$2" ]]; then
                error "Falta indicar los IDs de peliculas."
            fi

            films="$2"
            shift 2
            ;;

        -h|--help)
            mostrar_ayuda
            exit 0
            ;;

        *)
            error "Parametro desconocido: $1"
            ;;

    esac

done


# Debe ingresarse por lo menos uno de los dos parametros
if [[ -z "$people" && -z "$films" ]]; then
    error "Debe indicar -p/--people o -f/--film."
fi


# Verificar que esten instalados los programas necesarios
if ! command -v curl >/dev/null; then
    error "curl no esta instalado."
fi

if ! command -v jq >/dev/null; then
    error "jq no esta instalado. Puede instalarlo con: sudo apt install jq"
fi


# Directorio utilizado para guardar la cache
CACHE="$(dirname "$0")/cache"

if ! mkdir -p "$CACHE"; then
    error "No se pudo crear el directorio de cache."
fi


# Esta variable guarda el archivo obtenido por la funcion consultar
archivo_consultado=""


consultar() {
    tipo="$1"
    id="$2"

    archivo_cache="$CACHE/${tipo}_${id}.json"
    url="https://www.swapi.tech/api/$tipo/$id"


    # El ID debe contener solamente numeros
    if [[ ! "$id" =~ ^[0-9]+$ ]]; then
        error "ID invalido: $id"
    fi


    # Si el archivo no esta en cache, se consulta la API
    if [[ ! -f "$archivo_cache" ]]; then

        if ! respuesta_api=$(curl -sSf "$url"); then
            error "No se pudo obtener $tipo con ID $id."
        fi


        # Verificar que la respuesta tenga la informacion esperada
        if ! echo "$respuesta_api" | jq -e '.result.properties' >/dev/null 2>&1; then
            error "La respuesta recibida para $tipo con ID $id no es valida."
        fi


        # Guardar la respuesta para no volver a consultar la API
        if ! echo "$respuesta_api" > "$archivo_cache"; then
            error "No se pudo guardar la informacion en cache."
        fi

    fi


    archivo_consultado="$archivo_cache"
}


mostrar_personaje() {
    archivo="$1"
    id="$2"

    echo "Id: $id"
    echo "Nombre: $(jq -r '.result.properties.name' "$archivo")"
    echo "Genero: $(jq -r '.result.properties.gender' "$archivo")"
    echo "Altura: $(jq -r '.result.properties.height' "$archivo")"
    echo "Masa: $(jq -r '.result.properties.mass' "$archivo")"
    echo "Año de nacimiento: $(jq -r '.result.properties.birth_year' "$archivo")"
    echo
}


mostrar_pelicula() {
    archivo="$1"

    echo "Titulo: $(jq -r '.result.properties.title' "$archivo")"
    echo "ID Episodio: $(jq -r '.result.properties.episode_id' "$archivo")"
    echo "Fecha de publicacion: $(jq -r '.result.properties.release_date' "$archivo")"
    echo "Apertura: $(jq -r '.result.properties.opening_crawl' "$archivo")"
    echo
}


# Procesar personajes
if [[ -n "$people" ]]; then

    echo "Personajes:"

    IFS=',' read -ra ids <<< "$people"

    for id in "${ids[@]}"; do
        consultar "people" "$id"
        mostrar_personaje "$archivo_consultado" "$id"
    done

fi


# Procesar peliculas
if [[ -n "$films" ]]; then

    echo "Peliculas:"

    IFS=',' read -ra ids <<< "$films"

    for id in "${ids[@]}"; do
        consultar "films" "$id"
        mostrar_pelicula "$archivo_consultado"
    done

fi
