#!/usr/bin/env python3
"""Formula Creator - Create package formulas using AI."""

import sys
import argparse
from pathlib import Path

# Add project root to path (two levels up from scripts/creator)
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from pkgone.formula_creator import create_formula_cli
from pkgone.utils import read_env
from pkgone import config


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Create package formulas using AI',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument('repository',
                        help='GitHub repository (owner/repo or full URL)')
    parser.add_argument('-f', '--force', action='store_true',
                        help='Force creation even if formula exists')
    
    args = parser.parse_args()
    
    # Load environment
    env_file = config.SCRIPT_DIR / ".env"
    if env_file.exists():
        read_env(env_file)
    
    return create_formula_cli(args.repository, force=args.force)


if __name__ == '__main__':
    sys.exit(main())
