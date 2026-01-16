# Configuración del Entorno Yocto en macOS con Docker

Este documento describe los pasos para configurar un entorno de desarrollo para Yocto Project en macOS utilizando Docker de forma segura.

## 1. Requisitos Previos

Asegúrate de tener el siguiente software instalado en tu Mac:

*   **Homebrew**: El gestor de paquetes para macOS.
*   **Docker Desktop**: La herramienta para crear y gestionar contenedores.

**Importante**: Antes de continuar, asegúrate de que la aplicación Docker Desktop esté en ejecución.

## 2. Creación del Entorno Docker

Para asegurar un entorno de compilación limpio y consistente, usaremos un `Dockerfile` y un archivo `.env` para gestionar secretos.

### Paso 1: Configurar la Contraseña en `.env`

Por seguridad, la contraseña del usuario dentro del contenedor no se escribirá directamente en el `Dockerfile`. En su lugar, se pasará como un argumento durante la construcción de la imagen.

1.  **Crea un archivo `.env`** en el directorio raíz del proyecto (`Yocto`).
2.  **Añade la siguiente línea** a este archivo, reemplazando `tu_contraseña_segura` por la que desees:

    ```
    YOCTO_PASS=tu_contraseña_segura
    ```

3.  He creado un archivo `.env.example` para que sirva de guía y un `.gitignore` para asegurar que el archivo `.env` no se suba al repositorio.

### Paso 2: Crear el `Dockerfile`

El `Dockerfile` utiliza un argumento (`ARG`) para recibir la contraseña en el momento de la construcción. Nota: en esta versión del repo el `Dockerfile` está en la raíz del proyecto (archivo `Dockerfile`).

### Paso 3: Construir la Imagen Docker

Abre una terminal, asegúrate de estar en el directorio raíz de este proyecto y ejecuta el siguiente comando:

Este comando lee el `Dockerfile` en la raíz, extrae la contraseña de tu archivo `.env` de forma segura y la pasa como argumento para construir la imagen `yocto_env`.

```bash
# Desde la raíz del repo (zsh):
docker build --build-arg YOCTO_PASS=$(grep YOCTO_PASS .env | cut -d '=' -f2) -t yocto_env -f Dockerfile .
```

La construcción puede tardar varios minutos.

### Paso 4: Iniciar el Contenedor

Una vez construida la imagen, inicia un contenedor. Este será tu entorno de trabajo para Yocto.

### Alternativa recomendada: Docker Compose

Si preferís usar Docker Compose, hay un `docker-compose.yml` en la raíz del repo que define un servicio llamado `yocto`.

Para levantar el entorno en background:

```bash
# Desde la raíz del repo (zsh):
docker compose up -d
```

Esto construye (si hace falta) y arranca el contenedor `yocto` en segundo plano.

Para abrir una shell dentro del contenedor en ejecución:

```bash
# Accedé al shell del contenedor llamado 'yocto-minimal' (nombre definido en docker-compose.yml)
docker exec -it pocoyocto /bin/bash
```

Si preferís usar el nombre del servicio en lugar del container_name (por ejemplo en entornos donde no se setea `container_name`), podés usar:

```bash
# Accedé al shell usando el nombre del servicio
docker compose exec yocto /bin/bash
```

Notas:

* El `docker-compose.yml` actual monta `../yocto_projects` (ruta relativa desde la carpeta que contiene `docker-compose.yml`) en `/home/yoctouser/yocto_projects` dentro del contenedor. Asegurate de que la carpeta `yocto_projects` exista en la ruta esperada.
* El `container_name` dentro del compose es `yocto-minimal`, y el servicio se llama `yocto`.

### Volumen dedicado para caches y outputs de Yocto

Se ha añadido un volumen Docker llamado `yocto-output` montado dentro del contenedor en `/home/yoctouser/yocto_output`. Está pensado para alojar:

- sstate-cache
- downloads (DL_DIR)
- tmp (TMPDIR)
- imágenes y artefactos temporales de la compilación

Esto permite persistir y compartir caches entre ejecuciones y contenedores sin llenar el proyecto ni el host.

Cómo inicializar el volumen y fijar permisos (desde tu Mac, zsh):

```bash
# 1) Levantá el compose (crea el volumen si no existe):
docker compose up -d

# 2) Inicializá las carpetas dentro del volumen y fijá propietario a UID/GID 1000:1000
#    (reemplazá 1000:1000 si el usuario 'yoctouser' dentro del contenedor tiene otro uid/gid)
docker run --rm -v yocto-output:/mnt busybox sh -c "mkdir -p /mnt/sstate-cache /mnt/downloads /mnt/tmp /mnt/deploy && chown -R 1000:1000 /mnt"
```

Comprobá el UID/GID dentro del contenedor si no estás seguro:

```bash
# Accedé al contenedor y comprobá UID/GID
docker exec -it yocto-minimal id yoctouser
```

Recomendaciones para `build/conf/local.conf` (dentro del build de Yocto):

Agregá estas líneas para que BitBake use el volumen:

```
SSTATE_DIR ?= "/home/yoctouser/yocto_output/sstate-cache"
DL_DIR ?= "/home/yoctouser/yocto_output/downloads"
TMPDIR = "/home/yoctouser/yocto_output/tmp"
```

Alternativa: si preferís no modificar `local.conf`, las variables fueron exportadas en el `docker-compose.yml` bajo `environment:` para que estén disponibles en el contenedor.

Binder mount al host (opcional)

Si preferís mapear directamente a un directorio en tu Mac para poder inspeccionar archivos desde Finder o editar desde el host, podés cambiar el montaje por un bind-mount absoluto en `docker-compose.yml`:

```
# ejemplo: /Users/mini/yocto_output en macOS
- /Users/mini/yocto_output:/home/yoctouser/yocto_output:rw
```

Si usás bind-mount, asegurate de crear las carpetas en el host y luego ajustar permisos desde dentro del contenedor:

```bash
mkdir -p /Users/mini/yocto_output/{sstate-cache,downloads,tmp}
# luego desde dentro del contenedor:
# chown -R yoctouser:yoctouser /home/yoctouser/yocto_output
```

---

Decisión (resumen): usamos volumen Docker y NO bind-mount

Boludo, lo dejamos claro: vamos con un volumen Docker llamado `yocto-output` y NO con bind-mounts al host. ¿Por qué? Porque macOS por defecto tiene un filesystem case-insensitive y eso puede armar un quilombo con BitBake/Yocto (nombres de archivo, hashes, caches). Un volumen Docker usa el driver del host y evita esos problemas. Además mantiene las caches fuera del árbol del proyecto y es más sencillo de compartir entre contenedores.

Qué implica (rápido):

- Levantás el entorno en background con:

```bash
# Desde la raíz del repo (zsh):
docker compose up -d
```

- El volumen `yocto-output` se crea automáticamente (si no existe) por el `docker-compose.yml`.
- Inicializalo y fijá permisos (ejecutalo desde tu Mac):

```bash
# crea carpetas internas y pone owner 1000:1000 (ajustá si el UID/GID es distinto)
docker run --rm -v yocto-output:/mnt busybox sh -c "mkdir -p /mnt/sstate-cache /mnt/downloads /mnt/tmp /mnt/deploy && chown -R 1000:1000 /mnt"
```

Cómo recuperar la(s) imagen(es) para flashear (desde un volumen Docker)

Cuando usás un volumen Docker en lugar de un bind, los artefactos quedan dentro del volumen. Para flashear una SD/EMMC necesitás copiar la imagen (.wic, .img, .sdcard, etc.) del volumen al host. Estos son métodos simples y robustos:

1) Inspeccionar dónde están las imágenes dentro del volumen

Las imágenes generadas por Yocto suelen residir en `${TMPDIR}/deploy/images/<MACHINE>`; si configuraste `TMPDIR` tal como sugerimos, esa ruta dentro del contenedor será `/home/yoctouser/yocto_output/tmp/deploy/images/<MACHINE>`.

2) Copiar con un contenedor temporal (recomendado)

Desde tu Mac (en la raíz del repo), ejecutá este comando para copiar las imágenes a un directorio local `./out`:

```bash
# crea carpeta local donde quieras recibir las imágenes
mkdir -p out

docker run --rm -v yocto-output:/mnt -v "$(pwd)/out":/host/out --entrypoint sh busybox -c '
  # intentá copiar desde las rutas más probables; ajustá si tu TMPDIR es distinto
  if [ -d "/mnt/tmp/deploy/images" ]; then
    cp -r /mnt/tmp/deploy/images /host/out/
  elif [ -d "/mnt/deploy/images" ]; then
    cp -r /mnt/deploy/images /host/out/
  else
    echo "No encontré deploy/images en el volumen. Abrí una shell para inspeccionar: docker run --rm -it -v yocto-output:/mnt busybox sh"
    exit 1
  fi
'
```

Al terminar, vas a tener las imágenes en `./out/images/` en tu Mac y podés abrirlas con Finder o flashearlas.

3) Alternativa: entrar al volumen en modo interactivo

Si querés husmear manualmente antes de copiar:

```bash
docker run --rm -it -v yocto-output:/mnt --entrypoint sh busybox
# dentro podés listar: ls -la /mnt/tmp/deploy/images || ls -la /mnt/deploy/images
```

4) Si ya tenés un contenedor en ejecución que monta el volumen

Podés usar `docker exec` + `docker cp` para copiar desde ese contenedor al host; ejemplo:

```bash
# desde mac: crea un directorio receptor
mkdir -p out
# luego desde el host (reemplazá yocto-minimal por el nombre del contenedor que esté montando el volumen)
docker exec yocto-minimal ls -la /home/yoctouser/yocto_output/tmp/deploy/images
# y para copiar (si el archivo está en /home/yoctouser/yocto_output/tmp/deploy/images/<MACHINE>/image.wic):
docker cp yocto-minimal:/home/yoctouser/yocto_output/tmp/deploy/images/<MACHINE>/image.wic ./out/
```

Recomendación para flashear: usá balenaEtcher

Mi recomendación práctica: bajate balenaEtcher y usalo para flashear SDs o eMMC. Es simple, cross-platform y evita cagadas con opciones de dd mal puestas.

Pasos rápidos con balenaEtcher:

1.  Descargá e instalá balenaEtcher desde https://www.balena.io/etcher/.
2.  Abrí balenaEtcher, seleccioná la imagen `.wic`, `.img` o `.raw` que copiaste a `./out`.
3.  Seleccioná la unidad (SD/USB/eMMC) y clickeá "Flash".

Si preferís la línea de comandos podés usar `dd` con cuidado (no te mande un dd a la cara con la unidad equivocada), pero para la mayoría balenaEtcher es menos riesgoso.

Nota sobre case-sensitivity (por qué evitar bind-mount en macOS)

- macOS suele usar APFS o HFS+ en modo case-insensitive. Yocto/BitBake y muchas herramientas esperan un FS case-sensitive. Usar bind-mount a un FS case-insensitive puede provocar errores sutiles: fallos en checksum, paquetes recompilándose sin motivo, paths que colisionan, etc.
- Un volumen Docker (driver por defecto) evita ese problema porque se maneja con el sistema de archivos del runtime del contenedor y no con el host macOS directamente.

Si aún así querés bind-mount, asegurate de usar una partición o imagen de disco formateada como case-sensitive y montarla antes de usarla.

---

## 3. Despliegue Automatizado (GitHub Actions)

Se ha configurado una GitHub Action para construir y publicar la Docker image cuando se crea una etiqueta (tag). El workflow relevante está en la raíz del repo en:

```
.github/workflows/docker-publish.yml
```

(antes ese workflow vivía bajo una carpeta diferente; ahora está en la ubicación estándar de GitHub Actions).

### Configuración de la Action

En el directorio `Entorno/.github/workflows/` se encuentra el archivo `docker-publish.yml` que define la Action.

Básicamente configura un ubuntu y lanza el Dockerfile para luego subirla a Docker Hub.

### Configuración de Secretos en GitHub

Para que la Action funcione, debes configurar los siguientes **Repository Secrets** en GitHub (`Settings > Secrets and variables > Actions`):

1.  `DOCKER_HUB_USERNAME`: Tu nombre de usuario de Docker Hub.
2.  `DOCKER_HUB_TOKEN`: Un Access Token generado en Docker Hub (no uses tu contraseña real).
3.  `YOCTO_PASS`: La contraseña que se usará para el usuario `yoctouser` dentro de la imagen publicada.

### Cómo disparar la publicación

1.  Asegúrate de estar en la rama `entorno` (o la rama configurada para publicar la imagen).
2.  Crea una etiqueta que empiece por `img_` y súbela:
    ```bash
    git tag img_1.0
    git push origin img_1.0
    ```

### Archivos añadidos en el repo

- `.env.example`: plantilla para crear tu `.env` privado.
- `.gitignore`: entradas recomendadas para ignorar artefactos locales y secrets.
