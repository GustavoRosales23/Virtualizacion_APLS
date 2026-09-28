#!/bin/bash
# Conforti, Lista, Rosales, Porras - Grupo 6

# -------------------------------------------------------------------
# Funciones de ayuda y error
# -------------------------------------------------------------------

mostrar_ayuda() {
    echo "Monitorea un directorio y sus subdirectorios detectando la creación / movimiento de archivos duplicados."
    echo "Si encuentra algún duplicado, lo registra en un log, lo comprime y resguarda en un comprimido para luego eliminarlo."
    echo
    echo "Uso:"
    echo "  $0 -d <directorio> -s <salida>  Iniciar monitoreo"
    echo "  $0 -d <directorio> -k           Finalizar monitoreo"
    echo
    echo "Parámetros:"
    echo "  -d, --directorio <ruta>  Directorio a monitorear"
    echo "  -s, --salida <ruta>      Directorio para guardar backups"
    echo "  -k, --kill               Señal de finalización (requiere el directorio monitoreado)"
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
salida=""
kill=false

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

        -s|--salida)
            if [ "$#" -lt 2 ]; then
                error "Debe indicar un directorio de salida después de '$1'."
            fi

            salida="$2"
            shift 2
            ;;

        -k|--kill)
            kill=true
            shift
            ;;

        *)
            error "Parámetro desconocido: '$1'."
            ;;
    esac
done

if [[ "$kill" == true && -z "$directorio" ]]; then
    error "La opción '-k / --kill' requiere indicar un directorio con '-d / --directorio'."
fi

# Validar que el parámetro obligatorio haya sido proporcionado
if [ -z "$directorio" ]; then
    error "Debe indicar el directorio que desea monitorear."
fi

# Validar que exista y sea un directorio
if [ ! -d "$directorio" ]; then
    error "El directorio '$directorio' no existe o no es un directorio."
fi

# Archivo donde guardamos el PGID del monitoreo, con el directorio hasheado en su nombre para identificarlo univocamente.
# Se utiliza el PGID para poder matar a todos los procesos involucrados juntos.
pgidfile="/tmp/monitoreo_$(echo "$directorio" | md5sum | cut -d' ' -f1).pgid"


# ---------------------------------------------------------
# Finalizar daemon
# ---------------------------------------------------------

if [[ "$kill" == true ]]; then

    if [[ ! -f "$pgidfile" ]]; then
        echo "No hay un monitoreo ejecutándose sobre este directorio." >&2
        exit 1
    fi

    pgid=$(cat "$pgidfile")

    kill -- -"$pgid"
    echo "Monitoreo finalizado. PGID: $pgid"

    rm -f "$pgidfile"
    exit 0
fi


# ---------------------------------------------------------
# Incialización del daemon
# ---------------------------------------------------------

# Comprobación de existencia
if [[ -f "$pgidfile" ]]; then

    pgid=$(cat "$pgidfile")

    if kill -0 -- -"$pgid" 2>/dev/null; then
        echo "Ya existe un monitoreo ejecutándose sobre este directorio." >&2
        exit 1
    fi

    rm -f "$pgidfile"
fi

# Validar que se haya indicado una salida.
if [ -z "$salida" ]; then
    error "Debe indicar el directorio para guardar los backups."
fi

# Crear directorio de salida si no existe.
salida=$(realpath -m "$salida")
mkdir -p "$salida"


# -------------------------------------------------------------------
# Monitoreo
# -------------------------------------------------------------------

monitoreo() {

    # Creación de archivo de log.
    log="$salida/monitoreo.log"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Demonio iniciado sobre $directorio" >> "$log"

    # Inicio de monitoreo
    # Aclaración: Acá se crean dos procesos hijos, uno para inotifywait y otro para el procesamiento del pipe.
    # Por esta razón, se mata todo el process group directamente.
    inotifywait -m -r \
        -e close_write -e moved_to \
        --format '%w%f' \
        "$directorio" |
    while IFS= read -r archivo; do
    
        nombre=$(basename "$archivo")
        tamano=$(stat -c '%s' "$archivo")

        # Busqueda de duplicados dentro del directorio.
        duplicados=$(find "$directorio" \
            -type f \
            -name "$nombre" \
            -size "${tamano}c" \
            ! -path "$archivo"
        )

        if [[ -z "$duplicados" ]]; then
            continue
        fi

        timestamp=$(date '+%Y%m%d-%H%M%S')
        backup=$salida/$timestamp.tar.gz

        echo "$(date '+%Y-%m-%d %H:%M:%S') - Duplicado detectado: $archivo" >> "$log"

        # Crear backup con el archivo nuevo.
        tar -czf "$backup" "$archivo"

        # Solo eliminar si tar terminó correctamente.
        if [[ $? -eq 0 ]]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Backup creado: $backup" >> "$log"
            rm "$archivo"

            echo "$(date '+%Y-%m-%d %H:%M:%S') - Archivo eliminado: $archivo" >> "$log"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR creando backup" >> "$log"
        fi
    done
}

# -------------------------------------------------------------------
# Iniciar daemon
# -------------------------------------------------------------------

# Se inicia como daemon y se desacoplan las entradas y salidas.
(monitoreo) </dev/null >/dev/null 2>&1 &

pid=$!
pgid=$(ps -o pgid= "$pid" | tr -d ' ')

echo "$pgid" > "$pgidfile"
echo "Monitoreo iniciado. PGID: $pgid"