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
    
    def __init__(self, filepath: Path):
        self.filepath = filepath
        self.config: Dict[str, Any] = {}
        self._load()
        self._build_custom_vars()

    def set_os(self, os_name: str):
        """Set the current OS for conditional logic."""
        self.current_os = os_name
    
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


def load_all_formulas(formulas_dir: Path) -> List[Formula]:
    """Load all formula files from directory."""
    formulas = []
    
    # Load TOML formulas
    for formula_file in formulas_dir.glob("*.toml"):
        formulas.append(Formula(formula_file))
    
    return formulas
