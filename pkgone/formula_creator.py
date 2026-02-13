"""Formula creator using AI to generate package formulas."""

import os
import re
import sys
import json
import tempfile
import subprocess
from pathlib import Path
from typing import Optional, List
import requests

from . import config
from .utils import logme


class FormulaCreator:
    """Creates package formulas using AI assistance."""
    
    def __init__(self):
        self.tmpfolder = Path(tempfile.mkdtemp(prefix="pkgone-"))
        self.latest_file = self.tmpfolder / "latest.json"
        self.download_links = self.tmpfolder / "links.txt"
        self.output_gpt = Path("output_gpt.log")
        self.wget = "wget -q"
    
    def __del__(self):
        """Cleanup temporary files if requested."""
        pass
    
    def normalize_github_repo(self, input_str: str) -> str:
        """Normalize GitHub repository input to owner/repo format.
        
        Args:
            input_str: GitHub URL or owner/repo string
            
        Returns:
            Normalized owner/repo string
        """
        # If it's already in owner/repo format, return as-is
        if re.match(r'^[^/]+/[^/]+$', input_str):
            return input_str
        
        # Extract owner/repo from various GitHub URL formats
        match = re.search(r'github\.com/([^/]+/[^/]+)', input_str)
        if match:
            repo_part = match.group(1)
            # Remove any trailing path components
            repo_part = '/'.join(repo_part.split('/')[:2])
            return repo_part
        
        # If we can't parse it, return the original input
        return input_str
    
    def query_ai(self, prompt: str) -> Optional[dict]:
        """Query AI using OpenRouter API.
        
        Args:
            prompt: The prompt to send to the AI
            
        Returns:
            API response as dict or None on error
        """
        api_key = os.environ.get('OPENROUTER_API_KEY')
        
        if not api_key:
            print("Set the $OPENROUTER_API_KEY in order to use the LLM query.")
            return None
        
        payload = {
            'model': 'openai/gpt-4o-mini',
            'prompt': prompt
        }
        
        try:
            response = requests.post(
                'https://openrouter.ai/api/v1/completions',
                headers={
                    'Authorization': f'Bearer {api_key}',
                    'Content-Type': 'application/json'
                },
                json=payload,
                timeout=60
            )
            
            result = response.json()
            
            # Log to file
            with open(self.output_gpt, 'a') as f:
                f.write(f"PROMPT: {json.dumps(payload)}\n")
                f.write(f"RESPONSE: {json.dumps(result)}\n\n")
            
            return result
            
        except Exception as e:
            print(f"Error querying AI: {e}")
            return None
    
    def download_latest_gh(self, repo: str) -> bool:
        """Download latest release info from GitHub.
        
        Args:
            repo: Repository in owner/repo format
            
        Returns:
            True if successful
        """
        print(f"Downloading latest from: {repo}", file=sys.stderr)
        
        if self.latest_file.exists():
            print("Data already exists.", file=sys.stderr)
            return True
        
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
                with open(self.latest_file, 'w') as f:
                    json.dump(response.json(), f)
                return True
            else:
                print(f"Error downloading release info: {response.status_code}")
                return False
                
        except Exception as e:
            print(f"Error: {e}")
            return False
    
    def get_download_links(self) -> List[str]:
        """Extract download links from latest release.
        
        Returns:
            List of download URLs
        """
        print("Retrieving links", file=sys.stderr)
        
        with open(self.latest_file, 'r') as f:
            data = json.load(f)
        
        links = []
        
        # Look for linux x86_64 or amd64 assets
        for asset in data.get('assets', []):
            name = asset.get('name', '').lower()
            
            if ('linux' in name and 'x86_64' in name) or \
               ('linux' in name and 'amd64' in name):
                links.append(asset.get('browser_download_url'))
        
        # If no specific matches, try any linux asset
        if not links:
            for asset in data.get('assets', []):
                name = asset.get('name', '').lower()
                if 'linux' in name:
                    links.append(asset.get('browser_download_url'))
        
        return links
    
    def get_repo_data(self, repo: str) -> Optional[str]:
        """Get repository data and determine best download link.
        
        Args:
            repo: Repository in owner/repo format
            
        Returns:
            Best download link or None
        """
        print("Get Repo Data", file=sys.stderr)
        
        if not self.download_latest_gh(repo):
            return None
        
        links = self.get_download_links()
        
        if not links:
            print("No download links found", file=sys.stderr)
            return None
        
        if len(links) == 1:
            print("Only one link found.", file=sys.stderr)
            return links[0]
        
        # Ask AI to choose best link
        prompt_links = '\n'.join(links)
        prompt = (
            f"Given the following links and giving priority to tar.gz and similar, "
            f"and GNU over musl. To be run on an x64 machine. What will be best match? "
            f"return only the link. {prompt_links}"
        )
        
        result = self.query_ai(prompt)
        if result and 'choices' in result and len(result['choices']) > 0:
            return result['choices'][0].get('text', '').strip()
        
        # Fallback to first link
        return links[0]
    
    def get_file_listing(self, download_link: str) -> str:
        """Download file and get listing of contents.
        
        Args:
            download_link: URL to download
            
        Returns:
            File listing as string
        """
        filename = Path(download_link).name
        filepath = self.tmpfolder / filename
        
        if not filepath.exists():
            print(f"Downloading {download_link}...", file=sys.stderr)
            try:
                response = requests.get(download_link, timeout=60, stream=True)
                response.raise_for_status()
                
                with open(filepath, 'wb') as f:
                    for chunk in response.iter_content(chunk_size=8192):
                        f.write(chunk)
            except Exception as e:
                print(f"Error downloading file: {e}", file=sys.stderr)
                return ""
        
        if not filepath.exists():
            print("Error downloading file", file=sys.stderr)
            return ""
        
        # Get file listing based on file type
        if any(filepath.name.endswith(ext) for ext in ['.tar', '.tar.gz', '.tar.bz2', '.tar.xz', '.tgz', '.tbz', '.txz']):
            try:
                result = subprocess.run(
                    ['tar', 'tvf', str(filepath)],
                    capture_output=True,
                    text=True,
                    check=True
                )
                return result.stdout
            except subprocess.CalledProcessError:
                return ""
        
        return ""
    
    def load_prompt_template(self) -> str:
        """Load the ChatGPT prompt template."""
        template_path = config.SCRIPT_DIR / "scripts" / "creator" / "chatgpt.prompt"
        
        if template_path.exists():
            with open(template_path, 'r') as f:
                return f.read()
        
        # Return embedded template if file doesn't exist
        return self._get_default_prompt_template()
    
    def _get_default_prompt_template(self) -> str:
        """Get default prompt template."""
        return """I have a tool that generates packages based on template files. I want you to help me to creating new templates.

### START OF EXAMPLE 1 ###
Download url:
https://github.com/eza-community/eza/releases/download/v0.21.4/eza_x86_64-unknown-linux-gnu.tar.gz

File listing:
$ tar tvf eza_x86_64-unknown-linux-gnu.tar.gz
-rwxr-xr-x ces/users   2282480 2025-05-30 16:04 ./eza

Output Template:
# -*- mode: sh -*-
REPO="eza-community/eza"
DPKG_BASENAME="eza"
DOWNLOAD_FILENAME="eza_\\$TARGET_ARCH-unknown-linux-gnu.tar.gz"
DOWNLOAD_URL_TEMPLATE="https://github.com/\\$REPO/releases/download/\\$LATEST_VER/\\$DOWNLOAD_FILENAME"
EXTRACT_CMD="tar zxf"
INSTALL_FILES=(
    "eza|755|/usr/bin/eza"
)
CLEANUP_FILES="eza"
PACKAGE_DESCRIPTION="eza is a modern alternative for the venerable file-listing command-line program ls"
PACKAGE_SUMMARY="eza is a modern alternative for ls"
PACKAGE_LICENSE="MIT"
### END OF EXAMPLE 1 ###

Given the examples above, can you create the output template for the package with the following criteria:

Download url:
$DOWNLOAD_LINK

File listing:
$FILELIST

Add all files. Binary files should be in /usr/bin and the rest should be in /usr/share/packagename/. 
Return only the template without any comments. Give me the code only, without any Markdown formatting or triple backticks.
"""
    
    def var_substitution(self, text: str, download_link: str, filelist: str) -> str:
        """Substitute variables in template."""
        result = text.replace('$DOWNLOAD_LINK', download_link)
        result = result.replace('$FILELIST', filelist)
        return result
    
    def create_formula(self, repo_input: str, force: bool = False) -> bool:
        """Create a formula for the given repository.
        
        Args:
            repo_input: GitHub repository URL or owner/repo
            force: Force creation even if formula exists
            
        Returns:
            True if successful
        """
        # Normalize repo
        repo = self.normalize_github_repo(repo_input)
        package_name = repo.split('/')[-1]
        formula_file = config.SCRIPT_DIR / "formulas" / f"{package_name}-pkg.formula"
        
        if formula_file.exists() and not force:
            print(f"Formula already exists: {formula_file}")
            return False
        elif formula_file.exists():
            print("Force is on. Continuing")
        
        # Get download link
        download_link = self.get_repo_data(repo)
        if not download_link or 'https://github.com' not in download_link:
            print(f"Invalid download link: {download_link}")
            return False
        
        print(f"Download link: {download_link}")
        
        # Get file listing
        filelist = self.get_file_listing(download_link)
        if not filelist:
            print("Empty file listing. Please review")
            return False
        
        # Load and prepare prompt
        template = self.load_prompt_template()
        prompt = self.var_substitution(template, download_link, filelist)
        
        # Query AI
        data = self.query_ai(prompt)
        if not data or 'choices' not in data or not data['choices']:
            print("Failed to get AI response")
            return False
        
        formula = data['choices'][0].get('text', '').strip()
        
        # Display results
        print("\nFile listing")
        print("=" * 40)
        print(filelist)
        print("=" * 40)
        
        print("\nGenerated formula:")
        print("=" * 40)
        print(formula)
        print("=" * 40)
        
        # Ask user to save
        answer = input(f"\nDo you want to save this formula to {formula_file}? [y/N]: ")
        
        if answer.lower() in ['y', 'yes']:
            formula_file.parent.mkdir(exist_ok=True)
            with open(formula_file, 'w') as f:
                f.write(formula)
            print(f"Formula saved to: {formula_file}")
        else:
            print("Formula not saved.")
        
        # Ask about cleanup
        answer = input("\nDo you want to clean the temporary files? [y/N]: ")
        if answer.lower() in ['y', 'yes']:
            print("Deleting files...")
            import shutil
            shutil.rmtree(self.tmpfolder, ignore_errors=True)
            if self.output_gpt.exists():
                self.output_gpt.unlink()
        else:
            print("Files not deleted.")
        
        return True


def create_formula_cli(repo: str, force: bool = False) -> int:
    """CLI entry point for formula creation.
    
    Args:
        repo: Repository to create formula for
        force: Force creation
        
    Returns:
        Exit code
    """
    import sys
    
    creator = FormulaCreator()
    success = creator.create_formula(repo, force)
    return 0 if success else 1
