# PackageOne - Python Version

Este directorio contiene la versión Python de PackageOne, una herramienta automatizada para construir paquetes DEB y RPM desde releases de GitHub.

## Estructura

- `pkgone/` - Módulo principal de Python
  - `__init__.py` - Inicialización del módulo
  - `config.py` - Configuración y variables de entorno
  - `utils.py` - Funciones utilitarias
  - `formula.py` - Cargador y parser de fórmulas
  - `builder.py` - Constructor principal de paquetes
  - `deb_builder.py` - Constructor de paquetes DEB
  - `rpm_builder.py` - Constructor de paquetes RPM
  - `version_check.py` - Verificador de versiones
  - `formula_creator.py` - Creador de fórmulas con IA

- `runner.py` - Script principal de ejecución
- `scripts/creator/formula_creator.py` - Script standalone para crear fórmulas

## Instalación de dependencias

```bash
pip install requests
```

## Uso

```bash
# Construir todos los paquetes
python3 runner.py

# Construir un paquete específico
python3 runner.py -b bat-pkg.formula

# Verificar versiones
python3 runner.py -V

# Construir forzadamente (sin verificar versiones)
python3 runner.py -f

# Solo construir DEB (omitir RPM)
python3 runner.py -R

# Solo construir RPM (omitir DEB)
python3 runner.py -D

# Modo verbose
python3 runner.py -v

# Subir paquetes
python3 runner.py -u

# Crear fórmula automáticamente (requiere AI)
python3 runner.py -F repository/name

# O usando el script standalone
python3 scripts/creator/formula_creator.py owner/repo
python3 scripts/creator/formula_creator.py https://github.com/owner/repo
```

## Migración desde bash

La versión Python mantiene la misma funcionalidad que los scripts bash originales:

- `runner.sh` → `runner.py`
- `scripts/functions.sh` → `pkgone/utils.py`
- `scripts/pkg-common.sh` → `pkgone/builder.py`
- `scripts/deb-builder.sh` → `pkgone/deb_builder.py`
- `scripts/rpm-builder.sh` → `pkgone/rpm_builder.py`
- `scripts/version_check.sh` → `pkgone/version_check.py`
- `scripts/environ.sh` → `pkgone/config.py`

## Archivos excluidos

Los siguientes archivos no fueron convertidos (código legacy):

- `scripts/neovim-pkg.sh`
- `scripts/uploader_buildkite.sh`

## Creación de fórmulas con IA

El creador de fórmulas usa IA para generar automáticamente archivos de fórmula basándose en el repositorio de GitHub.

### Requisitos

Configura tu clave de API de OpenRouter:

```bash
export OPENROUTER_API_KEY="tu-clave-aqui"
```

O agrégala a tu archivo `.env`:

```
OPENROUTER_API_KEY=tu-clave-aqui
```

### Uso

```bash
# Método 1: Usando runner.py
python3 runner.py -F sharkdp/bat

# Método 2: Script standalone
python3 scripts/creator/formula_creator.py sharkdp/bat

# También acepta URLs completas
python3 scripts/creator/formula_creator.py https://github.com/sharkdp/bat
```

El script:
1. Descarga información del último release de GitHub
2. Identifica el mejor archivo para descargar (prioriza tar.gz, GNU sobre musl)
3. Descarga y lista el contenido del archivo
4. Usa IA para generar la fórmula
5. Te muestra la fórmula generada para revisión
6. Pregunta si quieres guardarla

**Importante**: Siempre revisa las fórmulas generadas por IA antes de usarlas en producción.

- ✅ Descarga automática de releases desde GitHub
- ✅ Construcción de paquetes DEB
- ✅ Construcción de paquetes RPM
- ✅ Verificación de versiones
- ✅ Sistema de caché de versiones
- ✅ Soporte para variables de entorno (.env)
- ✅ Logging detallado
- ✅ Construcción en paralelo posible
- ✅ Creación automática de fórmulas con IA (OpenRouter/ChatGPT)
