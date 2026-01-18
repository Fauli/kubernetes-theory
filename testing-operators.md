# Testing Operators
### From Unit Tests to Production Confidence
#### A Practical Guide

---

# Part 1: The Testing Pyramid

---

# Why Testing Operators Is Hard

| Challenge | Why It's Difficult |
|-----------|-------------------|
| API Interaction | Controllers constantly talk to the Kubernetes API |
| Asynchronous | Reconciliation happens in background goroutines |
| External State | Truth lives in etcd, not your code |
| Dependencies | Cloud APIs, databases, external services |
| Timing | Race conditions, eventual consistency |

You can't just call `Reconcile()` and check a return value.

---

# The Testing Pyramid for Operators

| Layer | Tool | Fidelity | Speed | Investment |
|-------|------|----------|-------|------------|
| **E2E** | kind / real cluster | Highest | Slow | Low |
| **Integration** | envtest | Medium | Fast | **High** |
| **Unit** | go test | Low | Fastest | Medium |

```
        ▲ E2E (real cluster)
       ╱ ╲    Few, slow, expensive
      ╱───╲
     ╱     ╲  Integration (envtest)
    ╱───────╲   ← Sweet spot for controllers
   ╱         ╲
  ╱   Unit    ╲ Many, fast, limited scope
 ╱─────────────╲
```

**Recommendation:** Invest most in envtest. It catches 80% of bugs.

---

# What Each Layer Tests

| Layer | What It Validates |
|-------|------------------|
| **Unit** | Business logic, transformations, validation |
| **envtest** | Reconciliation flow, status updates, RBAC |
| **E2E** | Full deployment, webhooks, real workloads |

```go
// Unit: Does buildDeployment() produce correct output?
// envtest: Does creating MyApp result in a Deployment?
// E2E: Does the Deployment actually run pods?
```

---

# Part 2: Unit Testing

---

# What to Unit Test

**Good candidates:**
- Pure functions (validation, transformations)
- Business logic extracted from Reconcile
- Utility/helper functions
- Spec-to-resource mapping

**Poor candidates:**
- Reconcile() directly (use envtest)
- Anything that needs a real client

---

# Extracting Testable Logic

**Before:** Everything in Reconcile (untestable)
```go
func (r *Reconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    // 200 lines mixing API calls with business logic
    var app myv1.Application
    r.Get(ctx, req.NamespacedName, &app)

    deploy := &appsv1.Deployment{
        // 50 lines of deployment construction
    }
    r.Create(ctx, deploy)
}
```

---

# Extracting Testable Logic (Fixed)

**After:** Pure functions extracted

```go
func (r *Reconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    var app myv1.Application
    r.Get(ctx, req.NamespacedName, &app)

    deploy := BuildDeployment(&app)  // Pure function!
    r.Create(ctx, deploy)
}

// Easily unit tested - no mocks needed
func BuildDeployment(app *myv1.Application) *appsv1.Deployment {
    return &appsv1.Deployment{
        ObjectMeta: metav1.ObjectMeta{
            Name:      app.Name,
            Namespace: app.Namespace,
        },
        Spec: appsv1.DeploymentSpec{
            Replicas: app.Spec.Replicas,
            // ...
        },
    }
}
```

---

# Unit Testing Pure Functions

```go
func TestBuildDeployment(t *testing.T) {
    app := &myv1.Application{
        ObjectMeta: metav1.ObjectMeta{Name: "test-app", Namespace: "default"},
        Spec: myv1.ApplicationSpec{
            Replicas: ptr.To(int32(3)),
            Image:    "nginx:latest",
        },
    }

    deploy := BuildDeployment(app)

    assert.Equal(t, "test-app", deploy.Name)
    assert.Equal(t, int32(3), *deploy.Spec.Replicas)
    assert.Equal(t, "nginx:latest", deploy.Spec.Template.Spec.Containers[0].Image)
}
```

Fast, deterministic, no external dependencies.

---

# Testing Validation Logic

```go
func ValidateApplication(app *myv1.Application) error {
    if app.Spec.Replicas != nil && *app.Spec.Replicas > 10 {
        return fmt.Errorf("replicas cannot exceed 10")
    }
    if !strings.HasPrefix(app.Spec.Image, "approved-registry/") {
        return fmt.Errorf("image must be from approved-registry")
    }
    return nil
}

func TestValidateApplication(t *testing.T) {
    tests := []struct {
        name    string
        app     *myv1.Application
        wantErr bool
    }{
        {"valid app", validApp(), false},
        {"too many replicas", appWithReplicas(20), true},
        {"unapproved image", appWithImage("docker.io/nginx"), true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := ValidateApplication(tt.app)
            assert.Equal(t, tt.wantErr, err != nil)
        })
    }
}
```

---

# The Fake Client

For simple tests that need a client but not full envtest:

```go
func TestReconcileBasic(t *testing.T) {
    app := &myv1.Application{
        ObjectMeta: metav1.ObjectMeta{Name: "test", Namespace: "default"},
    }

    // Create fake client with initial objects
    client := fake.NewClientBuilder().
        WithScheme(scheme.Scheme).
        WithObjects(app).
        WithStatusSubresource(app).  // Enable status updates
        Build()

    reconciler := &ApplicationReconciler{Client: client}
    _, err := reconciler.Reconcile(ctx, ctrl.Request{
        NamespacedName: types.NamespacedName{Name: "test", Namespace: "default"},
    })

    assert.NoError(t, err)
}
```

**Caveat:** Fake client doesn't behave exactly like real API server.

---

# When to Use Fake vs envtest

| Use Fake Client | Use envtest |
|----------------|-------------|
| Simple CRUD tests | Full reconciliation flow |
| Quick sanity checks | Testing watches/events |
| Testing error paths | Testing finalizers |
| CI speed matters a lot | Testing webhooks |

**Rule of thumb:** If you're testing controller *behavior*, use envtest.

---

# Part 3: Integration Testing with envtest

---

# What Is envtest?

A test environment that runs real Kubernetes components:

```
┌─────────────────────────────────────────┐
│     .        Your Test        .      .  │
├─────────────────────────────────────────┤
│     .       controller-runtime       .  │
├─────────────────────────────────────────┤
│   Real API Server    │    Real etcd     │  ← envtest provides these
└─────────────────────────────────────────┘
```

**What you get:**
- Real API server behavior (validation, defaulting)
- Real watches and events
- Real conflict detection

**What you don't get:**
- Kubelet (no actual pods running)
- Scheduler, controller-manager

---

# Setting Up envtest

```go
var (
    cfg       *rest.Config
    k8sClient client.Client
    testEnv   *envtest.Environment
    ctx       context.Context
    cancel    context.CancelFunc
)

func TestMain(m *testing.M) {
    testEnv = &envtest.Environment{
        CRDDirectoryPaths:     []string{filepath.Join("..", "config", "crd", "bases")},
        ErrorIfCRDPathMissing: true,
    }

    var err error
    cfg, err = testEnv.Start()
    if err != nil {
        log.Fatal(err)
    }

    // Run tests
    code := m.Run()

    // Cleanup
    testEnv.Stop()
    os.Exit(code)
}
```

---

# Installing envtest Binaries

The API server and etcd binaries are needed:

```bash
# Via setup-envtest (recommended)
go install sigs.k8s.io/controller-runtime/tools/setup-envtest@latest
setup-envtest use 1.28.x --bin-dir /usr/local/kubebuilder/bin

# Makefile target (kubebuilder projects)
make envtest
KUBEBUILDER_ASSETS="$(shell $(ENVTEST) use $(ENVTEST_K8S_VERSION) -p path)"
```

```makefile
# In your Makefile
ENVTEST_K8S_VERSION = 1.28.0

.PHONY: test
test: envtest
	KUBEBUILDER_ASSETS="$(shell $(ENVTEST) use $(ENVTEST_K8S_VERSION) -p path)" \
	go test ./... -coverprofile cover.out
```

---

# Starting the Controller

```go
func TestMain(m *testing.M) {
    // ... envtest setup ...

    k8sClient, _ = client.New(cfg, client.Options{Scheme: scheme.Scheme})

    // Start controller manager
    mgr, _ := ctrl.NewManager(cfg, ctrl.Options{Scheme: scheme.Scheme})

    reconciler := &ApplicationReconciler{
        Client: mgr.GetClient(),
        Scheme: mgr.GetScheme(),
    }
    reconciler.SetupWithManager(mgr)

    ctx, cancel = context.WithCancel(context.Background())
    go func() {
        mgr.Start(ctx)
    }()

    code := m.Run()
    cancel()  // Stop manager
    testEnv.Stop()
    os.Exit(code)
}
```

---

# Writing Your First envtest Test

```go
func TestAppCreatesDeployment(t *testing.T) {
    app := &myv1.Application{
        ObjectMeta: metav1.ObjectMeta{
            Name: "test-app", Namespace: "default",
        },
        Spec: myv1.ApplicationSpec{
            Image: "nginx", Replicas: ptr.To(int32(2)),
        },
    }
    require.NoError(t, k8sClient.Create(ctx, app))

    // Wait for controller to create Deployment
    deploy := &appsv1.Deployment{}
    key := types.NamespacedName{Name: "test-app", Namespace: "default"}

    eventually(t, func() bool {
        return k8sClient.Get(ctx, key, deploy) == nil
    }, 5*time.Second)

    assert.Equal(t, int32(2), *deploy.Spec.Replicas)
}
```

---

# The Eventually Pattern

Reconciliation is async - you must poll for results:

```go
// With Gomega (Ginkgo)
Eventually(func() bool {
    var app myv1.Application
    err := k8sClient.Get(ctx, key, &app)
    return err == nil && app.Status.Ready
}, timeout, interval).Should(BeTrue())

// With testify (standard library style)
func eventually(t *testing.T, condition func() bool, timeout time.Duration) {
    t.Helper()
    deadline := time.Now().Add(timeout)
    for time.Now().Before(deadline) {
        if condition() {
            return
        }
        time.Sleep(100 * time.Millisecond)
    }
    t.Fatal("condition not met within timeout")
}
```

**Tip:** Use short intervals (100ms) but reasonable timeouts (5-10s).

---

# The Consistently Pattern

Sometimes you need to verify something *doesn't* happen:

```go
// Verify no deployment is created for invalid app
Consistently(func() bool {
    var deploy appsv1.Deployment
    err := k8sClient.Get(ctx, key, &deploy)
    return apierrors.IsNotFound(err)
}, 2*time.Second, 200*time.Millisecond).Should(BeTrue())
```

**Use cases:**
- Invalid input should NOT create resources
- Deleted resource should NOT be recreated
- Paused reconciliation should NOT make changes

---

# Testing Status Updates

```go
func TestApplicationStatusUpdated(t *testing.T) {
    // Create app
    app := createTestApp(t, "status-test")

    // Wait for status to be updated
    eventually(t, func() bool {
        var updated myv1.Application
        k8sClient.Get(ctx, client.ObjectKeyFromObject(app), &updated)

        // Check conditions
        cond := meta.FindStatusCondition(updated.Status.Conditions, "Ready")
        return cond != nil && cond.Status == metav1.ConditionTrue
    }, 10*time.Second)

    // Verify observedGeneration
    var final myv1.Application
    k8sClient.Get(ctx, client.ObjectKeyFromObject(app), &final)
    assert.Equal(t, final.Generation, final.Status.ObservedGeneration)
}
```

---

# Testing Finalizers

```go
func TestFinalizerCleansUpExternalResource(t *testing.T) {
    app := createTestApp(t, "finalizer-test")

    // Wait for finalizer to be added
    eventually(t, func() bool {
        var updated myv1.Application
        k8sClient.Get(ctx, client.ObjectKeyFromObject(app), &updated)
        return controllerutil.ContainsFinalizer(&updated, "myapp.io/cleanup")
    }, 5*time.Second)

    // Delete the app
    err := k8sClient.Delete(ctx, app)
    require.NoError(t, err)

    // Verify cleanup happened (check your external system)
    eventually(t, func() bool {
        return externalResourceDeleted(app.Name)
    }, 10*time.Second)

    // Verify object is fully gone
    eventually(t, func() bool {
        var deleted myv1.Application
        err := k8sClient.Get(ctx, client.ObjectKeyFromObject(app), &deleted)
        return apierrors.IsNotFound(err)
    }, 5*time.Second)
}
```

---

# Testing Owner References

```go
func TestDeploymentHasOwnerReference(t *testing.T) {
    app := createTestApp(t, "owner-test")

    // Wait for deployment
    var deploy appsv1.Deployment
    eventually(t, func() bool {
        err := k8sClient.Get(ctx, client.ObjectKeyFromObject(app), &deploy)
        return err == nil
    }, 5*time.Second)

    // Verify owner reference
    ownerRef := metav1.GetControllerOf(&deploy)
    require.NotNil(t, ownerRef)
    assert.Equal(t, "Application", ownerRef.Kind)
    assert.Equal(t, app.Name, ownerRef.Name)
    assert.Equal(t, app.UID, ownerRef.UID)
}
```

---

# Part 4: E2E Testing

---

# When You Need E2E Tests

envtest doesn't run actual workloads. You need E2E for:

| Scenario | Why E2E? |
|----------|----------|
| Pod actually runs | Need kubelet |
| Service gets endpoints | Need kube-proxy |
| PVC binds to PV | Need provisioner |
| Webhooks with real certs | Need cert-manager |
| Multi-node behavior | Need real cluster |

---

# E2E Framework Options

| Framework | Style | Best For |
|-----------|-------|----------|
| **Ginkgo + Gomega** | BDD, Go code | Complex assertions |
| **kuttl** | YAML-based | Simple apply/assert |
| **chainsaw** | YAML-based | kuttl successor, more features |

```yaml
# kuttl test example
apiVersion: kuttl.dev/v1beta1
kind: TestStep
commands:
  - command: kubectl apply -f application.yaml
---
apiVersion: kuttl.dev/v1beta1
kind: TestAssert
timeout: 60
resource:
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: my-app
  status:
    readyReplicas: 3
```

---

# Kind for E2E Testing

```bash
# Create cluster
kind create cluster --name operator-test

# Load your operator image (no registry push needed)
kind load docker-image my-operator:test --name operator-test

# Install CRDs and operator
kubectl apply -f config/crd/
kubectl apply -f config/manager/

# Run tests
go test ./e2e/... -v

# Cleanup
kind delete cluster --name operator-test
```

---

# E2E Test Example

```go
func TestE2EApplicationDeployment(t *testing.T) {
    // Apply CR
    app := &myv1.Application{
        ObjectMeta: metav1.ObjectMeta{Name: "e2e-test", Namespace: "default"},
        Spec:       myv1.ApplicationSpec{Image: "nginx:latest", Replicas: ptr.To(int32(2))},
    }
    k8sClient.Create(ctx, app)

    // Wait for pods to actually be running
    eventually(t, func() bool {
        pods := &corev1.PodList{}
        k8sClient.List(ctx, pods,
            client.InNamespace("default"),
            client.MatchingLabels{"app": "e2e-test"})

        running := 0
        for _, pod := range pods.Items {
            if pod.Status.Phase == corev1.PodRunning {
                running++
            }
        }
        return running == 2
    }, 60*time.Second)
}
```

---

# Part 5: Testing Patterns

---

# Test Isolation with Namespaces

Each test gets its own namespace to avoid conflicts:

```go
func createTestNamespace(t *testing.T) string {
    ns := &corev1.Namespace{
        ObjectMeta: metav1.ObjectMeta{
            GenerateName: "test-",
        },
    }
    err := k8sClient.Create(ctx, ns)
    require.NoError(t, err)

    t.Cleanup(func() {
        k8sClient.Delete(ctx, ns)
    })

    return ns.Name
}

func TestSomething(t *testing.T) {
    ns := createTestNamespace(t)
    app := createAppInNamespace(t, ns, "my-app")
    // ...
}
```

---

# Parallel Test Execution

```go
func TestParallel(t *testing.T) {
    t.Parallel()  // Mark test as parallelizable

    ns := createTestNamespace(t)  // Isolated namespace
    // ... test logic
}
```

**Requirements for parallel tests:**
- Each test uses unique namespace
- No global state modification
- No fixed resource names
- Separate cleanup per test

---

# Test Fixtures and Helpers

```go
// testdata/application.yaml
type testFixtures struct {
    client client.Client
    ns     string
}

func newTestFixtures(t *testing.T) *testFixtures {
    ns := createTestNamespace(t)
    return &testFixtures{client: k8sClient, ns: ns}
}

func (f *testFixtures) createApp(t *testing.T, name string) *myv1.Application {
    app := &myv1.Application{
        ObjectMeta: metav1.ObjectMeta{Name: name, Namespace: f.ns},
        Spec:       defaultAppSpec(),
    }
    require.NoError(t, f.client.Create(ctx, app))
    return app
}

func (f *testFixtures) waitForReady(t *testing.T, app *myv1.Application) {
    eventually(t, func() bool {
        f.client.Get(ctx, client.ObjectKeyFromObject(app), app)
        return meta.IsStatusConditionTrue(app.Status.Conditions, "Ready")
    }, 10*time.Second)
}
```

---

# Testing Webhooks with envtest

```go
func TestMain(m *testing.M) {
    testEnv = &envtest.Environment{
        CRDDirectoryPaths: []string{"../config/crd/bases"},
        WebhookInstallOptions: envtest.WebhookInstallOptions{
            Paths: []string{"../config/webhook"},
        },
    }

    cfg, _ = testEnv.Start()

    // Webhooks need the manager to serve them
    mgr, _ := ctrl.NewManager(cfg, ctrl.Options{
        Scheme:         scheme.Scheme,
        WebhookServer:  webhook.NewServer(webhook.Options{Port: testEnv.WebhookInstallOptions.LocalServingPort}),
    })

    // Register webhooks
    (&myv1.Application{}).SetupWebhookWithManager(mgr)

    go mgr.Start(ctx)
    // ...
}
```

---

# Testing Validation Webhooks

```go
func TestValidationWebhookRejectsInvalidApp(t *testing.T) {
    app := &myv1.Application{
        ObjectMeta: metav1.ObjectMeta{Name: "invalid", Namespace: "default"},
        Spec: myv1.ApplicationSpec{
            Replicas: ptr.To(int32(100)),  // Exceeds limit
        },
    }

    err := k8sClient.Create(ctx, app)

    require.Error(t, err)
    assert.Contains(t, err.Error(), "replicas cannot exceed")
}

func TestMutationWebhookSetsDefaults(t *testing.T) {
    app := &myv1.Application{
        ObjectMeta: metav1.ObjectMeta{Name: "no-replicas", Namespace: "default"},
        Spec:       myv1.ApplicationSpec{Image: "nginx"},  // No replicas set
    }

    err := k8sClient.Create(ctx, app)
    require.NoError(t, err)

    // Webhook should have defaulted replicas
    var created myv1.Application
    k8sClient.Get(ctx, client.ObjectKeyFromObject(app), &created)
    assert.Equal(t, int32(1), *created.Spec.Replicas)
}
```

---

# Debugging Flaky Tests

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Random timeouts | Too short timeout | Increase to 10-30s |
| Works locally, fails in CI | CI is slower | Use longer timeouts in CI |
| Intermittent failures | Race condition | Add proper Eventually |
| Resource conflicts | Shared names | Use GenerateName |

```go
// CI-aware timeout
func testTimeout() time.Duration {
    if os.Getenv("CI") != "" {
        return 30 * time.Second
    }
    return 10 * time.Second
}
```

---

# Test Organization

```
myoperator/
├── api/v1/
│   └── application_types_test.go    # Type validation tests
├── internal/controller/
│   ├── application_controller.go
│   ├── application_controller_test.go  # envtest tests
│   └── suite_test.go                   # envtest setup
├── internal/builder/
│   ├── deployment.go
│   └── deployment_test.go           # Unit tests
└── e2e/
    ├── e2e_suite_test.go
    └── application_test.go          # E2E tests
```

---

# Summary

| Layer | Tool | Use For | Speed |
|-------|------|---------|-------|
| **Unit** | go test | Pure functions, builders | ~1ms |
| **Integration** | envtest | Controller logic, status, finalizers | ~2-5s startup |
| **E2E** | kind + kuttl/Ginkgo | Real workloads, webhooks, full flow | ~30s+ |

**Key patterns:**
- Extract pure functions for unit testing
- Use `Eventually` for async assertions
- Isolate tests with namespaces
- Use `Consistently` to verify non-action

---

# Questions?

---

