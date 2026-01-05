#!/bin/bash
echo "Generating periodic spikes..."

while true; do
    echo "Creating CPU spike..."
    for i in {1..4}; do
        docker exec webapp sh -c 'dd if=/dev/zero of=/dev/null &' &
    done
    
    sleep 30
    
    echo "Stopping CPU spike..."
    docker exec webapp sh -c "killall dd"
    
    sleep 90
done
