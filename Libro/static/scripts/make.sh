ROOT=$(dirname $(readlink -f $0))/../..
SCR="./static/scripts/make.sh"
DEF="./static/defaults/default"
MDS="./*.md"
OUT="./pub"
FOR=false
OFF=false
COL=60

print_help() {
  echo "
make.sh: utilidad de procesamiento.

Uso:
  $SCR [OPCIONES]

Opciones:
  -o | --output     Indica nombre de las salidas SIN extensión; por defecto '$OUT'.
  -f | --format     Embellece los archivos Markdown; por defecto '$FOR'.
  -c | --columns    Indica caracteres por línea del embellecimiento; por defecto '$COL'.
  -n | --no-output  Evita producción de las salidas; por defecto '$OFF'.
  -h | --help       Muestra esta ayuda.

Ejemplos:
  $SCR
    => Produce $OUT.html, $OUT.epub y $OUT.sla
  $SCR --output salida
    => Produce salida.html, salida.epub y salida.sla
  $SCR --output salida --format
    => Produce salida.html, salida.epub y salida.sla, y embellece los Markdown
  $SCR --output salida --format --columns 100
    => Produce salida.html, salida.epub y salida.sla, y embellece los Markdown con líneas de 100 caracteres
  $SCR --no-output --format --columns 100
    => No produce salidas, solo embellece los Markdown con líneas de 100 caracteres
  $SCR -n -f -c 100
    => Versión corta del ejemplo anterior
  "
}

invalid_opt() {
  echo "[ERROR] Invalid option, printing help"
  print_help
}

format() {
  for md in $MDS; do
    echo "[INFO] Formating $md"
    pandoc $md --reference-links --columns=$COL -o $md
  done
}

backup() {
  backup_file () {
    for FILE in $1*; do
      NUM=$((${FILE: -1}+1))
    done
    echo "[WARNING] Backing $1 to $1.$NUM"
    mv $1 $1.$NUM
  }

  if test -f "$OUT.$1"; then
    backup_file $OUT.$1
  fi
}

convert() {
  echo "[INFO] Exporting $OUT.$1"
  # For reproducible builds; cfr: https://pandoc.org/MANUAL.html#reproducible-builds
  SOURCE_DATE_EPOCH=0 pandoc --defaults $DEF.$1  -o $OUT.$1  *.md
}

cd $ROOT

for arg in "$@"; do
  shift
  case "$arg" in
    '--help')      set -- "$@" '-h'   ;;
    '--output')    set -- "$@" '-o'   ;;
    '--format')    set -- "$@" '-f'   ;;
    '--columns')   set -- "$@" '-c'   ;;
    '--no-output') set -- "$@" '-n'   ;;
    *)             set -- "$@" "$arg" ;;
  esac
done

while getopts ":o:c:fnh" opt; do
  case $opt in
    'h') print_help; exit 0 ;;
    'o') OUT=$OPTARG ;;
    'f') FOR=true ;;
    'c') COL=$OPTARG ;;
    'n') OFF=true; FOR=true ;;
    '?') invalid_opt; exit 1 ;;
  esac
done

if [ "$FOR" = true ]; then
  format
fi

if [ "$OFF" = false ]; then
  convert html
  convert epub
fi
