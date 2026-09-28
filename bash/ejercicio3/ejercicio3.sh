#!/bin/bash
# Conforti, Lista, Rosales, Porras - Grupo 6

# -------------------------------------------------------------------
# Funciones de ayuda y error
# -------------------------------------------------------------------

mostrar_ayuda() {
    echo "Uso: $0 -d <directorio>"
    echo
    echo "Parámetros:"
    echo "  -d, --directorio <ruta>  Directorio a analizar"
    echo "  -h, --help               Mostrar esta ayuda"
}

error() {
    echo "Error: $1" >&2
    echo "Utilice '$0 --help' para obtener ayuda." >&2
    exit 1
}

# -------------------------------------------------------------------
# Procesamiento de parámetros
# -------------------------------------------------------------------

directorio=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            mostrar_ayuda
            exit 0
            ;;

        -d|--directorio)
            if [ "$#" -lt 2 ]; then
                error "Debe indicar un directorio después de '$1'."
            fi

            directorio="$2"
            shift 2
            ;;

        *)
            error "Parámetro desconocido: '$1'."
            ;;
    esac
done

# Validar que el parámetro obligatorio haya sido proporcionado
if [ -z "$directorio" ]; then
    error "Debe indicar el directorio que desea analizar."
fi

# Validar que exista y sea un directorio
if [ ! -d "$directorio" ]; then
    error "El directorio '$directorio' no existe o no es un directorio."
fi


# -------------------------------------------------------------------
# Búsqueda de duplicados
# -------------------------------------------------------------------

# 1. Obtener los archivos recursivamente y procesarlos con AWK
ls -lR --quoting-style=literal "$directorio" | awk '
    # 2. Detectar el comienzo de un directorio
    /:$/ {
        directorio = substr($0, 1, length($0) - 1)
        next
    }

    # 3. Ignorar todo lo que no sea un archivo regular
    $1 !~ /^-/ {
        next
    }

    {
        # 4. Obtener tamaño y nombre
        tamano = $5
        nombre = $9

        # Maneja la existencia de espacios en un nombre
        for (i = 10; i <= NF; i++)
            nombre = nombre " " $i

        # 4.1 Construir una clave nombre + tamano
        clave = nombre SUBSEP tamano

        # 4.2 Contar cuántas veces aparece
        cantidad[clave]++

        # 4.3 Guardar el directorio donde apareció
        paths[clave] = paths[clave] directorio "\n"
    }

    END {
        # 5. Recorrer todas las claves
        for (clave in cantidad) {

            # 5.1 Solo nos interesan las que aparecen más de una vez
            if (cantidad[clave] > 1) {

                # 5.2 Recuperar nombre y tamano
                split(clave, tupla, SUBSEP)
                nombre = tupla[1]
                print nombre

                # 5.3 Mostrar los paths
                print paths[clave]
            }
        }
    }
'
