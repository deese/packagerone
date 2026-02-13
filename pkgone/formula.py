"""Formula loading and parsing."""

import re
import sys
from pathlib import Path
from typing import Dict, List, Any

if sys.version_info >= (3, 11):
    import tomllib
else:
    try:
        import tomli as tomllib
    except ImportError:
        raise ImportError("Python < 3.11 requires 'tomli' package. Install with: pip install tomli")


class Formula:
    """Represents a package formula configuration."""
    
    def __init__(self, filepath: Path):
        self.filepath = filepath
        self.config: Dict[str, Any] = {}
        self._load()
    
    def _load(self):
        """Load formula from TOML or shell script file."""
        if self.filepath.suffix == '.toml':
            self._load_toml()
        else:
            self._load_shell()
    
    def _load_toml(self):
        """Load formula from TOML file."""
        with open(self.filepath, 'rb') as f:
            self.config = tomllib.load(f)
    
    def _load_shell(self):
        """Load formula from shell script file."""
        with open(self.filepath, 'r') as f:
            content = f.read()
        
        # Parse simple variable assignments
        for line in content.split('\n'):
            line = line.strip()
            
            # Skip comments and empty lines
            if not line or line.startswith('#'):
                continue
            
            # Parse variable=value
            if '=' in line and not line.startswith('('):
                key, value = line.split('=', 1)
                key = key.strip()
                value = value.strip()
                
                # Handle arrays
                if value.startswith('('):
                    array_content = value
                    # Find closing parenthesis (might be multiline)
                    if ')' not in value:
                        in_array = True
                        for next_line in content.split('\n')[content.split('\n').index(line)+1:]:
                            array_content += '\n' + next_line
                            if ')' in next_line:
                                break
                    
                    # Parse array elements
                    array_str = array_content.strip('()')
                    elements = []
                    for item in re.findall(r'"([^"]*)"', array_str):
                        elements.append(item)
                    self.config[key] = elements
                else:
                    # Remove quotes
                    value = value.strip('"').strip("'")
                    self.config[key] = value
    
    def get(self, key: str, default: Any = None) -> Any:
        """Get configuration value."""
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
    
    # Load legacy shell formulas
    for formula_file in formulas_dir.glob("*.formula"):
        # Skip legacy files
        if formula_file.name in ['neovim-pkg.formula']:
            continue
        formulas.append(Formula(formula_file))
    
    return formulas
