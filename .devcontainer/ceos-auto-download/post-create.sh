#!/bin/bash
set -e

# --- Environment Setup ---
VENV_PATH="$HOME/.venv"
SHELL_CONFIG_FILE="$HOME/.bashrc"
DOWNLOAD_COMMAND="download-ceos"

# --- Color Codes for Highlighting ---
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color

# --- Helper Functions ---
print_message() {
    echo " "
    echo -e "--- ${CYAN}$1${NC} ---"
    echo " "
}

install_system_dependencies() {
    print_message "Updating apt and installing system dependencies"
    sudo apt-get update
    echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections
    sudo apt-get install -y --no-install-recommends \
        git gnupg lsb-release curl unzip iproute2 iputils-ping \
        software-properties-common jq tshark xz-utils
}

setup_python_environment() {
    print_message "Creating Python virtual environment at $VENV_PATH"
    python3 -m venv "$VENV_PATH"
    
    print_message "Installing Python requirements"
    # shellcheck source=/dev/null
    source "$VENV_PATH/bin/activate"
    pip install --upgrade pip
    pip install -r .devcontainer/ceos-auto-download/requirements.txt
    deactivate
}

install_ansible_collection() {
    print_message "Installing Arista AVD collection"
    # shellcheck source=/dev/null
    source "$VENV_PATH/bin/activate"
    ansible-galaxy collection install arista.avd
    deactivate
}

install_containerlab() {
    print_message "Installing Containerlab"
    bash -c "$(curl -sL https://get.containerlab.dev)"
}

deploy_edgeshark() {
    print_message "Deploying Edgeshark"
    curl -sL https://github.com/siemens/edgeshark/raw/main/deployments/wget/docker-compose.yaml \
    | DOCKER_DEFAULT_PLATFORM= docker compose -f - up -d
}

# --- This function runs ONLY if a token is provided ---
automated_ceos_download() {
    print_message "ARISTA_TOKEN found, starting automated download"
    # shellcheck source=/dev/null
    source "$VENV_PATH/bin/activate"
    
    arch=$(uname -m)
    if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
        image_format="cEOSarm"
        file_pattern="cEOSarm-lab-*.tar.xz"
    else
        image_format="cEOS"
        file_pattern="cEOS-lab-*.tar.xz"
    fi

    ardl --token "$ARISTA_TOKEN" get eos --format "$image_format" --latest

    image_tar_xz=$(ls $file_pattern 2>/dev/null | head -n 1)

    if [[ -n "$image_tar_xz" ]]; then
        unxz -k "$image_tar_xz"
        image_tar="${image_tar_xz%.xz}"
        echo -e "🐳 ${GREEN}Importing '$image_tar' as 'ceos:latest'...${NC}"
        docker import "$image_tar" ceos:latest
        echo ""
        echo -e "✅ ${GREEN}cEOS image imported successfully.${NC}"
        echo -e "   ${YELLOW}-------------------------------------------------------------------${NC}"
        echo -e "   ${YELLOW}🚨 IMPORTANT: Update your topology YAML to use the correct image:${NC}"
        echo -e "   ${YELLOW}   image: ceos:latest${NC}"
        echo -e "   ${YELLOW}-------------------------------------------------------------------${NC}"
        rm "$image_tar" "$image_tar_xz"
    else
        echo "⚠️ Download failed. No cEOS tarball found."
    fi
}

# --- This function runs ONLY if the token is MISSING ---
create_manual_download_script() {
    print_message "ARISTA_TOKEN not set. Creating the manual '$DOWNLOAD_COMMAND' command"

    sudo bash -c "cat > /usr/local/bin/$DOWNLOAD_COMMAND" << EOF
#!/bin/bash
set -e

# Color Codes
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
NC='\033[0m'

source "\$HOME/.venv/bin/activate"

read -sp "Please enter your Arista Token: " ARISTA_TOKEN
echo ""
if [[ -z "\$ARISTA_TOKEN" ]]; then echo "⚠️ No token provided. Exiting."; exit 1; fi

echo -e "✅ \${GREEN}Token received. Starting download...\${NC}"
arch=\$(uname -m)

if [[ "\$arch" == "aarch64" || "\$arch" == "arm64" ]]; then
    format="cEOSarm"
    pattern="cEOSarm-lab-*.tar.xz"
else
    format="cEOS"
    pattern="cEOS-lab-*.tar.xz"
fi

ardl --token "\$ARISTA_TOKEN" get eos --format "\$format" --latest

tar_file=\$(ls \$pattern 2>/dev/null | head -n 1)

if [[ -n "\$tar_file" ]]; then
    unxz -k "\$tar_file"
    tar_image="\${tar_file%.xz}"
    echo -e "🐳 \${GREEN}Importing '\$tar_image' as 'ceos:latest'...\${NC}"
    docker import "\$tar_image" ceos:latest
    echo ""
    echo -e "✅ \${GREEN}Image imported successfully.\${NC}"
    echo -e "   \${YELLOW}-------------------------------------------------------------------"
    echo -e "   🚨 IMPORTANT: Update your topology YAML to use the correct image:"
    echo -e "      image: ceos:latest"
    echo -e "   -------------------------------------------------------------------\${NC}"
    rm "\$tar_image" "\$tar_file"
else
    echo "⚠️ Download failed."
    exit 1
fi
EOF
    sudo chmod +x "/usr/local/bin/$DOWNLOAD_COMMAND"
}

configure_shell() {
    # Add venv activation to the shell profile
    if ! grep -q "source $VENV_PATH/bin/activate" "$SHELL_CONFIG_FILE"; then
        echo -e "\n# Activate Python virtual environment\nsource $VENV_PATH/bin/activate" >> "$SHELL_CONFIG_FILE"
    fi
}

# --- Main Execution ---
main() {
    install_system_dependencies
    setup_python_environment
    install_ansible_collection
    install_containerlab
    deploy_edgeshark
    configure_shell

    # --- Conditional Logic ---
    if [[ -n "$ARISTA_TOKEN" ]]; then
        automated_ceos_download
        print_message "Devcontainer setup complete! cEOS image downloaded."
    else
        create_manual_download_script
        print_message "Devcontainer setup complete! cEOS image was NOT downloaded."
        echo ""
        echo -e "${YELLOW}******************************************************************${NC}"
        echo -e "${YELLOW}*${NC} The ARISTA_TOKEN was empty in your devcontainer.json file.     ${YELLOW}*${NC}"
        echo -e "${YELLOW}*${NC} To download the cEOS image, run the following command:        ${YELLOW}*${NC}"
        echo -e "${YELLOW}*${NC}                                                                ${YELLOW}*${NC}"
        echo -e "${YELLOW}*${NC}   ${GREEN}$DOWNLOAD_COMMAND${NC}                                                 ${YELLOW}*${NC}"
        echo -e "${YELLOW}******************************************************************${NC}"
        echo ""
    fi
}

main