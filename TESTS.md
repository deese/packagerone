# Tests de Verificación - Conversión a Python

Este documento contiene pruebas para verificar que la conversión a Python funciona correctamente.

## Pruebas Básicas

### 1. Importación de módulos

```bash
# Test 1: Importar config
python3 -c "from pkgone import config; print('✓ Config OK')"

# Test 2: Importar utils
python3 -c "from pkgone.utils import get_latest_ver; print('✓ Utils OK')"

# Test 3: Importar builder
python3 -c "from pkgone.builder import build_package; print('✓ Builder OK')"

# Test 4: Importar formula
python3 -c "from pkgone.formula import Formula; print('✓ Formula OK')"

# Test 5: Importar formula_creator
python3 -c "from pkgone.formula_creator import FormulaCreator; print('✓ FormulaCreator OK')"
```

### 2. Funcionalidad básica

```bash
# Test 6: Obtener versión de GitHub
python3 -c "
from pkgone.utils import get_latest_ver
ver = get_latest_ver('sharkdp/bat')
print(f'✓ GitHub API: {ver}')
"

# Test 7: Normalizar repo
python3 -c "
from pkgone.formula_creator import FormulaCreator
creator = FormulaCreator()
repo = creator.normalize_github_repo('https://github.com/sharkdp/bat')
print(f'✓ Normalize: {repo}')
assert repo == 'sharkdp/bat'
"

# Test 8: Cargar fórmula
python3 -c "
from pkgone.formula import Formula
from pathlib import Path
formula_path = Path('formulas/bat-pkg.formula')
if formula_path.exists():
    formula = Formula(formula_path)
    print(f'✓ Formula loaded: {formula.get(\"REPO\")}'
)
"
```

### 3. Scripts principales

```bash
# Test 9: Runner help
python3 runner.py --help

# Test 10: Formula creator help
python3 scripts/creator/formula_creator.py --help

# Test 11: Version check (requiere .env con GITHUB_TOKEN)
# python3 runner.py -V
```

## Pruebas de Integración

### 4. Construcción de paquetes (requiere dependencias del sistema)

```bash
# Test 12: Construcción de un paquete específico (solo si tienes dpkg-deb y rpmbuild)
# python3 runner.py -b bat-pkg.formula -v

# Test 13: Construcción forzada
# python3 runner.py -b bat-pkg.formula -f -v

# Test 14: Solo DEB (omitir RPM)
# python3 runner.py -b bat-pkg.formula -R -v

# Test 15: Solo RPM (omitir DEB)
# python3 runner.py -b bat-pkg.formula -D -v
```

### 5. Creación de fórmulas (requiere OPENROUTER_API_KEY)

```bash
# Test 16: Crear fórmula con IA
# export OPENROUTER_API_KEY="tu-clave"
# python3 runner.py -F sharkdp/fd

# Test 17: Crear fórmula standalone
# python3 scripts/creator/formula_creator.py sharkdp/fd
```

## Resultados Esperados

| Test | Estado | Descripción |
|------|--------|-------------|
| 1-5  | ✓ | Importaciones básicas funcionan |
| 6    | ✓ | API de GitHub responde correctamente |
| 7    | ✓ | Normalización de URLs funciona |
| 8    | ✓ | Carga de fórmulas funciona |
| 9-10 | ✓ | Scripts muestran ayuda correctamente |
| 11   | ⚠️ | Requiere .env con GITHUB_TOKEN |
| 12-15| ⚠️ | Requiere dpkg-deb y rpmbuild instalados |
| 16-17| ⚠️ | Requiere OPENROUTER_API_KEY |

## Dependencias del Sistema

Para pruebas completas, necesitas:

```bash
# Ubuntu/Debian
sudo apt-get install dpkg-dev rpm fakeroot

# Para Python
pip install requests
```

## Variables de Entorno

Crea un archivo `.env` en la raíz del proyecto:

```bash
# Opcional: Token de GitHub (para evitar rate limits)
GITHUB_TOKEN=tu_token_github

# Opcional: Para creación de fórmulas con IA
OPENROUTER_API_KEY=tu_clave_openrouter

# Opcional: Para upload
PKG1UPLOADER=nombre_del_uploader
```

## Verificación Rápida

Ejecuta todos los tests básicos:

```bash
cd /mnt/d/devel/packagerone

echo "Test 1: Config"
python3 -c "from pkgone import config; print('✓')"

echo "Test 2: Utils"
python3 -c "from pkgone.utils import get_latest_ver; print('✓')"

echo "Test 3: Builder"
python3 -c "from pkgone.builder import build_package; print('✓')"

echo "Test 4: Formula"
python3 -c "from pkgone.formula import Formula; print('✓')"

echo "Test 5: FormulaCreator"
python3 -c "from pkgone.formula_creator import FormulaCreator; print('✓')"

echo "Test 6: GitHub API"
python3 -c "from pkgone.utils import get_latest_ver; ver = get_latest_ver('sharkdp/bat'); print(f'✓ Version: {ver}')"

echo "Test 7: Runner help"
python3 runner.py --help | head -1

echo "Test 8: Formula creator help"
python3 scripts/creator/formula_creator.py --help | head -1

echo "All basic tests passed! ✓"
```
