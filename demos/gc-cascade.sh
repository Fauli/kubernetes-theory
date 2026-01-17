#!/bin/bash
# Demo: Garbage Collection Cascade Delete
# Shows how ownerReferences trigger automatic cleanup

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
echo -e "${BLUE}  Demo: Garbage Collection Cascade     ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Setup
echo -e "${GREEN}[1/5] Creating a Deployment with 2 replicas...${NC}"
kubectl create deployment demo-nginx --image=nginx --replicas=2
sleep 2

pause

# Show the hierarchy
echo -e "${GREEN}[2/5] Showing the ownership hierarchy...${NC}"
echo -e "${YELLOW}Deployment → ReplicaSet → Pods${NC}"
echo ""
kubectl get deploy,rs,pods -l app=demo-nginx
echo ""
echo -e "${YELLOW}Notice: Each level owns the next via ownerReferences${NC}"

pause

# Show ownerReferences
echo -e "${GREEN}[3/5] Looking at ownerReferences on a Pod...${NC}"
POD=$(kubectl get pods -l app=demo-nginx -o jsonpath='{.items[0].metadata.name}')
kubectl get pod $POD -o jsonpath='{.metadata.ownerReferences}' | jq .
echo ""
echo -e "${YELLOW}The Pod is owned by a ReplicaSet (controller: true)${NC}"

pause

# Delete and watch
echo -e "${GREEN}[4/5] Deleting the Deployment - watch the cascade...${NC}"
echo -e "${YELLOW}Running: kubectl delete deployment demo-nginx${NC}"
echo ""
kubectl delete deployment demo-nginx &
kubectl get pods -l app=demo-nginx -w &
WATCH_PID=$!
sleep 10
kill $WATCH_PID 2>/dev/null || true
echo ""
echo -e "${YELLOW}Pods disappeared! GC deleted them because owner was deleted.${NC}"

pause

# Cleanup
echo -e "${GREEN}[5/5] Cleanup complete${NC}"
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Key Takeaway:                        ${NC}"
echo -e "${BLUE}  ownerReferences = automatic cleanup  ${NC}"
echo -e "${BLUE}  No manual deletion needed!           ${NC}"
echo -e "${BLUE}========================================${NC}"
