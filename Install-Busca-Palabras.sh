#!/bin/bash

# Fecha inicio 01/Sep/2021
# actualizado 25/Feb/2024
# Por: @robert_nissan

# Colores
NC='\033[0m'            # Sin color
RED='\033[1;31m'        # Rojo brillante
BLUE='\033[1;34m'       # Azul brillante
CYAN='\033[1;36m'       # Cian brillante
WHITE='\033[1;37m'      # Blanco brillante
GREEN='\033[1;32m'      # Verde brillante
YELLOW='\033[1;33m'     # Amarillo brillante
MAGENTA='\033[1;35m'    # Magenta brillante

echo -e ""$YELLOW"=-=-=-=(PERMISOS DE ALMACENAMIENTO)=-=-=-="
# Verificar si los permisos de almacenamiento ya han sido concedidos
# Ruta de prueba
prueba_ruta="/sdcard/.prueba_permiso_termux.txt"
# Verificar el estado del almacenamiento
verificar_almacenamiento() {
    if [ -d "/sdcard/" ]; then
        # Intentar crear un archivo para verificar los permisos
        echo "Prueba de permisos" > "$prueba_ruta" 2>/dev/null
        if [ -f "$prueba_ruta" ]; then
            echo -e "${GREEN}Los permisos de almacenamiento ya han sido concedidos.${NC}"
            rm "$prueba_ruta"  # Eliminar el archivo de prueba
            return 0
        else
            echo -e "${RED}El directorio existe, pero los permisos de escritura no están disponibles.${NC}"
        fi
    fi

    # Si llegamos aquí, es porque no se tienen los permisos
    echo -e "${YELLOW}Concediendo permisos de almacenamiento...${NC}"
    termux-setup-storage
    sleep 5  # Esperar un momento para permitir que se concedan los permisos

    # Verificar de nuevo los permisos
    if [ -d "/sdcard/" ]; then
        echo "Prueba de permisos" > "$prueba_ruta" 2>/dev/null
        if [ -f "$prueba_ruta" ]; then
            echo -e "${GREEN}Permisos de almacenamiento concedidos correctamente.${NC}"
            rm "$prueba_ruta"  # Eliminar el archivo de prueba
            return 0
        else
            echo -e "${RED}No se pudieron conceder los permisos de almacenamiento. Asegúrate de aceptar la solicitud de permisos.${NC}"
            return 1
        fi
    else
        echo -e "${RED}El directorio de almacenamiento no está disponible. Asegúrate de aceptar la solicitud de permisos.${NC}"
        return 1
    fi
}
# Ejecutar la función
verificar_almacenamiento

echo -e ""$YELLOW"<>=<>=<>=INSTALANDO DEPENDENCIAS=<>=<>=<>${NC}";sleep 2;

# Funcion para vericar la conexión a internet
verif_con_internet() {
    rm -rf "$TEMP_FILE" > /dev/null
    proceso_ip_externa='false'
    TEMP_FILE=$(mktemp) # Archivo temporal para almacenar la salida de curl
    TIMEOUT=5 # Tiempo máximo en segundos para que curl termine
    # Ejecutar curl en segundo plano
    curl -s ipinfo.io/ip > "$TEMP_FILE" &
    CURL_PID=$! # Capturar el PID del proceso curl
    # echo "CURL_PID: $CURL_PID"
    # Esperar a que curl termine con un tiempo límite
    SECONDS=0
    while kill -0 $CURL_PID 2>/dev/null; do
        if [[ $SECONDS -ge $TIMEOUT ]]; then
            echo "false"
            kill -9 $CURL_PID >/dev/null
            rm -rf "$TEMP_FILE"
            x=""
            return 1
        fi
        sleep 0.5
    done
    # Verificar si curl se ejecutó correctamente
    wait $CURL_PID || true  # No abortar si wait devuelve error
    CURL_EXIT_CODE=$?
    # echo "CURL_EXIT_CODE: $CURL_EXIT_CODE"
    # echo "Mostrar contenido de $TEMP_FILE:"
    # cat "$TEMP_FILE"
    if [[ $CURL_EXIT_CODE -ne 0 ]]; then
        echo "Advertencia: curl no terminó correctamente, pero revisando la salida..." >/dev/null
    fi
    x=$(cat "$TEMP_FILE") # Leer la salida del archivo temporal
    no_ip='<html><head><title>302 Found</title></head><body><h1>302 Found</h1><p>The document has moved <a href="https://mi.tigo.com.co/assets/captive.html?utm_source=captiveportal">here</a></p></body></html>'
    if [[ -n "$x" && "$x" != "$no_ip" ]]; then
        echo "true"
        rm -rf "$TEMP_FILE"
        return 0
    else
        echo "false"
        rm -rf "$TEMP_FILE"
        return 1
    fi
}

reanuda='false'
verif_inter() {
    while true; do
        if [[ $(verif_con_internet) == 'true' ]]; then
            [[ "$reanuda" == 'true' ]] && reanuda='false' && echo -ne "\r\033[K${conteo}${YELLOW}instalando ${pkg} > ${MAGENTA} Volvió la conexión a Internet${NC}"
            return
        else
            echo -ne "\r\033[K${conteo}${YELLOW}instalando ${pkg} > ${RED}No hay conexión a Internet${NC}"
            reanuda='true'
        fi
    done
}

paquetes_termux() {
    instalar_paquete_python() {
        python='false'
        python_pip='false'
        # Verificar si Python está instalado
        while ! [[ -x ${PREFIX}/bin/python ]]; do
            echo -e "00 - ${YELLOW}Instalando python${NC}"
            verif_inter
            [[ "$python" == 'false' ]] && apt install python -y && python='true'
            if [ $? -eq 0 ]; then
                echo -e "   > ${GREEN}python instalado${NC}"
                verif_inter
                return
            else
                continue
            fi
            verif_inter
            [[ "$python_pip" == 'false' ]] && pkg install python-pip && python_pip='true'
            if [ $? -eq 0 ]; then
                echo -e "   > ${GREEN}python-pip instalado${NC}"
                verif_inter
                return
            else
                continue
            fi
        done
        echo -e "00 - ${GREEN}Python ya está instalado${NC}."
    }
    instalar_paquete_python
    
    # Función para instalar paquetes de Python si no están presentes
    instalar_paquete_pip() {
        local paquete=$1
        local instalacion=$2
        local mensaje_error=$3

        while ! python -c "import $paquete" &>/dev/null; do
            echo -ne "\r\033[K$4${YELLOW}Instalando $1${NC}"
            verif_inter
            eval "$instalacion" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo -e "\n   > ${GREEN}$1 instalado${NC}"
                return
            elif [ $? -ne 0 ]; then
                echo -e "${RED}$mensaje_error${NC}"
                exit 1
            fi
        done
        echo -e "$4${GREEN}$1 ya está instalado${NC}."
    }

    # Función para instalar paquetes en $PREFIX/share/doc/
    instalar_paquete_share() {
        while [[ ! -d $PREFIX/share/doc/$1 ]]; do
            echo -ne "\r\033[K$3${YELLOW}Instalando $1${NC}"
            verif_inter
            pkg install -y $2 >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo -e "\n   > ${GREEN}$1 instalado${NC}"
                return
            else
                continue
            fi
        done
        echo -e "$3${GREEN}$1 ya está instalado${NC}."
    }

    # Función para instalar paquetes en $PREFIX/libexec/
    instalar_paquete_libexec() {
        while [[ ! -f "$PREFIX/libexec/$1" ]]; do
            echo -ne "\r\033[K$3${YELLOW}Instalando $1${NC}"
            verif_inter
            pkg install -y "$2" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo -e "\n   > ${GREEN}$1 instalado${NC}"
                return
            else
                continue
            fi
        done
        echo -e "$3${GREEN}$1 ya está instalado${NC}."
    }
    
    # Función para instalar paquetes en $PREFIX/bin/
    instalar_paquete_bin_pkg_list() {
        while pkg list-installed 2>/dev/null | grep -q $1; do
            echo -ne "\r\033[K$3${YELLOW}Instalando $1${NC}"
            verif_inter
            pkg install -y $2 >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo -e "\n   > ${GREEN}$1 instalado${NC}"
                return
            else
                continue
            fi
        done
        echo -e "$3${GREEN}$1 ya está instalado${NC}."
    }
    
    # Función para instalar paquetes en $PREFIX/bin/
    instalar_paquete_bin_pkg() {
        while [[ ! -f $PREFIX/bin/$1 ]]; do
            echo -ne "\r\033[K$3${YELLOW}Instalando $1${NC}"
            verif_inter
            pkg install -y $2 >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo -e "\n   > ${GREEN}$1 instalado${NC}"
                return
            else
                continue
            fi
        done
        echo -e "$3${GREEN}$1 ya está instalado${NC}."
    }
    
    # Función para instalar paquetes en $PREFIX/bin/
    instalar_paquete_bin_apt() {
        while [[ ! -f $PREFIX/bin/$1 ]]; do
            echo -ne "\r\033[K$3${YELLOW}Instalando $1${NC}"
            verif_inter
            apt install -y $2 >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo -e "\n   > ${GREEN}$1 instalado${NC}"
                return
            else
                continue
            fi
        done
        echo -e "$3${GREEN}$1 ya está instalado${NC}."
    }
    
    # Función para instalar paquetes en $PREFIX/bin/
    instalar_paquete_bin_apt_get() {
        while [[ ! -f $PREFIX/bin/$1 ]]; do
            echo -ne "\r\033[K$3${YELLOW}Instalando $1${NC}"
            verif_inter
            apt-get install -y $2 >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo -e "\n   > ${GREEN}$1 instalado${NC}"
                return
            else
                continue
            fi
        done
        echo -e "$3${GREEN}$1 ya está instalado${NC}."
    }


    pkgs=("jq" "bc" "pv" "7z" "zip" "rar" "git" "adb" "tsu" "fish" "unrar" "proot" "rsync" "sqlite" "expect" "crunch" "iproute2" "busybox" "termux-api" "proot-distro" "libqrencode" "silversearcher-ag")
    count=0
    for pkg in "${pkgs[@]}"; do
        count=$((count + 1))
        # printf "%d - " "$count"
        conteo=$(printf "%02d - " "$count")
    
        case "$pkg" in
            # Instalar herramientas necesarias
            # instalar_paquete     "nom" "paq" "conteo"
            "jq") instalar_paquete_bin_pkg "jq" "jq" "$conteo" ;;
            "bc") instalar_paquete_bin_pkg "bc" "bc" "$conteo" ;;
            "pv") instalar_paquete_bin_pkg "pv" "pv" "$conteo" ;;
            "7z") instalar_paquete_bin_pkg "7z" "p7zip" "$conteo" ;;
            "zip") instalar_paquete_bin_pkg "zip" "zip" "$conteo" ;;
            "rar") instalar_paquete_bin_pkg "rarp" "rar" "$conteo" ;;
            "zip") instalar_paquete_bin_pkg "git" "git" "$conteo" ;;
            "adb") instalar_paquete_bin_pkg "adb" "android-tools" "$conteo" ;;
            "tsu") instalar_paquete_bin_apt "tsu" "tsu" "$conteo" ;;
            "fish") instalar_paquete_bin_apt "fish" "fish" "$conteo" ;;
            "unrar") instalar_paquete_bin_pkg "unrar" "unrar" "$conteo" ;;
            "proot") instalar_paquete_bin_apt "proot" "proot" "$conteo" ;;
            "rsync") instalar_paquete_bin_apt "rsync" "rsync" "$conteo" ;;
            "sqlite") instalar_paquete_bin_pkg_list "sqlite" "sqlite" "$conteo" ;;
            "expect") instalar_paquete_bin_apt_get "expect" "expect" "$conteo" ;;
            "crunch") instalar_paquete_bin_pkg "crunch" "crunch" "$conteo" ;;
            "iproute2") instalar_paquete_share "iproute2" "iproute2" "$conteo" ;;
            "busybox") instalar_paquete_bin_pkg "busybox" "busybox" "$conteo" ;;
            "termux-api") instalar_paquete_libexec "termux-api" "termux-api" "$conteo" ;;
            "proot-distro") instalar_paquete_bin_pkg "proot-distro" "proot-distro" "$conteo" ;;
            "libqrencode") instalar_paquete_share "libqrencode" "libqrencode" "$conteo" ;;
            "silversearcher-ag") instalar_paquete_share "silversearcher-ag" "silversearcher-ag" "$conteo" ;;
            # instalar_paquete_pip "gdown" "pip install gdown" "Error al instalar gdown. Asegúrate de tener pip instalado." "$conteo" ;;
            # instalar_paquete_pip "wcwidth" "pip install wcwidth" "Error al instalar wcwidth. Asegúrate de tener pip instalado." "$conteo" ;;
            # instalar_paquete_pip "unidecode" "pip install unidecode" "Error al instalar unidecode. Asegúrate de tener pip instalado." "$conteo" ;;
            *) echo "Paquete desconocido: $pkg" ;;
        esac
    done
    if [ "$count" -eq "${#pkgs[@]}" ]; then
        echo "Todos los paquetes instalados"
    fi
}

paquetes_termux

# Descomprimir con tar
# tar -xvzf archivo-comprimido.tar.gz

tamanio=$(wget --spider --server-response "https://raw.githubusercontent.com/RobertNissan/Busca-Palabras/main/Busca-Palabras.tar.gz" 2>&1 | 
awk '/Length:/ {print $2}' | head -n 1 | 
awk '{
    size = $1;
    if (size >= 1073741824) printf "%.2fGB\n", size / 1073741824;
    else if (size >= 1048576) printf "%.2fMB\n", size / 1048576;
    else if (size >= 1024) printf "%.2fKB\n", size / 1024;
    else printf "%dB\n", size;
}')
tar_extrator_progress() {
    total=$(tar -tzf Busca-Palabras.tar.gz | wc -l)
    count=0
    tar -xvzf Busca-Palabras.tar.gz | while read -r line; do
        count=$((count + 1))
        percent=$((count * 100 / total))
        echo -ne "Progreso: $percent% [$count/$total] archivos extraídos...\r"
    done
    echo -e "\nExtracción completada."
    # echo "Actualización completa!!!."
    sleep 2
}
archivo='Busca-Palabras.tar.gz'
mkdir -p /sdcard/backups
mkdir -p /sdcard/Alarms
if [ ! -f "$archivo" ]; then
    echo -e "";echo -e ""$white"   ••(DESCARGANDO SCRIPT BUSCA-PALABRAS)••    ";sleep 1.5;echo "Tamaño del archivo: ${tamanio}";wget --no-check-certificate --quiet --show-progress -O "${archivo}" "https://raw.githubusercontent.com/RobertNissan/Busca-Palabras/main/${archivo}";tar_extrator_progress;rm -r "${archivo}";cp -r Busca-Palabras /sdcard/backups;cd Busca-Palabras;chmod +x Menu-Busca-Palabras.sh;dos2unix Menu-Busca-Palabras.sh;chmod +x spawn;bash Menu-Busca-Palabras.sh;cd ${HOME}/Busca-Palabras/;fish
else
    tar_extrator_progress;rm -r "${archivo}";cp -r Busca-Palabras /sdcard/backups;cd Busca-Palabras;chmod +x Menu-Busca-Palabras.sh;dos2unix Menu-Busca-Palabras.sh;chmod +x spawn;bash Menu-Busca-Palabras.sh;cd ${HOME}/Busca-Palabras/;fish
fi
