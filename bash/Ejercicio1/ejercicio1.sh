#!/bin/bash
# --- Colores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Variables ---
DIRECTORIO=""
ARCHIVO_SALIDA=""
MOSTRAR_PANTALLA=0
NOMBRE_ARCHIVO_GANADORES="Ganadores.csv"

# ============================================================
# Función de uso
# ============================================================
uso() {
    cat <<EOF
Uso: $0 -d <directorio> (-a <archivo.json> | -p)

Parámetros:
  -d, --directorio <ruta>   Directorio con los archivos CSV de las agencias (obligatorio)
  -a, --archivo <ruta>      Ruta completa del archivo JSON de salida
                            (mutuamente excluyente con -p)
  -p, --pantalla            Muestra el resultado JSON por pantalla
                            (mutuamente excluyente con -a)
  -h, --help                Muestra esta ayuda

Ejemplo:
  $0 -d ./agencias -p
  $0 -d ./agencias -a ./resultado.json
EOF
    exit 1
}

# ============================================================
# 1. Parseo y validación de parámetros
# ============================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--directorio)
            [[ -z "$2" || "$2" =~ ^- ]] && { echo -e "${RED}Error:${NC} -d requiere un valor"; uso; }
            DIRECTORIO="$2"
            shift 2
            ;;
        -a|--archivo)
            [[ -z "$2" || "$2" =~ ^- ]] && { echo -e "${RED}Error:${NC} -a requiere un valor"; uso; }
            ARCHIVO_SALIDA="$2"
            shift 2
            ;;
        -p|--pantalla)
            MOSTRAR_PANTALLA=1
            shift
            ;;
        -h|--help)
            uso
            ;;
        *)
            echo -e "${RED}Error:${NC} Parámetro desconocido: $1"
            uso
            ;;
    esac
done

# --- Validar obligatorio: -d ---
if [[ -z "$DIRECTORIO" ]]; then
    echo -e "${RED}Error:${NC} El parámetro -d/--directorio es obligatorio."
    uso
fi

# --- Validar exclusividad -a / -p ---
if [[ -n "$ARCHIVO_SALIDA" && "$MOSTRAR_PANTALLA" -eq 1 ]]; then
    echo -e "${RED}Error:${NC} No se pueden usar -a y -p al mismo tiempo."
    uso
fi

if [[ -z "$ARCHIVO_SALIDA" && "$MOSTRAR_PANTALLA" -eq 0 ]]; then
    echo -e "${RED}Error:${NC} Debe indicar -a/--archivo o -p/--pantalla."
    uso
fi

# --- Validar directorio ---
if [[ ! -d "$DIRECTORIO" ]]; then
    echo -e "${RED}Error:${NC} '$DIRECTORIO' no es un directorio válido."
    exit 1
fi

find "$DIRECTORIO" -maxdepth 1 -name "*.csv" -exec sed -i 's/\r$//' {} \;

# --- Validar existencia del archivo de ganadores ---
ARCHIVO_GANADORES="$DIRECTORIO/$NOMBRE_ARCHIVO_GANADORES"
if [[ ! -f "$ARCHIVO_GANADORES" ]]; then
    echo -e "${RED}Error:${NC} No se encontró el archivo de ganadores: $ARCHIVO_GANADORES"
    exit 1
fi

# --- Validar que el directorio de salida exista (si se usa -a) ---
if [[ -n "$ARCHIVO_SALIDA" ]]; then
    DIR_SALIDA=$(dirname "$ARCHIVO_SALIDA")
    if [[ ! -d "$DIR_SALIDA" ]]; then
        echo -e "${RED}Error:${NC} El directorio de salida '$DIR_SALIDA' no existe."
        exit 1
    fi
fi

# ============================================================
# 2. Leer números ganadores
# ============================================================
IFS=',' read -r -a GANADORES < "$ARCHIVO_GANADORES"

if [[ ${#GANADORES[@]} -ne 5 ]]; then
    echo -e "${RED}Error:${NC} El archivo de ganadores debe tener exactamente 5 números."
    exit 1
fi

echo -e "${GREEN}Números ganadores:${NC} ${GANADORES[*]}" >&2

# ============================================================
# 3. Función: contar aciertos entre dos arrays de 5 números
# ============================================================
contar_aciertos() {
    local -a jugada=("$@")
    local aciertos=0
    local i j
    for ((i=0; i<5; i++)); do
        for ((j=0; j<5; j++)); do
            if [[ "${jugada[$i]}" -eq "${GANADORES[$j]}" ]]; then
                ((aciertos++))
                break
            fi
        done
    done
    echo "$aciertos"
}

# ============================================================
# 4. Procesar archivos (excluyendo el de ganadores)
# ============================================================
declare -a GANADORES_5=()
declare -a GANADORES_4=()
declare -a GANADORES_3=()

shopt -s nullglob
for archivo in "$DIRECTORIO"/*.csv; do
    # Saltar el archivo de ganadores
    [[ "$(basename "$archivo")" == "$NOMBRE_ARCHIVO_GANADORES" ]] && continue

    agencia=$(basename "$archivo" .csv)

    while IFS= read -r linea || [[ -n "$linea" ]]; do
        # Ignorar líneas vacías
        [[ -z "$linea" ]] && continue

        # Separar id y números
        IFS=',' read -r -a campos <<< "$linea"

        # Validar formato: 6 campos (id + 5 números)
        if [[ ${#campos[@]} -ne 6 ]]; then
            echo -e "${YELLOW}Advertencia:${NC} Línea inválida en $archivo: '$linea'" >&2
            continue
        fi

        id="${campos[0]}"
        # Extraer los 5 números (índices 1..5)
        jugada=("${campos[@]:1:5}")

        # Calcular aciertos
        aciertos=$(contar_aciertos "${jugada[@]}")

        case "$aciertos" in
            5) GANADORES_5+=("$agencia|$id") ;;
            4) GANADORES_4+=("$agencia|$id") ;;
            3) GANADORES_3+=("$agencia|$id") ;;
        esac
    done < "$archivo"
done

# ============================================================
# 5. Generar JSON
# ============================================================
generar_json() {
    echo "{"

    # ---------- 5 aciertos ----------
    echo '   "5_aciertos": ['
    local primero=1
    for item in "${GANADORES_5[@]}"; do
        [[ -z "$item" ]] && continue
        local agencia="${item%%|*}"
        local jugada="${item##*|}"
        [[ $primero -eq 0 ]] && echo "      },"
        [[ $primero -eq 1 ]] || echo "      {"
        [[ $primero -eq 1 ]] && echo "      {"
        echo "         \"agencia\": \"$agencia\","
        echo "         \"jugada\": \"$jugada\""
        primero=0
    done
    if [[ $primero -eq 0 ]]; then
        echo "      }"
    fi
    echo "   ],"

    # ---------- 4 aciertos ----------
    echo '   "4_aciertos": ['
    primero=1
    for item in "${GANADORES_4[@]}"; do
        [[ -z "$item" ]] && continue
        local agencia="${item%%|*}"
        local jugada="${item##*|}"
        if [[ $primero -eq 0 ]]; then
            echo "      },"
        fi
        echo "      {"
        echo "         \"agencia\": \"$agencia\","
        echo "         \"jugada\": \"$jugada\""
        primero=0
    done
    if [[ $primero -eq 0 ]]; then
        echo "      }"
    fi
    echo "   ],"

    # ---------- 3 aciertos ----------
    echo '   "3_aciertos": ['
    primero=1
    for item in "${GANADORES_3[@]}"; do
        [[ -z "$item" ]] && continue
        local agencia="${item%%|*}"
        local jugada="${item##*|}"
        if [[ $primero -eq 0 ]]; then
            echo "      },"
        fi
        echo "      {"
        echo "         \"agencia\": \"$agencia\","
        echo "         \"jugada\": \"$jugada\""
        primero=0
    done
    if [[ $primero -eq 0 ]]; then
        echo "      }"
    fi
    echo "   ]"

    echo "}"
}

# ============================================================
# 6. Salida: pantalla o archivo
# ============================================================
if [[ "$MOSTRAR_PANTALLA" -eq 1 ]]; then
    generar_json
else
    generar_json > "$ARCHIVO_SALIDA"
    echo -e "${GREEN} Archivo JSON generado:${NC} $ARCHIVO_SALIDA" >&2
fi

exit 0


























