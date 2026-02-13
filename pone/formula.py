"""Formula loading and parsing."""

import re
import sys
import platform
from pathlib import Path
from typing import Dict, List, Any

from . import config    

if sys.version_info >= (3, 11):
    import tomllib
else:
    try:
        import tomli as tomllib
    except ImportError:
        raise ImportError("Python < 3.11 requires 'tomli' package. Install with: pip install tomli")


class Formula:
    """Represents a package formula configuration."""
    current_os: str = platform.system().lower()
    custom_variables = [ "package_name", "arch", "os", "extension", "bin_dest", "share_dest" ]
    def __init__(self, filepath: Path):
        self.filepath = filepath
        self.config: Dict[str, Any] = {}
        self._load()
        self._resolve_variables()

    def set_os(self, os_name: str):
        """Set the current OS for conditional logic."""
        self.current_os = os_name
        self._resolve_variables()
    
    def _flatten_dict(self, data: dict, parent_key: str = '', sep: str = '_') -> dict:
        """Flatten a nested dictionary."""
        items = []
        for k, v in data.items():
            new_key = f"{parent_key}{sep}{k}" if parent_key else k
            if isinstance(v, dict):
                items.extend(self._flatten_dict(v, new_key, sep=sep).items())
            elif isinstance(v, list):
                # No aplanamos listas
                pass
            else:
                items.append((new_key, v))
        return dict(items)
    
    def _resolve_string(self, value: str, vars_dict: dict, max_iterations: int = 10) -> str:
        """Resolve variables in a string iteratively."""
        for _ in range(max_iterations):
            try:
                new_value = value.format(**vars_dict)
                if new_value == value:  # No más cambios
                    break
                value = new_value
            except (KeyError, ValueError):
                break
        return value
    
    def _resolve_variables(self):
        """Resolve variables in the configuration recursively."""
        # Crear un diccionario plano con todas las variables disponibles
        self._build_custom_vars()
        flat_vars = self._flatten_dict(self.config)
        
        # Agregar variables de package y OS sin prefijo para facilitar su uso
        if 'package' in self.config and isinstance(self.config['package'], dict):
            flat_vars.update(self.config['package'])
        if self.current_os in self.config and isinstance(self.config[self.current_os], dict):
            flat_vars.update(self.config[self.current_os])

        print("Flat vars")
        print(flat_vars)
        
        # Resolver variables en el diccionario plano iterativamente
        for _ in range(10):  # Máximo 10 pasadas
            changed = False
            for key, value in flat_vars.items():
                if isinstance(value, str):
                    new_value = self._resolve_string(value, flat_vars, max_iterations=1)
                    if new_value != value:
                        flat_vars[key] = new_value
                        changed = True
            if not changed:
                break
        
        print("POST")
        print(flat_vars)
        # Aplicar las variables resueltas al diccionario original
        self.config = self._apply_resolved_vars(self.config, flat_vars)
    
    def _apply_resolved_vars(self, data: Any, vars_dict: dict) -> Any:
        """Apply resolved variables to the nested structure."""
        if isinstance(data, str):
            return self._resolve_string(data, vars_dict, max_iterations=1)
        elif isinstance(data, dict):
            return {k: self._apply_resolved_vars(v, vars_dict) for k, v in data.items()}
        elif isinstance(data, list):
            return [self._apply_resolved_vars(item, vars_dict) for item in data]
        else:
            return data
    
    def _load(self):
        """Load formula from TOML file."""
        with open(self.filepath, 'rb') as f:
            self.config = tomllib.load(f)

    def _build_custom_vars(self):
        """Build custom variables for the formula."""
        package_name = self.config.get('package', {}).get('name') or self.config.get('package', {}).get('basename')

        arch = config.get("RUNTIME", {}).get("arch", platform.machine())
        
        self.config.update({
            'package_name': package_name,
            'arch': arch,
        })
        for _var in self.custom_variables:
            if _var not in self.config:
                self.config[_var] = self.get(_var)

    
    def get(self, key: str, default: Any = None, os_name: str = None) -> Any:
        """Get configuration value."""
        os_name = os_name or self.current_os
        if os_name in self.config and key in self.config[os_name]:
            return self.config[os_name].get(key)
        return self.config.get(key, default)
    
    def __getitem__(self, key: str) -> Any:
        """Get configuration value using bracket notation."""
        return self.config[key]
    
    def __contains__(self, key: str) -> bool:
        """Check if key exists in configuration."""
        return key in self.config


def load_all_formulas(formulas_dir: Path = None) -> List[Formula]:
    """Load all formula files from directory."""
    formulas = []
    
    # Load TOML formulas
    formulas_dir = formulas_dir or config.FORMULAS_DIR

    for formula_file in formulas_dir.glob("*.toml"):
        formulas.append(Formula(formula_file))
    
    return formulas
