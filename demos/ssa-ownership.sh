#!/bin/bash
# Demo: Server-Side Apply Field Ownership
# Shows how multiple managers can own different fields

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
echo -e "${BLUE}  Demo: Server-Side Apply Ownership    ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Cleanup any previous run
kubectl delete configmap ssa-demo 2>/dev/null || true

# Manager A creates with field .data.a
echo -e "${GREEN}[1/5] Manager A creates ConfigMap with field 'a'...${NC}"
echo -e "${YELLOW}Running: kubectl apply --server-side --field-manager=manager-a${NC}"
kubectl apply --server-side --field-manager=manager-a -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ssa-demo
data:
  a: "owned-by-manager-a"
EOF
echo ""

pause

# Manager B adds field .data.b
echo -e "${GREEN}[2/5] Manager B adds field 'b' (different manager)...${NC}"
echo -e "${YELLOW}Running: kubectl apply --server-side --field-manager=manager-b${NC}"
kubectl apply --server-side --field-manager=manager-b -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ssa-demo
data:
  b: "owned-by-manager-b"
EOF
echo ""

pause

# Show the result
echo -e "${GREEN}[3/5] Both fields coexist!${NC}"
kubectl get configmap ssa-demo -o yaml
echo ""
echo -e "${YELLOW}Notice: Both 'a' and 'b' are present - no conflict!${NC}"

pause

# Show managedFields
echo -e "${GREEN}[4/5] Looking at managedFields (who owns what)...${NC}"
kubectl get configmap ssa-demo -o jsonpath='{.metadata.managedFields}' | jq '.[] | {manager, fields: .fieldsV1}'
echo ""
echo -e "${YELLOW}Each manager owns only the fields they applied.${NC}"

pause

# Show conflict when same field
echo -e "${GREEN}[5/5] What if Manager B tries to change 'a'?${NC}"
echo -e "${YELLOW}Without --force-conflicts, this will fail:${NC}"
kubectl apply --server-side --field-manager=manager-b -f - <<EOF 2>&1 || true
apiVersion: v1
kind: ConfigMap
metadata:
  name: ssa-demo
data:
  a: "manager-b-tries-to-steal"
  b: "owned-by-manager-b"
EOF
echo ""
echo -e "${YELLOW}Conflict! Manager A owns field 'a'.${NC}"

pause

# Cleanup
echo -e "${GREEN}Cleaning up...${NC}"
kubectl delete configmap ssa-demo

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Key Takeaway:                        ${NC}"
echo -e "${BLUE}  SSA = safe multi-controller updates  ${NC}"
echo -e "${BLUE}  Each manager owns their fields       ${NC}"
echo -e "${BLUE}========================================${NC}"
