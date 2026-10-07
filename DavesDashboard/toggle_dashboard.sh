#!/bin/bash
cd "$(dirname "$0")"

# Check if the server is already running
if pgrep -f "server.py" > /dev/null
then
    echo "🛑 Dave's Dashboard is currently running. Stopping it now..."
    pkill -f "server.py"
    echo "✅ Dashboard successfully stopped!"
else
    echo "🚀 Starting Dave's Dashboard..."
    # Start the server in the background
    python3 server.py > /dev/null 2>&1 &
    
    # Wait a second for it to boot up
    sleep 1
    
    echo "🌐 Opening in your default web browser..."
    # Automatically open the web browser
    xdg-open http://localhost:8081
    
    echo "✅ Dashboard is now running in the background!"
    echo "   (Run this script again when you want to stop it)"
fi
