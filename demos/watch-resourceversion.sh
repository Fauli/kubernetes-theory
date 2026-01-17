#!/bin/bash
# Demo: Watch and resourceVersion
# Shows how watches work with incremental resourceVersions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pause() {
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Demo: Watch and resourceVersion      ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Cleanup
kubectl delete configmap watch-demo 2>/dev/null || true

echo -e "${GREEN}[1/4] Starting a watch on ConfigMaps...${NC}"
echo -e "${YELLOW}Each event will show its resourceVersion${NC}"
echo ""
echo -e "${YELLOW}Starting watch in background (will show events below)...${NC}"
echo ""

# Start watch with custom output format
kubectl get configmaps -w -o custom-columns='EVENT:metadata.name,RESOURCE_VERSION:metadata.resourceVersion' --no-headers &
WATCH_PID=$!

sleep 2

pause

echo -e "${GREEN}[2/4] Creating a ConfigMap...${NC}"
kubectl create configmap watch-demo --from-literal=key=value1
sleep 2

pause

echo -e "${GREEN}[3/4] Updating the ConfigMap...${NC}"
kubectl patch configmap watch-demo -p '{"data":{"key":"value2"}}'
sleep 2

kubectl patch configmap watch-demo -p '{"data":{"key":"value3"}}'
sleep 2

pause

echo -e "${GREEN}[4/4] Deleting the ConfigMap...${NC}"
kubectl delete configmap watch-demo
sleep 2

# Stop the watch
kill $WATCH_PID 2>/dev/null || true

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Key Takeaways:                       ${NC}"
echo -e "${BLUE}  - Each change has a new resourceVersion${NC}"
echo -e "${BLUE}  - Watch streams changes incrementally ${NC}"
echo -e "${BLUE}  - resourceVersion orders all changes ${NC}"
echo -e "${BLUE}========================================${NC}"
