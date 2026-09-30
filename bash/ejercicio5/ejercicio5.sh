#!/bin/bash
# Conforti, Lista, Rosales, Porras - Grupo 6

mostrar_ayuda() {
    echo "Uso: $0 [-p ids] [-f ids]"
    echo "  -p, --people   IDs de personajes separados por coma"
    echo "  -f, --film     IDs de peliculas separados por coma"
    echo "  -h, --help     Muestra esta ayuda"
    echo
    echo "Ejemplo: $0 -p \"1,2\" -f \"1,2\""
}

# Parametros
people=""
films=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--people)
            [[ -n "$2" ]] || { echo "Error: falta indicar los IDs de personajes"; exit 1; }
            people="$2"
            shift 2
            ;;
        -f|--film)
            [[ -n "$2" ]] || { echo "Error: falta indicar los IDs de peliculas"; exit 1; }
            films="$2"
            shift 2
            ;;
        -h|--help)
            mostrar_ayuda
            exit 0
            ;;
        *)
            echo "Error: parametro desconocido: $1"
            mostrar_ayuda
            exit 1
            ;;
    esac
done

if [[ -z "$people" && -z "$films" ]]; then
    echo "Error: debe indicar -p/--people o -f/--film"
    exit 1
fi

command -v curl >/dev/null || { echo "Error: curl no esta instalado"; exit 1; }
command -v jq >/dev/null || { echo "Error: jq no esta instalado. Utilice sudo apt install jq"; exit 1; }

CACHE="$(dirname "$0")/cache"
mkdir -p "$CACHE" || { echo "Error: no se pudo crear la cache"; exit 1; }

consultar() {
    tipo="$1"
    id="$2"
    archivo="$CACHE/${tipo}_${id}.json"
    url="https://www.swapi.tech/api/$tipo/$id"

    if [[ ! "$id" =~ ^[0-9]+$ ]]; then
        echo "Error: ID invalido: $id" >&2
        return 1
    fi

    # Si ya esta en cache, no consulta la API.
    if [[ ! -f "$archivo" ]]; then
        respuesta=$(curl -sSf "$url") || {
            echo "Error: no se pudo obtener $tipo con ID $id" >&2
            return 1
        }

        echo "$respuesta" | jq -e '.result.properties' >/dev/null 2>&1 || {
            echo "Error: respuesta invalida para $tipo con ID $id" >&2
            return 1
        }

        echo "$respuesta" > "$archivo" || {
            echo "Error: no se pudo guardar la cache" >&2
            return 1
        }
    fi

    echo "$archivo"
}

mostrar_personaje() {
    archivo="$1"
    id="$2"

    echo "Id: $id"
    echo "Name: $(jq -r '.result.properties.name' "$archivo")"
    echo "Gender: $(jq -r '.result.properties.gender' "$archivo")"
    echo "Height: $(jq -r '.result.properties.height' "$archivo")"
    echo "Mass: $(jq -r '.result.properties.mass' "$archivo")"
    echo "Birth Year: $(jq -r '.result.properties.birth_year' "$archivo")"
    echo
}

mostrar_pelicula() {
    archivo="$1"

    echo "Title: $(jq -r '.result.properties.title' "$archivo")"
    echo "Episode id: $(jq -r '.result.properties.episode_id' "$archivo")"
    echo "Release date: $(jq -r '.result.properties.release_date' "$archivo")"
    echo "Opening crawl: $(jq -r '.result.properties.opening_crawl' "$archivo")"
    echo
}

if [[ -n "$people" ]]; then
    echo "Personajes:"
    IFS=',' read -ra ids <<< "$people"

    for id in "${ids[@]}"; do
        archivo=$(consultar "people" "$id") && mostrar_personaje "$archivo" "$id"
    done
fi

if [[ -n "$films" ]]; then
    echo "Peliculas:"
    IFS=',' read -ra ids <<< "$films"

    for id in "${ids[@]}"; do
        archivo=$(consultar "films" "$id") && mostrar_pelicula "$archivo"
    done
fi
