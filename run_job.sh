#!/bin/bash

# ====== CONFIG ======
PROJECT_DIR="$(pwd)/my_project"
VENV_DIR="$(pwd)/venv"

echo "Project directory: $PROJECT_DIR"
echo "Virtualenv directory: $VENV_DIR"

# ====== Create venv if it does not exist ======
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

# ====== Activate venv ======
echo "Activating virtual environment..."
source "$VENV_DIR/bin/activate"

# ====== Install requirements ======
if [ -f "$PROJECT_DIR/requirements.txt" ]; then
    echo "Installing requirements..."
    pip install -r "$PROJECT_DIR/requirements.txt"
fi

# ====== Run your Python job ======
echo "Running Python job..."
python "$PROJECT_DIR/main.py"

# ====== Deactivate ======
deactivate
echo "Done."
