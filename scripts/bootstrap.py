import subprocess
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
VENV_DIR = PROJECT_ROOT / ".venv"
REQUIREMENTS_FILE = PROJECT_ROOT / "requirements.txt"


# Finding the virtual environment Python path
def get_venv_python_path():
    unix_python = VENV_DIR / "bin" / "python"
    windows_python = VENV_DIR / "Scripts" / "python.exe"
    return unix_python if unix_python.exists() else windows_python


# Creating the virtual environment if missing
def create_virtual_environment():
    if VENV_DIR.exists():
        print("Virtual environment already exists.")
        return

    print("Creating virtual environment :")
    subprocess.run([sys.executable, "-m", "venv", str(VENV_DIR)], check = True)


# Installing required Python packages
def install_dependencies():
    if not REQUIREMENTS_FILE.exists():
        raise FileNotFoundError(f"Requirements file not found : {REQUIREMENTS_FILE}")

    python_executable = get_venv_python_path()
    if not python_executable.exists():
        raise FileNotFoundError("Virtual environment Python executable not found.")

    print("Upgrading pip :")
    subprocess.run([str(python_executable), "-m", "pip", "install", "--upgrade", "pip"], check = True)

    print("Installing dependencies :")
    subprocess.run([str(python_executable), "-m", "pip", "install", "-r", str(REQUIREMENTS_FILE)], check = True)


def main():
    print(f"Project root : {PROJECT_ROOT}")
    create_virtual_environment()
    install_dependencies()
    print("Environment bootstrap completed successfully.")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"Bootstrap failed : {exc}")
        sys.exit(1)