# Testing Operators
### From Unit Tests to Production Confidence
#### A Practical Guide

---

# Part 1: The Testing Pyramid

---

# Why Testing Operators Is Hard

- Controllers interact with Kubernetes API
- Asynchronous reconciliation
- External dependencies (cloud APIs, databases)
- State lives in the cluster, not your code

---

# The Testing Pyramid for Operators

```
        /\
       /  \     E2E Tests (real cluster)
      /----\
     /      \   Integration Tests (envtest)
    /--------\
   /          \  Unit Tests (no API server)
  --------------
```

---

# Part 2: Unit Testing

---

# What to Unit Test

- Pure functions (validation, transformations)
- Business logic extracted from Reconcile
- Helper functions

---

# Extracting Testable Logic

TODO: How to structure code for testability
TODO: Example refactoring

```go
// Hard to test
func (r *Reconciler) Reconcile(...) {
    // 200 lines of mixed logic
}

// Easy to test
func (r *Reconciler) Reconcile(...) {
    desired := r.buildDesiredState(obj)
    // ...
}

func buildDesiredState(obj *MyType) *appsv1.Deployment {
    // Pure function - easy to test!
}
```

---

# Mocking the Client

TODO: When to mock vs use envtest
TODO: fake.NewClientBuilder()

---

# Part 3: Integration Testing with envtest

---

# What Is envtest?

- Runs a real API server and etcd (in-process)
- No kubelet, no nodes, no scheduler
- Fast startup (~2 seconds)
- Perfect for controller tests

---

# Setting Up envtest

TODO: Setup code example
TODO: Installing binaries
TODO: Makefile targets

```go
var testEnv *envtest.Environment

func TestMain(m *testing.M) {
    testEnv = &envtest.Environment{
        CRDDirectoryPaths: []string{"../config/crd/bases"},
    }
    cfg, _ := testEnv.Start()
    // ...
}
```

---

# Writing envtest Tests

TODO: Creating test resources
TODO: Waiting for reconciliation
TODO: Asserting on results

---

# Testing Reconciliation

TODO: How to trigger reconcile
TODO: Eventually/Consistently patterns
TODO: Timeouts and flakiness

```go
Eventually(func() bool {
    var obj MyType
    err := k8sClient.Get(ctx, key, &obj)
    return obj.Status.Ready == true
}, timeout, interval).Should(BeTrue())
```

---

# Testing Finalizers

TODO: Testing deletion flow
TODO: Simulating cleanup

---

# Testing Error Cases

TODO: Simulating API errors
TODO: Testing retry behavior

---

# Part 4: E2E Testing

---

# When You Need E2E Tests

- Testing with real nodes/pods
- Testing with real external services
- Smoke tests before release

---

# E2E Frameworks

TODO: Ginkgo + Gomega
TODO: kuttl
TODO: chainsaw

---

# Kind for E2E

TODO: Setting up kind cluster
TODO: Loading operator image
TODO: Running tests

---

# Part 5: Testing Patterns

---

# Test Fixtures

TODO: Managing test data
TODO: Cleanup between tests

---

# Parallel Tests

TODO: Namespace isolation
TODO: Avoiding conflicts

---

# Testing Webhooks

TODO: envtest with webhooks
TODO: Cert generation

---

# Summary

| Layer | Tool | Speed | Fidelity |
|-------|------|-------|----------|
| Unit | go test | Fast | Low |
| Integration | envtest | Medium | Medium |
| E2E | kind/real cluster | Slow | High |

---

# Questions?

---
