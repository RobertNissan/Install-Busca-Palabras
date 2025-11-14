#!/bin/bash

# Fecha inicio 01/Sep/2021
# actualizado 26/Jun/2024
# Por: @robert_nissan

# COLORES
rojo='\e[1m\e[31m'
verde='\e[1m\e[32m'
white="\e[1;37m\e[0m"
amarillo='\e[1m\e[33m'
azulcielo='\e[1m\e[36m'
COLOR_RESET="\033[0m"
echo -e ""$verde"=-=-=-=(PERMISOS DE ALMACENAMIENTO)=-=-=-="
# Verificar si los permisos de almacenamiento ya han sido concedidos
# Ruta de prueba
prueba_ruta="/sdcard/.prueba_permiso_termux.txt"
# Verificar el estado del almacenamiento
verificar_almacenamiento() {
    if [ -d "/sdcard/" ]; then
        # Intentar crear un archivo para verificar los permisos
        echo "Prueba de permisos" > "$prueba_ruta" 2>/dev/null
        if [ -f "$prueba_ruta" ]; then
            echo -e "${verde}Los permisos de almacenamiento ya han sido concedidos.${COLOR_RESET}"
            rm "$prueba_ruta"  # Eliminar el archivo de prueba
            return 0
        else
            echo -e "${rojo}El directorio existe, pero los permisos de escritura no están disponibles.${COLOR_RESET}"
        fi
    fi

    # Si llegamos aquí, es porque no se tienen los permisos
    echo -e "${amarillo}Concediendo permisos de almacenamiento...${COLOR_RESET}"
    termux-setup-storage
    sleep 5  # Esperar un momento para permitir que se concedan los permisos

    # Verificar de nuevo los permisos
    if [ -d "/sdcard/" ]; then
        echo "Prueba de permisos" > "$prueba_ruta" 2>/dev/null
        if [ -f "$prueba_ruta" ]; then
            echo -e "${verde}Permisos de almacenamiento concedidos correctamente.${COLOR_RESET}"
            rm "$prueba_ruta"  # Eliminar el archivo de prueba
            return 0
        else
            echo -e "${rojo}No se pudieron conceder los permisos de almacenamiento. Asegúrate de aceptar la solicitud de permisos.${COLOR_RESET}"
            return 1
        fi
    else
        echo -e "${rojo}El directorio de almacenamiento no está disponible. Asegúrate de aceptar la solicitud de permisos.${COLOR_RESET}"
        return 1
    fi
}

# Ejecutar la función
verificar_almacenamiento
echo -e ""$amarillo"<>=<>=<>=INSTALANDO DEPENDENCIAS=<>=<>=<>${COLOR_RESET}";sleep 2;

# Función principal para instalar paquetes
instalar_paquetes() {
    if [ $# -eq 0 ]; then
        echo "Uso: instalar_paquetes <paquete1> [paquete2] [paquete3] ..."
        echo "Ejemplos:"
        echo "  instalar_paquetes git wget curl"
        echo "  instalar_paquetes pip:colorama apt:curl pkg:git"
        return 1
    fi

    local STTY_STATE=""

    bloquear_teclado() {
        STTY_STATE="$(stty -g 2>/dev/null || true)"
        stty -icanon -echo min 0 time 0 2>/dev/null || true
    }

    restaurar_teclado() {
        [ -n "${STTY_STATE:-}" ] && stty "$STTY_STATE" 2>/dev/null || true
        printf '\033[?25h'
    }

    ocultar_cursor() {
        printf '\033[?25l'
    }

    trap restaurar_teclado RETURN EXIT INT TERM TSTP
    bloquear_teclado
    ocultar_cursor

    # Convertir argumentos a formato Python
    local args_python=""
    for arg in "$@"; do
        args_python="$args_python\"$arg\", "
    done

python3 - <<PY
import sys, shutil, subprocess, signal, time, re, unicodedata, os, pty, select, threading
from collections import deque

# Obtener argumentos desde bash
raw_packages = [${args_python%%, }]

def expand_packages(raw_list):
    result = []
    current_manager = "pkg"  # gestor por defecto

    for entry in raw_list:
        entry = entry.strip()
        if not entry:
            continue

        if ":" in entry:
            # Cambiar el gestor actual
            manager, pkgs = entry.split(":", 1)
            current_manager = manager.strip()
            # Procesar paquetes de este gestor
            for pkg in pkgs.split():
                if pkg.strip():
                    result.append((current_manager, pkg.strip()))
        else:
            # Usar el gestor actual para paquetes sin prefijo
            for pkg in entry.split():
                if pkg.strip():
                    result.append((current_manager, pkg.strip()))
    return result

packages = expand_packages(raw_packages)

ANSI_RE = re.compile(r'\x1B(?:[@-Z\-_]|\b\[[0-?]*[ -/]*[@-~])')

def clean_output(s: str) -> str:
    if not s:
        return ""
    s = ANSI_RE.sub("", s)
    s = s.replace("\t", "    ")
    return s

def escape_line_for_box(line: str) -> str:
    return line if line else ""

def process_backspaces(s: str) -> str:
    out = []
    for ch in s:
        if ch == '\b':
            if out:
                out.pop()
        else:
            out.append(ch)
    return "".join(out)

PROGRESS_KEYWORDS = ("Downloading", "MB/s", "Progress", "eta", "ETA", "saved", "━", "%", "Collecting", "Installing", "Building")

def is_progress_line(s: str) -> bool:
    if not s:
        return False
    low = s.lower()
    return any(k.lower() in low for k in PROGRESS_KEYWORDS)

MAX_BOX_CONTENT_LINES = 15
SIDE_PADDING = 1
RIGHT_PADDING = 2
MARGIN_RIGHT = 0

def get_terminal_width():
    try:
        return os.get_terminal_size().columns
    except OSError:
        return 80

def get_content_width(term_w):
    return max(term_w - MARGIN_RIGHT - 2 - SIDE_PADDING - RIGHT_PADDING, 2)

try:
    from wcwidth import wcwidth
except ImportError:
    def wcwidth(ch):
        if ch == '\t': return 4
        if unicodedata.combining(ch): return 0
        ea = unicodedata.east_asian_width(ch)
        return 2 if ea in ('F','W') else 1

ansi_re = re.compile(r'\x1b\[[0-9;]*m')
def strip_ansi(s):
    return ansi_re.sub('', s)
def visible_len(s):
    return sum(max(0, wcwidth(c)) for c in strip_ansi(s))

def wrap_line_ansi(text, width):
    lines = []
    current_line = ""
    current_len = 0

    for text_part in text.splitlines():
        words = re.split(r'(\s+)', text_part)

        for word in words:
            vis_len = visible_len(word)
            if current_len + vis_len > width:
                if current_len > 0:
                    lines.append(current_line)
                    current_line = ""
                    current_len = 0

                if vis_len > width:
                    temp_word = ""
                    temp_len = 0
                    for char in word:
                        char_len = visible_len(char)
                        if temp_len + char_len > width:
                            lines.append(current_line + temp_word)
                            current_line = ""
                            current_len = 0
                            temp_word = char
                            temp_len = char_len
                        else:
                            temp_word += char
                            temp_len += char_len
                    word = temp_word
                    vis_len = temp_len

            current_line += word
            current_len += vis_len

        if current_line:
            lines.append(current_line)
            current_line = ""
            current_len = 0

    return lines if lines else [""]

def draw_panel(lines, title="", messages_above=None, last_height=[0]):
    if messages_above is None:
        messages_above = []

    term_w, _ = shutil.get_terminal_size((80,24))
    content_width = get_content_width(term_w)

    border_color, reset = "\033[1;35m", "\033[0m"

    padding_total = SIDE_PADDING + RIGHT_PADDING
    horizontal = "─" * (content_width + padding_total)
    top = f"{border_color}╭{horizontal}╮{reset}"
    bottom = f"{border_color}╰{horizontal}╯{reset}"

    wrapped = []
    for L in lines:
        cleaned_line = clean_output(L)
        wrapped.extend(wrap_line_ansi(cleaned_line, content_width))

    visible = wrapped[-MAX_BOX_CONTENT_LINES:]

    if last_height[0] > 0:
        sys.stdout.write(f"\033[{last_height[0]}A\r")

    output = []
    for msg in messages_above:
        output.append("\033[2K" + msg)

    output.append("\033[2K" + top)

    title_line_content = ' ' * (content_width + padding_total)
    if title:
        clean_title = clean_output(title)
        vis_title_len = visible_len(clean_title)
        padding_needed = content_width - vis_title_len
        title_disp = clean_title + " " * max(0, padding_needed)
        title_line_content = ' ' * SIDE_PADDING + title_disp + ' ' * RIGHT_PADDING
    output.append(f"\033[2K{border_color}│{reset}" + title_line_content + f"{border_color}│{reset}")

    empty_lines = MAX_BOX_CONTENT_LINES - len(visible)
    for _ in range(empty_lines):
        output.append(f"\033[2K{border_color}│{reset}" + ' ' * (content_width + padding_total) + f"{border_color}│{reset}")

    for L in visible:
        vis_L_len = visible_len(L)
        padding_needed = content_width - vis_L_len
        L_disp = L + " " * max(0, padding_needed)
        output.append(f"\033[2K{border_color}│{reset}" + ' ' * SIDE_PADDING + L_disp + ' ' * RIGHT_PADDING + f"{border_color}│{reset}")

    output.append("\033[2K" + bottom)

    sys.stdout.write('\n'.join(output) + '\n')
    sys.stdout.flush()

    last_height[0] = len(output)

SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
def spinner_thread(stop_event, spinner_state):
    i = 0
    while not stop_event.is_set():
        spinner_state[0] = SPINNER_FRAMES[i % len(SPINNER_FRAMES)]
        i += 1
        time.sleep(0.08)

def is_package_installed(manager, package):
    try:
        if manager == "pip":
            result = subprocess.run(["pip", "show", package], capture_output=True, text=True, timeout=5)
            return result.returncode == 0

        elif manager == "pkg":
            try:
                # Comprobar con pkg list-installed (forma más confiable en Termux)
                result = subprocess.run(["pkg", "list-installed"], capture_output=True, text=True, timeout=5)
                if result.returncode == 0 and f"{package}/" in result.stdout:
                    return True
                # Si no aparece, usar dpkg como respaldo
                result = subprocess.run(["dpkg", "-s", package], capture_output=True, text=True, timeout=5)
                return result.returncode == 0 and "Status: install ok installed" in result.stdout
            except Exception:
                return False

        elif manager in ["apt", "apt-get"]:
            result = subprocess.run(["dpkg", "-s", package], capture_output=True, text=True, timeout=5)
            return result.returncode == 0 and "Status: install ok installed" in result.stdout

    except Exception:
        return False
    return False

def run_install_for(manager, package, messages_above, last_height):
    if is_package_installed(manager, package):
        print(f"\033[1;33m⚠️ {package} ya estaba instalado ({manager}).\033[0m")
        return True

    display_buffer = deque(maxlen=MAX_BOX_CONTENT_LINES)
    spinner_state = ["⠋"]
    stop_event = threading.Event()
    t = threading.Thread(target=spinner_thread, args=(stop_event, spinner_state))
    t.daemon = True
    t.start()

    try: os.system("tput civis")
    except: pass

    if manager == "pip":
        cmd = ["pip", "install", package, "--progress-bar=on"]
    elif manager == "pkg":
        cmd = ["pkg", "install", "-y", package]
    elif manager == "apt":
        cmd = ["apt", "install", "-y", package]
    else:
        cmd = ["apt-get", "install", "-y", package]

    master, slave = pty.openpty()
    proc = subprocess.Popen(cmd, stdin=slave, stdout=slave, stderr=slave, close_fds=True)
    os.close(slave)
    buf = b""

    try:
        while proc.poll() is None:
            title = f"{spinner_state[0]} 🔧 Instalando {package} con {manager}..."
            r, _, _ = select.select([master], [], [], 0.05)
            if r:
                try:
                    chunk = os.read(master, 4096)
                except OSError:
                    break
                if not chunk: break
                buf += chunk

            while True:
                cr_pos = buf.find(b'\r')
                lf_pos = buf.find(b'\n')
                if cr_pos == -1 and lf_pos == -1: break
                pos = min(p for p in [cr_pos, lf_pos] if p != -1)
                is_cr = (pos == cr_pos)
                line_bytes = buf[:pos]
                buf = buf[pos + 1:]
                line = line_bytes.decode('utf-8', 'ignore')

                if is_cr:
                    if display_buffer:
                        display_buffer[-1] = escape_line_for_box(process_backspaces(line))
                    else:
                        display_buffer.append(escape_line_for_box(process_backspaces(line)))
                else:
                    display_buffer.append(escape_line_for_box(process_backspaces(line.rstrip())))

            render_buffer = list(display_buffer)
            if buf and render_buffer:
                remains_str = buf.decode('utf-8', 'ignore')
                if is_progress_line(remains_str):
                    render_buffer[-1] = escape_line_for_box(process_backspaces(remains_str))

            draw_panel(render_buffer, title=title, messages_above=[], last_height=last_height)

        proc.wait()
    finally:
        stop_event.set()
        t.join()
        try: os.close(master)
        except: pass

    # Limpiar el recuadro
    for _ in range(last_height[0]):
        sys.stdout.write("\033[F\033[2K")
    sys.stdout.flush()
    last_height[0] = 0

    # Mostrar resultado
    if proc.returncode == 0:
        print(f"\033[1;32m✅ {package} instalado correctamente ({manager}).\033[0m")
    else:
        print(f"\033[1;31m❌ Error instalando {package} con {manager}.\033[0m")

    try: os.system("tput cnorm")
    except: pass
    return proc.returncode == 0

if __name__ == "__main__":
    messages_above = []
    last_height = [0]

    for manager, pkg in packages:
        run_install_for(manager, pkg, messages_above, last_height)
PY

    restaurar_teclado
}

# Llamar a la función con la lista de paquetes requeridos
instalar_paquetes "pkg:jq bc pv android-tools crunch iproute2 busybox termux-api proot-distro libqrencode silversearcher-ag" "apt:tsu fish proot rsync python" "apt-get:expect"

# Descomprimir con tar
# tar -xvzf archivo-comprimido.tar.gz

archivo='Busca-Palabras.tar.gz'
mkdir -p /sdcard/backups
if [ ! -f "$archivo" ]; then
    echo -e "";echo -e ""$white"   ••(DESCARGANDO SCRIPT BUSCA-PALABRAS)••    ";sleep 1.5;wget https://www.dropbox.com/s/dat7yzgquuhe3og/Busca-Palabras.tar.gz?dl=0;mv Busca-Palabras.tar.gz?dl=0 Busca-Palabras.tar.gz;tar -xvzf Busca-Palabras.tar.gz;rm -r Busca-Palabras.tar.gz;cp -r Busca-Palabras /sdcard/backups;cd Busca-Palabras;chmod +x Menu-Busca-Palabras.sh;dos2unix Menu-Busca-Palabras.sh;chmod +x spawn;bash Menu-Busca-Palabras.sh;cd ${HOME}/Busca-Palabras/;fish
else
    tar -xvzf Busca-Palabras.tar.gz;rm -r Busca-Palabras.tar.gz;cp -r Busca-Palabras /sdcard/backups;cd Busca-Palabras;chmod +x Menu-Busca-Palabras.sh;dos2unix Menu-Busca-Palabras.sh;chmod +x spawn;bash Menu-Busca-Palabras.sh;cd ${HOME}/Busca-Palabras/;fish
fi
