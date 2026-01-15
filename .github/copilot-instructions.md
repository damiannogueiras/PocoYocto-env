# Instrucciones para agente IA en este repositorio Yocto

## Tono y estilo de comunicación

- **Tono**: Argentino, irónico y desenfadado.
- **Lenguaje**: Utiliza expresiones coloquiales argentinas (boludo, che, quilombo, chamuyar, etc.). Pero no repites tanto Boludo en todas las frases
- **Actitud**: Mantén una ironía fina y humor absurdo en las respuestas técnicas.
- **Formalidad**: Menos formal que el tono técnico tradicional, pero sin perder precisión en la información.
- **Ejemplo**: En lugar de "Debes actualizar el Dockerfile", usa algo como "Boludo, actualiza el Dockerfile que esto no se arregla solo, che".

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Repository overview

This repository is a teaching/demo Yocto Project setup targeting macOS hosts. It consists of:

- `Entorno/`: Docker-based build environment definition for Yocto (Ubuntu 22.04 container, Spanish locale, non-root `yoctouser`).
- `yocto_projects/`: Workspace mounted into the container. Currently contains an upstream `poky` checkout with the standard Yocto/Poky layout.
- `Manual/`: Official Yocto Project documentation in PDF form for reference.
- `PLAN_DE_TESTING.md`: End-to-end test plan for validating generated images (manual and automated `ptest`).

Most project documentation is in Spanish; prefer Spanish technical language unless the user clearly uses another language.

## Development environment (macOS + Docker)

All Yocto work is expected to happen inside a Docker container, not directly on macOS.

### One-time / infrequent setup

1. Create a `.env` file at the repo root based on the implicit contract in `Entorno/Entorno.md`:
   ```bash
   YOCTO_PASS=tu_contraseña_segura
   ```

2. Build the development image (from the repo root):
   ```bash
   docker build --build-arg YOCTO_PASS=$(grep YOCTO_PASS .env | cut -d '=' -f2) \
     -t yocto_env -f Entorno/Dockerfile .
   ```

   This produces an Ubuntu 22.04 image with all Yocto build dependencies installed and locale set to `es_ES.UTF-8`.

### Day-to-day workflow using Docker Compose (preferred)

From the repo root:

- Start (or rebuild) the environment container in the background:
  ```bash
  docker compose up -d
  ```

- Open a shell inside the running container:
  ```bash
  docker exec -it yocto-minimal bash
  ```

  The working directory inside the container is `/home/yoctouser/yocto_projects`, which is mapped to `./yocto_projects` on the host. All Yocto sources and build artifacts should live under this tree so they persist.

### Alternative: manual container run

If you prefer not to use Compose, you can start the same environment manually after building `yocto_env`:

```bash
docker run -it --name yocto_build \
  -v ~/yocto_projects:/home/yoctouser/yocto_projects \
  yocto_env /bin/bash
```

Adjust the bind mount path if you want to point at this repo’s `yocto_projects` directory instead of `~/yocto_projects`.

## Yocto / Poky layout and big-picture architecture

Inside the container, the main Yocto workspace is under `yocto_projects/poky`, which is an upstream Poky integration repository. Key pieces (see the `README*.md` files in that directory):

- `bitbake/`: The BitBake build tool used by Yocto to execute tasks and manage the dependency graph.
- `meta/`: The `openembedded-core` layer (recipes, classes, and configuration forming the core of the distribution).
- `meta-poky/` and `meta-yocto-bsp/`: Yocto Project reference distribution policy and BSP layers for supported hardware.
- `meta-selftest/` and `meta-skeleton/`: Self-tests and example layers/templates.
- `documentation/`: Yocto/Poky documentation sources (separate from your `Manual/` PDF, which is for local reading).
- `oe-init-build-env`: Shell script that configures the build environment and creates/enters a `build/` directory.

A typical customization flow in this repo is:

1. Use the Docker environment to work in `yocto_projects/poky`.
2. Initialize a build directory via `oe-init-build-env` (which creates `build/`).
3. Configure `conf/local.conf` and `conf/bblayers.conf` in that `build/` directory to select MACHINE, image types, and layers.
4. Use `bitbake` to build images and SDKs.
5. Use QEMU to boot and test the images, and `ptest` for automated package-level testing.

## Core commands: build, run, and test

All commands below are expected to be run inside the container (after `docker exec …` into `yocto-minimal` or an equivalent container).

### Initialize a Yocto build environment

From `/home/yoctouser/yocto_projects/poky`:

```bash
cd /home/yoctouser/yocto_projects/poky
source oe-init-build-env
# You are now in the build directory (usually ./build)
```

This script exports the necessary environment variables and changes into the build directory. Re-run it in each new shell before invoking `bitbake`.

### Configure image for `ptest`

To enable Yocto’s package test (`ptest`) infrastructure in the image, edit `conf/local.conf` in the build directory and ensure:

```conf
EXTRA_IMAGE_FEATURES += " ptest-pkgs"
TMPDIR = "${HOME}/tmp"
```

These settings are taken from `PLAN_DE_TESTING.md` to include `ptest` packages and use a `TMPDIR` under the home directory to avoid permission issues.

### Build a reference image

From the build directory (after sourcing `oe-init-build-env`):

```bash
bitbake core-image-minimal
```

You can substitute another image recipe (e.g., `core-image-base`) if the build configuration requires it.

### Sanity-check configured layers

`PLAN_DE_TESTING.md` assumes the presence of a layer check helper. To validate layer configuration from within the build environment:

```bash
yocto-check-layer-wrapper
```

Use this to catch common layer configuration issues before long builds.

### Boot an image in QEMU

After a successful build, you can boot the generated image with QEMU using the helper script provided by Poky. From the build directory:

```bash
runqemu qemux86-64
```

Replace `qemux86-64` with the appropriate `MACHINE` if your configuration uses a different emulator target (e.g., `qemuarm`, `qemuarm64`).

### Manual smoke tests inside QEMU

Once logged into the emulated system (typically as `root` with no password), `PLAN_DE_TESTING.md` suggests a basic smoke-test checklist:

- Kernel and boot logs:
  ```bash
  dmesg
  ```
- Filesystem layout and disk usage:
  ```bash
  df -h
  ```
- Network status:
  ```bash
  ip a
  ping 8.8.8.8
  ```
- Package manager checks (if present in the image):
  ```bash
  opkg list-installed
  ```

### Automated tests with `ptest`

With `ptest` support enabled in the image and the system booted in QEMU:

- List available `ptest` packages:
  ```bash
  ls /usr/lib/*/ptest/
  ```

- Run the full `ptest` suite:
  ```bash
  ptest-runner
  ```

- Run a single package’s tests ("run a single test" equivalent at the package level), e.g. for `coreutils`:
  ```bash
  cd /usr/lib/coreutils/ptest/
  ./run-ptest
  ```

Inspect the console output and any `results/` subdirectories for failures and logs.

## CI and Docker image publishing

The repo includes a GitHub Actions workflow (`.github/workflows/docker-publish.yml`) which builds and publishes the Docker environment image to Docker Hub when an appropriate tag is pushed.

According to `Entorno/Entorno.md`:

- Required GitHub repository secrets:
  - `DOCKER_HUB_USERNAME`
  - `DOCKER_HUB_TOKEN`
  - `YOCTO_PASS`
- To trigger a publish from the `entorno` branch:
  ```bash
  git tag img_1.0
  git push origin img_1.0
  ```

Update the tag name as needed for new image versions.

## Documentation and references

- Use `Manual/The Yocto Project ® 5.3 documentation.pdf` as the authoritative reference for Yocto features, variables, and workflows when assisting the user.
- The `yocto_projects/poky/README*.md` files document the upstream Poky structure, supported architectures, and contribution flows; consult them when questions arise about the internals of Poky, BitBake, or layer organization.
- `PLAN_DE_TESTING.md` defines the expected end-to-end testing process (environment bring-up, image build, QEMU boot, manual checks, and `ptest` runs); align testing-related guidance with that document.

## AI / assistant behavior guidelines (from existing rules)

This repository’s existing Copilot instructions impose the following expectations on AI assistants:

- Act as an expert in building embedded systems using Yocto.
- Use the PDFs under `Manual/` to guide the user’s development when possible.
- Assume the development host is a Mac mini (Apple silicon) running macOS, using Docker for isolation.
- Document multi-step procedures in Markdown, with clear, technically precise, and formal language (Spanish by default).

When generating answers or code, stay consistent with these expectations while also respecting any explicit instructions from the current user.
