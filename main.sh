#!/bin/bash

# Function to remove the server
remove_server() {
    local server_directory="$1"
    local service_name="${server_directory}_server"
    local install_directory="./$server_directory"
    local service_file="/etc/systemd/system/${service_name}.service"

    # Stop and disable the service
    sudo systemctl stop "$service_name" > /dev/null 2>&1
    sudo systemctl disable "$service_name" > /dev/null 2>&1

    # Remove the service file
    sudo rm -f "$service_file" > /dev/null 2>&1

    # Reload systemd
    sudo systemctl daemon-reload > /dev/null 2>&1

    # Remove the installation directory
    sudo rm -rf "$install_directory" > /dev/null 2>&1

    echo "Server '$server_directory' removed."

    # Get the port from the service file and release it
    local port=$(grep 'ExecStart=' "$service_file" | grep -oP '0\.0\.0\.0:\K\d+')
    if [ -n "$port" ]; then
        sudo ss -nlp | grep ":$port" | awk '{print $6}' | cut -d',' -f1 | xargs sudo kill -9 > /dev/null 2>&1
        echo "Port $port released."
    fi
}

# Check if PHP is installed
if ! command -v php > /dev/null 2>&1; then
    echo "PHP is not installed. Installing PHP..."
    sudo apt-get update
    sudo apt-get install php -y
fi

# Check the command argument
if [ "$1" == "remove" ]; then
    # Read the stored server directory name
    server_directory=$(cat server_directory.txt 2>/dev/null)
    if [ -n "$server_directory" ]; then
        read -p "Are you sure you want to delete the server '$server_directory'? (y/n): " confirm_remove
        if [ "$confirm_remove" == "y" ]; then
            remove_server "$server_directory"
            rm -- "server_directory.txt"
        else
            echo "Server removal aborted."
        fi
    else
        echo "Server directory information not found. You can manually specify the server directory to remove."
    fi
    exit
fi

# Prompt for the server directory name
read -p "Enter the name for the server directory: " server_directory
install_directory="/var/www/$server_directory"

# Check if the directory already exists
while [ -d "$install_directory" ]; do
    echo "Directory '$server_directory' already exists."
    read -p "Please enter a different name for the server directory: " server_directory
    install_directory="/var/www/$server_directory"
done

# Store the server directory name in a file
echo "$server_directory" > server_directory.txt

# Create the installation directory
sudo mkdir -p "$install_directory"
sudo chown -R www-data:www-data "$install_directory"
sudo chmod -R 777 "$install_directory"

# Create 'index.html' file with full permissions
html_code='
<!DOCTYPE html>
<html>
<title>Welcome</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="stylesheet" href="https://www.w3schools.com/w3css/4/w3.css">
<body>

<div class="w3-light-grey w3-padding-32 w3-center">
  <h1 class="w3-jumbo">PHP Server</h1>
</div>

<center><p>Welcome to your server! From now on you can edit the server files and see your code in action here.</p></center>

</body>
</html>
'
echo "$html_code" | sudo tee "$install_directory/index.html" > /dev/null

# Provide full permissions to the 'index.html' file
sudo chmod 777 "$install_directory/index.html"

# Prompt for the port
read -p "Enter the port number for the PHP server (default: 2024): " port
port=${port:-2024}

# Create systemd service unit file
service_file="/etc/systemd/system/${server_directory}_server.service"
echo "
[Unit]
Description=PHP Server for $server_directory
After=network.target

[Service]
ExecStart=/usr/bin/php -S 0.0.0.0:$port -t $install_directory
Restart=always
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=${server_directory}_server

[Install]
WantedBy=multi-user.target
" | sudo tee "$service_file" > /dev/null

# Reload systemd
sudo systemctl daemon-reload

# Start and enable the service
sudo systemctl start "${server_directory}_server"
sudo systemctl enable "${server_directory}_server"

echo "Installation completed. PHP server for '$server_directory' is running on port $port. Document root: $install_directory"
echo "You can delete the server using './script.sh remove'"
