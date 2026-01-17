#!/bin/bash
# Demo: Finalizers - Deletion is a State
# Shows how finalizers block deletion

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
echo -e "${BLUE}  Demo: Finalizers (Deletion is State) ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Cleanup
kubectl delete configmap finalizer-demo --force --grace-period=0 2>/dev/null || true

echo -e "${GREEN}[1/5] Creating a ConfigMap WITH a finalizer...${NC}"
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: finalizer-demo
  finalizers:
    - demo/my-cleanup-hook
data:
  key: value
EOF
echo ""
kubectl get configmap finalizer-demo
echo ""

pause

echo -e "${GREEN}[2/5] Trying to delete the ConfigMap...${NC}"
echo -e "${YELLOW}Running: kubectl delete configmap finalizer-demo &${NC}"
kubectl delete configmap finalizer-demo --wait=false &
DELETE_PID=$!
sleep 2
echo ""

pause

echo -e "${GREEN}[3/5] Is it deleted? Let's check...${NC}"
echo ""
kubectl get configmap finalizer-demo -o yaml | head -20
echo ""
echo -e "${RED}It still exists!${NC} But notice the deletionTimestamp."
echo ""

pause

echo -e "${GREEN}[4/5] Looking at the deletion state...${NC}"
echo ""
echo -e "${YELLOW}deletionTimestamp:${NC}"
kubectl get configmap finalizer-demo -o jsonpath='{.metadata.deletionTimestamp}'
echo ""
echo ""
echo -e "${YELLOW}finalizers:${NC}"
kubectl get configmap finalizer-demo -o jsonpath='{.metadata.finalizers}'
echo ""
echo ""
echo -e "${BLUE}The object is 'being deleted' but blocked by finalizer!${NC}"
echo -e "${BLUE}A real controller would: 1) do cleanup, 2) remove finalizer${NC}"

pause

echo -e "${GREEN}[5/5] Removing the finalizer (simulating controller cleanup)...${NC}"
kubectl patch configmap finalizer-demo -p '{"metadata":{"finalizers":null}}' --type=merge
sleep 2
echo ""
echo -e "${YELLOW}Checking if it's gone...${NC}"
kubectl get configmap finalizer-demo 2>&1 || true
echo ""
echo -e "${GREEN}Now it's deleted!${NC}"

# Wait for delete to complete
wait $DELETE_PID 2>/dev/null || true

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Key Takeaways:                       ${NC}"
echo -e "${BLUE}  - Deletion is a STATE (deletionTimestamp)${NC}"
echo -e "${BLUE}  - Finalizers BLOCK actual removal    ${NC}"
echo -e "${BLUE}  - Controller must remove finalizer   ${NC}"
echo -e "${BLUE}  - Stuck finalizers = stuck objects!  ${NC}"
echo -e "${BLUE}========================================${NC}"
