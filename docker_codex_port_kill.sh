ps aux | grep copilot-api
pkill -f copilot-api
sleep 1
ss -ltnp | grep 4141    # çmake sure port is already not be used
