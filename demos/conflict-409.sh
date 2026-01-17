#!/bin/bash
# Demo: 409 Conflict - Optimistic Concurrency
# Shows how concurrent updates cause conflicts

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

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Demo: 409 Conflict                   ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Cleanup
kubectl delete configmap conflict-demo 2>/dev/null || true

echo -e "${GREEN}[1/5] Creating a ConfigMap...${NC}"
kubectl create configmap conflict-demo --from-literal=counter=1
echo ""
kubectl get configmap conflict-demo -o yaml | grep -A5 "data:"
echo ""

pause

echo -e "${GREEN}[2/5] Saving the current state to a file...${NC}"
echo -e "${YELLOW}This simulates reading the object before modifying${NC}"
kubectl get configmap conflict-demo -o yaml > $TMPDIR/cm-old.yaml
echo ""
echo -e "${YELLOW}Saved resourceVersion:${NC}"
grep resourceVersion $TMPDIR/cm-old.yaml
echo ""

pause

echo -e "${GREEN}[3/5] Someone else updates the ConfigMap...${NC}"
echo -e "${YELLOW}Running: kubectl patch configmap conflict-demo ...${NC}"
kubectl patch configmap conflict-demo -p '{"data":{"counter":"2","updatedBy":"someone-else"}}'
echo ""
kubectl get configmap conflict-demo -o yaml | grep -A5 "data:"
echo ""
echo -e "${YELLOW}Note: resourceVersion has changed!${NC}"
kubectl get configmap conflict-demo -o jsonpath='{.metadata.resourceVersion}'
echo ""
echo ""

pause

echo -e "${GREEN}[4/5] Now we try to apply our old version...${NC}"
echo -e "${YELLOW}This will FAIL because resourceVersion is stale${NC}"
echo ""

# Modify our old file
sed -i.bak 's/counter: "1"/counter: "100"/' $TMPDIR/cm-old.yaml 2>/dev/null || \
  sed -i '' 's/counter: "1"/counter: "100"/' $TMPDIR/cm-old.yaml

echo -e "${YELLOW}Running: kubectl apply -f cm-old.yaml${NC}"
echo ""
kubectl apply -f $TMPDIR/cm-old.yaml 2>&1 || true
echo ""
echo -e "${RED}409 Conflict!${NC} Our resourceVersion was stale."

pause

echo -e "${GREEN}[5/5] The solution: re-read, modify, retry${NC}"
echo ""
echo -e "${YELLOW}Pattern in Go:${NC}"
cat <<'EOF'
err := retry.RetryOnConflict(retry.DefaultRetry, func() error {
    // 1. Re-read current state
    if err := r.Get(ctx, key, &obj); err != nil {
        return err
    }
    // 2. Modify
    obj.Data["counter"] = "100"
    // 3. Update (may conflict, will retry)
    return r.Update(ctx, &obj)
})
EOF
echo ""
echo -e "${YELLOW}Or use Server-Side Apply to avoid conflicts entirely!${NC}"

# Cleanup
kubectl delete configmap conflict-demo

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Key Takeaways:                       ${NC}"
echo -e "${BLUE}  - resourceVersion = optimistic lock  ${NC}"
echo -e "${BLUE}  - Stale version → 409 Conflict       ${NC}"
echo -e "${BLUE}  - Always re-read before update       ${NC}"
echo -e "${BLUE}  - Or use Server-Side Apply           ${NC}"
echo -e "${BLUE}========================================${NC}"
