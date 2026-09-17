#!/bin/bash

# recibe Matriz, Filas, Columnas.
function mostrarMatriz() {
	declare -n ref_matriz=$1 # Referencia que apunta hacia la matriz
	local filas=$2
	local columnas=$3

	for ((i = 0; i < $filas; i++)) do

		for ((j = 0; j < $columnas; j++)) do
			printf "%s" "${ref_matriz[$i,$j]}"
			if ((j != $columnas - 1)); then
				echo -n "$separador"
			fi
		done
		echo "" # \n
	done
}

function mostrarAyuda() {
	echo "Uso: bash ejercicio2.sh [OPCIONES]... "
	echo "Traspone o multiplica por un escalar una Matriz, y la guarda en un archivo."
	echo ""
	echo "  -m, --matriz    [PATH]       Indica la ruta exacta al archivo de texto con la matriz"
	echo "  -s, --separador [SEPARADOR]  Establece el separador para parsear la matriz"
	echo "  -p, --producto  [ESCALAR]    Establece el escalar por el que se multiplicará la matriz. No se puede usar con --trasponer."
	echo "  -t, --trasponer              Traspone la matriz. No se puede usar con --producto."
	echo "  -h, --help                   Muestra este mensaje de ayuda"
	echo ""
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		-m|--matriz)
			matriz_path=$2
			shift 2
			;;
		-s|--separador)
			separador=$2
			shift 2
			;;
		-p|--producto)
			escalar=$2
			shift 2
			;;
		-t|--trasponer)
			trasponer=true
			shift 1
			;;
		-h|--help)
			mostrarAyuda
			exit
			;;
		*)
			echo "Parámetro desconocido: $1"
			shift 1
			;;
	esac
done

#### VALIDACIONES!
if [ -z "${matriz_path+x}" ]; then
	echo "Se requiere el parámetro -m o --matriz"
	exit 1
fi

# --separador correcto requerido
if [ -z "${separador+x}" ]; then
	echo "Se requiere el parámetro -s o --separador"
	exit 1
elif [[ "${separador}" =~ [0-9.-] ]]; then 
	echo "El separador no puede contener numeros, puntos, o guiones."
	exit 1
fi

# --producto o --trasponer requerido
if [ -z "${escalar+x}" ] && [ -z "${trasponer+x}" ]; then
	echo "Se requiere el parámetro producto O trasponer (uno de los dos)"
	exit 1
fi

# -- No usar -p y -t al mismo tiempo
if [ -n "${escalar+x}" ] && [ -n "${trasponer+x}" ]; then
	echo "No se puede usar --producto junto con --trasponer"
	exit 1
fi

if [ ! -f "${matriz_path}" ]; then 
	echo "El archivo ${matriz_path} no existe."
	exit 1
fi

data=$(cat "${matriz_path}")

if [ -z "${data}" ]; then
	echo "El archivo está vacío."
	exit 1
fi

mapfile -t lineas < "$matriz_path" # Carga cada linea en un vector lineas

declare -A matriz

declare -i elemsXFila

fila=0
for linea in ${lineas[@]}; do
	columna=0

	IFS="$separador" read -r -a elementos <<< "$linea"

	if (($fila == 0)); then
		elemsXFila=${#elementos[@]}
	elif (($elemsXFila != ${#elementos[@]})); then
		echo "ERROR: LA MATRIZ NO TIENE LA MISMA CANTIDAD DE COLUMNAS EN CADA FILA."
		exit 1
	fi

	for n in ${elementos[@]}; do

		# Validación con regex, solo se permiten numeros, guiones y puntos.
		if ! [[ "$n" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then 
			echo "ERROR: La matriz contiene elementos que NO son números."
			exit 1
		fi

		matriz[$fila,$columna]=$n
		((columna++))
	done

	((fila++))

done

echo "Matriz Ingresada: "
mostrarMatriz matriz $fila $elemsXFila

echo ""

directorio=$(dirname "${matriz_path}")
archivo_original=$(basename "${matriz_path}")

nuevaRuta="${directorio}/salida.${archivo_original}"

if [ ! -z "${escalar+x}" ]; then
	echo "Matriz multiplicada por el escalar ${escalar}:"

	for ((i = 0; i < fila; i++)) do

		for ((j = 0; j < elemsXFila; j++)) do
			resultado=$(echo "${matriz[$i,$j]} * $escalar" | bc)
			matriz[$i,$j]=$resultado
		done
	done


	mostrarMatriz matriz $fila $elemsXFila | tee "${nuevaRuta}"
else 

	echo "Matriz traspuesta:"

	declare -A matrizT
	columnas=$fila
	filas=$elemsXFila

	for ((i=0; i < filas; i++)) do

		for ((j = 0; j < columnas; j++)) do

			matrizT[$i,$j]=${matriz[$j,$i]}
		done

	done

	mostrarMatriz matrizT $filas $columnas | tee "${nuevaRuta}"

fi

echo "Resultado guardado en ${nuevaRuta}"
