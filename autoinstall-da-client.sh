#!/bin/bash

# Function to display the menu
show_menu() {
    curl -s https://raw.githubusercontent.com/dwisyafriadi2/logo/main/logo.sh | bash
    echo "=============================="
    echo " 0G DA Client Management Menu "
    echo "=============================="
    echo "1. Install Dependencies"
    echo "2. Install 0G DA Client"
    echo "3. Configure DA Client"
    echo "4. Start DA Client"
    echo "5. Stop DA Client"
    echo "6. Check DA Client Status"
    echo "7. Check DA Client Logs"
    echo "8. Uninstall 0G DA Client"
    echo "9. Exit"
    echo "=============================="
}

install_dependencies() {
    echo "Installing dependencies..."
    sudo apt-get update && sudo apt-get install -y cmake git jq
    echo "Dependencies installed."
}

install_go() {
    if command -v go &>/dev/null; then
        echo "Go is already installed. Skipping installation."
    else
        echo "Installing Go 1.22.0..."
        cd $HOME
        ver="1.22.0"
        wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
        rm "go$ver.linux-amd64.tar.gz"
        if ! grep -q '/usr/local/go/bin' "$HOME/.bashrc"; then
            echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> "$HOME/.bashrc"
        fi
        source "$HOME/.bashrc"
        go version
        echo "Go installation completed."
    fi
}

install_da_client() {
    echo "Installing 0G DA Client..."
    install_dependencies
    install_go
    cd $HOME
    git clone -b v1.0.0-testnet https://github.com/0glabs/0g-da-client.git
    cd 0g-da-client
    git stash
    git fetch --all --tags
    git checkout f8db250
    git submodule update --init
    echo "0G DA Client installed."
}

configure_da_client() {
    echo "Configuring 0G DA Client..."

    # Prompt user for details
    read -p "Enter your RPC URL (e.g., https://evmrpc-testnet.0g.ai): " rpc_url
    read -p "Enter your Ethereum private key: " eth_private_key
    read -p "Enter your DA Node IP: " da_node_ip

    makefile_path="$HOME/0g-da-client/disperser/Makefile"

    # Backup the existing Makefile
    if [ -f "$makefile_path" ]; then
        cp "$makefile_path" "$makefile_path.bak"
        echo "Backup of Makefile created: Makefile.bak"
    else
        echo "Error: Makefile not found! Exiting."
        return 1
    fi

    # Update Makefile with user inputs
    cat <<EOF > "$makefile_path"
run_combined: build_combined
	./bin/combined \\
	--chain.rpc $rpc_url \\
	--chain.private-key $eth_private_key \\
	--chain.receipt-wait-rounds 180 \\
	--chain.receipt-wait-interval 1s \\
	--chain.gas-limit 2000000 \\
	--combined-server.use-memory-db \\
	--combined-server.storage.kv-db-path /runtime/ \\
	--combined-server.storage.time-to-expire 2592000 \\
	--disperser-server.grpc-port 51001 \\
	--batcher.da-entrance-contract 0x857C0A28A8634614BB2C96039Cf4a20AFF709Aa9 \\
	--batcher.da-signers-contract 0x0000000000000000000000000000000000001000 \\
	--batcher.finalizer-interval 20s \\
	--batcher.confirmer-num 3 \\
	--batcher.max-num-retries-for-sign 3 \\
	--batcher.finalized-block-count 50 \\
	--batcher.batch-size-limit 500 \\
	--batcher.encoding-interval 3s \\
	--batcher.encoding-request-queue-size 1 \\
	--batcher.pull-interval 10s \\
	--batcher.signing-interval 3s \\
	--batcher.signed-pull-interval 20s \\
	--batcher.expiration-poll-interval 3600 \\
	--encoder-socket $da_node_ip:34000 \\
	--encoding-timeout 600s \\
	--signing-timeout 600s \\
	--chain-read-timeout 12s \\
	--chain-write-timeout 13s \\
	--combined-server.log.level-file trace \\
	--combined-server.log.level-std trace \\
	--combined-server.log.path ./../run/run.log
EOF

    echo "Makefile updated successfully!"

    # Create systemd service
    sudo tee /etc/systemd/system/0gdacli.service > /dev/null <<EOF
[Unit]
Description=0G DA Client
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/0g-da-client/disperser
ExecStart=/usr/bin/make run_combined
Restart=always
RestartSec=10
LimitNOFILE=65535
Environment="PATH=/usr/local/go/bin:/usr/bin:/bin"

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable 0gdacli
    echo "0G DA Client systemd service created and enabled."
}


start_da_client() {
    echo "Starting 0G DA Client..."
    sudo systemctl start 0gdacli
    echo "DA Client started."
}

stop_da_client() {
    echo "Stopping 0G DA Client..."
    sudo systemctl stop 0gdacli
    echo "DA Client stopped."
}

check_da_client_status() {
    echo "Checking 0G DA Client status..."
    sudo systemctl status 0gdacli
}

check_da_client_logs() {
    echo "Checking 0G DA Client logs..."
    sudo journalctl -u 0gdacli -f -o cat
}

uninstall_da_client() {
    echo "Uninstalling 0G DA Client..."
    sudo systemctl stop 0gdacli
    sudo systemctl disable 0gdacli
    sudo rm /etc/systemd/system/0gdacli.service
    sudo systemctl daemon-reload
    rm -rf $HOME/0g-da-client
    echo "0G DA Client successfully uninstalled."
}

while true; do
    show_menu
    read -p "Please enter your choice: " choice
    case $choice in
        1) install_dependencies ;;
        2) install_da_client ;;
        3) configure_da_client ;;
        4) start_da_client ;;
        5) stop_da_client ;;
        6) check_da_client_status ;;
        7) check_da_client_logs ;;
        8) uninstall_da_client ;;
        9) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid option. Please try again." ;;
    esac
    read -p "Press Enter to continue..." </dev/tty
done
