"""Version checking functionality."""

from pathlib import Path
from datetime import datetime

from . import config
from .formula import Formula, load_all_formulas
from .utils import get_latest_ver, get_stored_version, date_diff, logme


def check_version(repo: str) -> None:
    """Check and display version information for a repository."""
    result = get_latest_ver(repo, with_date=True)
    
    if not result:
        logme(f"Version not found for {repo}")
        return
    
    ver, reldate = result
    current_version = get_stored_version(repo)
    
    if ver:
        day_diff = date_diff(reldate)
        date_fmt = datetime.fromisoformat(reldate.replace('Z', '+00:00')).strftime('%Y-%m-%d')
        
        if current_version:
            if current_version == ver:
                status = "(unchanged)"
            else:
                status = f"(updated from {current_version})"
        else:
            status = "(not previously stored)"
        
        print(f"{repo:25s} {ver:>10s} - {date_fmt:>10s} {day_diff:>5d} day(s) ago {status}")
    else:
        logme(f"Version not found for {repo}")


def check_all_versions() -> None:
    """Check versions for all formulas."""
    print("Checking versions...")
    
    # Load all formulas
    formulas_dir = config.SCRIPT_DIR / "formulas"
    formulas = load_all_formulas(formulas_dir)
    
    for formula in formulas:
        repo = formula.get('REPO')
        if repo:
            check_version(repo)
