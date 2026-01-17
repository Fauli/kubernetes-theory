#!/bin/bash
# Demo: Level-Triggered Reconciliation
# Shows that controllers react to STATE, not events

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
echo -e "${BLUE}  Demo: Level-Triggered Reconciliation ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Cleanup any previous run
kubectl delete deployment level-demo 2>/dev/null || true

# Create deployment
echo -e "${GREEN}[1/4] Creating a Deployment with 3 replicas...${NC}"
kubectl create deployment level-demo --image=nginx --replicas=3
echo -e "${YELLOW}Waiting for pods to be ready...${NC}"
kubectl wait --for=condition=available deployment/level-demo --timeout=60s
echo ""
kubectl get pods -l app=level-demo
echo ""

pause

# Show current state
echo -e "${GREEN}[2/4] Current state: 3 pods running${NC}"
echo -e "${YELLOW}Desired: 3 | Actual: 3 | Gap: 0${NC}"
echo ""

pause

# Delete a pod and watch
echo -e "${GREEN}[3/4] Deleting one pod - watch what happens...${NC}"
POD=$(kubectl get pods -l app=level-demo -o jsonpath='{.items[0].metadata.name}')
echo -e "${YELLOW}Deleting pod: $POD${NC}"
echo ""

# Start watch in background
kubectl get pods -l app=level-demo -w &
WATCH_PID=$!

sleep 1
kubectl delete pod $POD

echo -e "${YELLOW}Watch the output above...${NC}"
sleep 8
kill $WATCH_PID 2>/dev/null || true

echo ""
echo -e "${YELLOW}A new pod was created!${NC}"
echo ""

pause

# Explain
echo -e "${GREEN}[4/4] What happened?${NC}"
echo ""
echo -e "${BLUE}The controller did NOT react to 'pod deleted' event.${NC}"
echo -e "${BLUE}It saw: Desired=3, Actual=2, Gap=1 → Create 1 pod${NC}"
echo ""
echo -e "${YELLOW}This is level-triggered:${NC}"
echo -e "  Edge-triggered: 'A pod was deleted' → create pod"
echo -e "  Level-triggered: 'Want 3, have 2' → create 1"
echo ""

# Cleanup
echo -e "${GREEN}Cleaning up...${NC}"
kubectl delete deployment level-demo

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Key Takeaway:                        ${NC}"
echo -e "${BLUE}  Controllers reconcile STATE not events${NC}"
echo -e "${BLUE}========================================${NC}"
