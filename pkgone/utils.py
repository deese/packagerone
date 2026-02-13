"""Utility functions for package building."""

import os
import re
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, List, Tuple, Union
import requests

from . import config


def read_env(filepath: Path = None) -> Dict[str, str]:
    """Read environment variables from .env file."""
    if filepath is None:
        filepath = config.SCRIPT_DIR / ".env"
    
    if not filepath.exists():
        raise FileNotFoundError(f"Missing {filepath}")
    
    env_vars = {}
    logme(f"Reading {filepath}")
    
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip().replace('\r', '')
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                env_vars[key.strip()] = value.strip()
                os.environ[key.strip()] = value.strip()
    
    return env_vars


def get_latest_ver(repo: str, with_date: bool = False) -> Optional[Union[str, Tuple[str, str]]]:
    """Get latest GitHub release version for a repository."""
    headers = {}
    github_token = os.environ.get('GITHUB_TOKEN')
    
    if github_token:
        headers['Authorization'] = f'Bearer {github_token}'
        headers['Accept'] = 'application/vnd.github+json'
    
    try:
        response = requests.get(
            f'https://api.github.com/repos/{repo}/releases/latest',
            headers=headers,
            timeout=30
        )
        
        if response.status_code == 200:
            data = response.json()
            tag_name = data.get('tag_name', '')
            
            if with_date:
                published_at = data.get('published_at', '')
                return tag_name, published_at
            return tag_name
        elif 'rate limit exceeded' in response.text.lower():
            logme("Github API exceeded. Try later.")
            return None
        else:
            logme(f"Error fetching version for {repo}: {response.status_code}")
            return None
            
    except Exception as e:
        logme(f"Error fetching version for {repo}: {e}")
        return None


def date_diff(target_date: str) -> int:
    """Calculate days difference between now and target date."""
    now_ts = datetime.now().timestamp()
    target_ts = datetime.fromisoformat(target_date.replace('Z', '+00:00')).timestamp()
    diff_sec = target_ts - now_ts
    diff_days = int(diff_sec / 86400 * -1)
    return diff_days


def get_stored_version(repo: str) -> Optional[str]:
    """Get stored version from database file."""
    if not config.DB_FILE.exists():
        return None
    
    try:
        with open(config.DB_FILE, 'r') as f:
            for line in f:
                if line.startswith(f"{repo}="):
                    return line.split('=', 1)[1].strip()
    except Exception:
        pass
    
    return None


def set_stored_version(repo: str, version: str):
    """Store version in database file."""
    lines = []
    found = False
    
    if config.DB_FILE.exists():
        with open(config.DB_FILE, 'r') as f:
            lines = f.readlines()
    
    with open(config.DB_FILE, 'w') as f:
        for line in lines:
            if line.startswith(f"{repo}="):
                f.write(f"{repo}={version}\n")
                found = True
            else:
                f.write(line)
        
        if not found:
            f.write(f"{repo}={version}\n")


def var_substitution(text: str, variables: Dict[str, str], max_loops: int = 5) -> str:
    """Substitute variables in text (handles $VAR and ${VAR} formats)."""
    result = text
    count = 0
    
    while ('$' in result) and count < max_loops:
        for var, val in variables.items():
            result = result.replace(f'${var}', str(val))
            result = result.replace(f'${{{var}}}', str(val))
        count += 1
    
    return result


def ts() -> str:
    """Get formatted timestamp."""
    return datetime.now().strftime("[%Y-%m-%d %H:%M:%S]")


def logme(msg: str, verbose_only: bool = False, no_eol: bool = False, eol: str = "\n"):
    """Log message to file and/or stdout."""
    if config.RUNLOG:
        with open(config.RUNLOG, 'a') as f:
            f.write(f"{ts()} {msg}\n")
    
    if verbose_only:
        if config.VERBOSE:
            print(msg, end=eol if not no_eol else "")
    else:
        print(msg, end=eol if not no_eol else "")


def pad(text: str, width: int) -> str:
    """Pad text to specified width."""
    if width < 0:
        return text.ljust(abs(width))
    return text.rjust(width)


def max_strlen(items: List[str]) -> int:
    """Get maximum string length from list."""
    return max(len(str(item)) for item in items) if items else 0


def download_file(url: str, dest: Path) -> bool:
    """Download file from URL to destination."""
    try:
        logme(f"Downloading: {url}", verbose_only=True)
        response = requests.get(url, timeout=60, stream=True)
        response.raise_for_status()
        
        with open(dest, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        return True
    except Exception as e:
        logme(f"Download failed: {e}")
        return False
