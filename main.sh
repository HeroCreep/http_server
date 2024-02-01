#!/bin/bash

# Check if Python is installed
if command -v python3 &>/dev/null; then
    # Create a virtual environment
    python3 -m venv venv

    # Activate the virtual environment
    source venv/bin/activate

    # Install required dependencies
    pip install Flask==2.0.1

    # Create the server script
    cat <<EOF >server.py
from flask import Flask
app = Flask(__name__)

@app.route('/')
def hello():
    return 'Hello, World!'

if __name__ == '__main__':
    app.run(port=8080)
EOF

    echo "Installation complete. To start the server, run: ./setup_server.sh start"
else
    echo "Python 3 is required for this installation."
    echo "Please install Python 3 and run this script again."
fi

# Check for the start command
if [ "$1" == "start" ]; then
    # Activate the virtual environment
    source venv/bin/activate

    # Run the simple HTTP server
    python server.py
fi
