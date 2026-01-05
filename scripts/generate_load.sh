#!/bin/bash
echo "Starting load generation..."

while true; do
    # Normal requests
    for i in {1..10}; do
        curl -s -o /dev/null "http://localhost:3000/"
    done
    
    # Slow endpoint calls
    curl -s -o /dev/null "http://localhost:3000/slow"
    
    # Database calls
    curl -s -o /dev/null "http://localhost:3000/db"
    
    # Cache calls
    curl -s -o /dev/null "http://localhost:3000/cache"
    
    sleep 2
done
