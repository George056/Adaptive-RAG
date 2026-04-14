#!/usr/bin/env bash

set -euo pipefail

echo "=== Adaptive-RAG Setup Script ==="

# --------------------------- Detect OS --------------------------- 
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="mac"
    echo "Detected macOS"
elif [[ -f /etc/os-release ]]; then
    OS="linux"
    source /etc/os-release
    echo "Detected Linux: $NAME $VERSION_ID"
else
    echo "Unsupported OS. Exiting."
    exit 1
fi

# --------------------------- Install System Dependencies ---------------------------
echo "Installing system dependencies..."

if [[ "$OS" == "mac" ]]; then
    if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew not found. Installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install wget curl git python@3.8
    # Elasticsearch will be run via Docker on Mac
else
    # Linux
    if [[ -n "${ID_LIKE:-}" && "$ID_LIKE" == *"debian"* ]] || [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
        sudo apt-get update
        sudo apt-get install -y wget curl git python3.8 python3.8-venv python3-pip build-essential
    elif [[ "$ID" == "fedora" || "$ID_LIKE" == *"fedora"* ]]; then
        sudo dnf install -y wget curl git python38 python38-devel gcc gcc-c++ make
    elif [[ "$ID" == "arch" || "$ID_LIKE" == *"arch"* ]]; then
        sudo pacman -Syu --noconfirm wget curl git python python-pip base-devel
    else
        echo "Unsupported Linux distro. Please install wget, curl, git, python3.8 manually."
        exit 1
    fi
fi

# --------------------------- Conda Environment ---------------------------
echo "Setting up conda environment..."

if ! command -v conda >/dev/null 2>&1; then
    echo "Conda not found. Installing Miniconda..."
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    bash miniconda.sh -b -p "$HOME/miniconda"
    rm miniconda.sh
    export PATH="$HOME/miniconda/bin:$PATH"
    conda init
fi

conda create -n adaptiverag python=3.8 -y
conda activate adaptiverag

# --------------------------- Python Dependencies ---------------------------
echo "Installing Python packages..."

pip install --upgrade pip
pip install -r requirements.txt

# Critical fixes for this repo on Python 3.8
pip install "pydantic==1.9.2" --force-reinstall
pip install bitsandbytes --force-reinstall
pip install "typing_extensions==4.5.0" --force-reinstall

# --------------------------- NLTK & spaCy Data ---------------------------
echo "Downloading NLTK and spaCy data..."
python -c "
import nltk
nltk.download('stopwords', quiet=True)
nltk.download('punkt', quiet=True)
nltk.download('punkt_tab', quiet=True)
print('NLTK data downloaded')
"
python -m spacy download en_core_web_sm

# --------------------------- Final Message ---------------------------
echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Next steps:"
echo "1. Start Elasticsearch (native or Docker):"
echo "   - Linux:   ./elasticsearch-7.10.2/bin/elasticsearch"
echo "   - Mac:     docker run -d --name elasticsearch -p 9200:9200 -e 'discovery.type=single-node' -e 'xpack.security.enabled=false' docker.elastic.co/elasticsearch/elasticsearch:7.10.2"
echo ""
echo "2. Start retriever server (new terminal):"
echo "   uvicorn serve:app --port 8000 --app-dir retriever_server"
echo ""
echo "3. Start LLM server with flan-t5-large (new terminal):"
echo "   MODEL_NAME=flan-t5-large uvicorn serve:app --port 8010 --app-dir llm_server"
echo ""
echo "4. Run a fast baseline (example):"
echo "   python run.py write oner_large --instantiation_scheme oner_qa --prompt_set 1 --set_name dev_None --llm_port_num 8010 --no_diff"
echo "   python run.py predict oner_large --instantiation_scheme oner_qa --prompt_set 1 --set_name dev_200 --llm_port_num 8010 --evaluation_path processed_data/2wikimultihopqa/dev_500_subsampled.jsonl --skip_if_exists"
echo ""
echo "You can now safely run experiments with flan-t5-large (much faster and lower memory)."

conda deactivate
