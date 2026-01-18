# CRD Design Patterns
### Building APIs That Don't Suck
#### A Guide for Operator Developers

---

# Part 1: API Design Philosophy

---

# Your CRD Is a User Interface

- Users interact with your operator through the CRD
- Bad API design = frustrated users
- Good API design = self-documenting, hard to misuse

```yaml
# Bad: What does this mean?
spec:
  mode: 3
  flags: "rw,sync"

# Good: Self-documenting
spec:
  accessMode: ReadWrite
  synchronous: true
```

---

# The Kubernetes API Conventions

From the official [API Conventions](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md):

| Principle | Meaning |
|-----------|---------|
| Declarative | Describe desired state, not actions |
| Spec/Status split | Spec = intent, Status = observation |
| Level-triggered | Current state matters, not history |
| Explicit | No hidden defaults or magic |

---

# Declarative Over Imperative

```yaml
# Imperative (BAD) - describes actions
spec:
  action: "scale-up"
  increment: 2

# Declarative (GOOD) - describes desired state
spec:
  replicas: 5
```

The controller figures out *how* to get there.

---

# Spec Is Intent, Status Is Observation

```yaml
apiVersion: myapp.io/v1
kind: Database
metadata:
  name: prod-db
spec:
  # What the USER wants
  replicas: 3
  version: "14.2"
status:
  # What the CONTROLLER observes
  readyReplicas: 2
  currentVersion: "14.1"
  conditions:
    - type: Upgrading
      status: "True"
```

Note: Never read from status in your controller logic!

---

# Part 2: Spec Design

---

# Required vs Optional Fields

The Go type determines behavior:

```go
type DatabaseSpec struct {
    // Required - no pointer, no omitempty
    // User MUST provide this
    Name string `json:"name"`

    // Optional with zero value - use pointer
    // nil means "use default", 0 means "zero"
    Replicas *int32 `json:"replicas,omitempty"`

    // Optional string - empty string is valid
    // nil means "not set"
    Description *string `json:"description,omitempty"`
}
```

---

# The Pointer Rule

| Type | Zero Value | Use Pointer? |
|------|------------|--------------|
| `string` | `""` | If empty string is valid |
| `int32` | `0` | If zero is a valid value |
| `bool` | `false` | Almost always yes |
| `[]T` | `nil` | Usually no (nil == empty) |

```go
// bool example - nil vs false matters
EnableTLS *bool `json:"enableTLS,omitempty"`

// nil  = use cluster default
// true = force TLS
// false = explicitly disable TLS
```

---

# Setting Defaults

Three options, in order of preference:

**1. CRD structural schema defaults (simplest)**
```yaml
# In CRD YAML
properties:
  replicas:
    type: integer
    default: 1
```

**2. Kubebuilder markers**
```go
// +kubebuilder:default=3
Replicas *int32 `json:"replicas,omitempty"`
```

**3. Mutating webhook (most flexible)**
```go
func (r *Database) Default() {
    if r.Spec.Replicas == nil {
        r.Spec.Replicas = ptr.To(int32(3))
    }
}
```

---

# Validation with Kubebuilder Markers

```go
type DatabaseSpec struct {
    // +kubebuilder:validation:MinLength=1
    // +kubebuilder:validation:MaxLength=63
    // +kubebuilder:validation:Pattern=`^[a-z][a-z0-9-]*$`
    Name string `json:"name"`

    // +kubebuilder:validation:Minimum=1
    // +kubebuilder:validation:Maximum=10
    Replicas *int32 `json:"replicas,omitempty"`

    // +kubebuilder:validation:Enum=small;medium;large
    Size string `json:"size"`
}
```

Validation happens at the API server - fast feedback!

---

# CEL Validation (Kubernetes 1.25+)

More powerful than markers, runs in the API server:

```go
// +kubebuilder:validation:XValidation:rule="self.minReplicas <= self.maxReplicas",message="min must be <= max"
type AutoscalingSpec struct {
    MinReplicas int32 `json:"minReplicas"`
    MaxReplicas int32 `json:"maxReplicas"`
}
```

CEL can:
- Compare multiple fields
- Access old value (`oldSelf`) for transition rules
- Call built-in functions

---

# Part 3: Immutable Fields

---

# When Fields Should Be Immutable

Some fields can't change after creation:

| Field Type | Example | Why Immutable? |
|------------|---------|----------------|
| Storage class | `storageClass: fast` | Can't migrate PVs |
| Network config | `subnet: 10.0.0.0/24` | Would break connections |
| Identity | `clusterID: abc123` | External systems reference it |

---

# Enforcing Immutability

**Option 1: CEL transition rules**
```go
// +kubebuilder:validation:XValidation:rule="self == oldSelf",message="storageClass is immutable"
StorageClass string `json:"storageClass"`
```

**Option 2: Validating webhook**
```go
func (r *Database) ValidateUpdate(old runtime.Object) error {
    oldDB := old.(*Database)
    if r.Spec.StorageClass != oldDB.Spec.StorageClass {
        return field.Forbidden(
            field.NewPath("spec", "storageClass"),
            "field is immutable",
        )
    }
    return nil
}
```

---

# Immutable After Set Pattern

Sometimes a field can be set once, but not changed:

```go
// +kubebuilder:validation:XValidation:rule="oldSelf == '' || self == oldSelf",message="clusterID is immutable once set"
ClusterID string `json:"clusterID,omitempty"`
```

This allows:
- `""` -> `"abc123"` (setting initial value)
- `"abc123"` -> `"abc123"` (no change)
- `"abc123"` -> `"xyz789"` (BLOCKED)

---

# Part 4: Nested vs Flat Structures

---

# When to Nest Objects

**Nest when:**
- Fields are logically grouped
- The group might be reused
- The group is optional as a whole

```go
// Good nesting - TLS is optional as a unit
type DatabaseSpec struct {
    TLS *TLSConfig `json:"tls,omitempty"`
}

type TLSConfig struct {
    Enabled     bool   `json:"enabled"`
    SecretName  string `json:"secretName"`
    MinVersion  string `json:"minVersion,omitempty"`
}
```

---

# When to Keep Flat

**Keep flat when:**
- Fields are independent
- Nesting adds no clarity
- You want simpler YAML

```go
// Unnecessary nesting
spec:
  resources:
    compute:
      cpu: "1"
      memory: "1Gi"

// Better flat
spec:
  cpu: "1"
  memory: "1Gi"
```

---

# Embedded Types for Reuse

Kubernetes uses embedded types extensively:

```go
type PodSpec struct {
    // Embedded - fields appear at PodSpec level
    corev1.Container `json:",inline"`
}

type DatabaseSpec struct {
    // Reference - clearer boundary
    Template corev1.PodTemplateSpec `json:"template"`
}
```

Use `json:",inline"` sparingly - it can confuse users.

---

# Part 5: Status Design

---

# What Belongs in Status

| Include | Exclude |
|---------|---------|
| Current state observations | Derived/computed values that aren't stored |
| Ready replica counts | Anything the user can compute |
| Error messages | Sensitive data (secrets, tokens) |
| External resource IDs | Large blobs |
| Conditions | Historical data |

---

# ObservedGeneration Pattern

**Critical for correctness:**

```go
type DatabaseStatus struct {
    // Which spec version did we last reconcile?
    ObservedGeneration int64 `json:"observedGeneration,omitempty"`

    Conditions []metav1.Condition `json:"conditions,omitempty"`
}
```

```go
// In your controller:
if db.Generation != db.Status.ObservedGeneration {
    // Spec changed - need to reconcile
}

// After successful reconcile:
db.Status.ObservedGeneration = db.Generation
```

---

# Conditions

Standard way to report multiple aspects of status:

```go
type DatabaseStatus struct {
    Conditions []metav1.Condition `json:"conditions,omitempty"`
}
```

```yaml
status:
  conditions:
    - type: Ready
      status: "True"
      reason: AllReplicasAvailable
      message: "3/3 replicas are ready"
      lastTransitionTime: "2024-01-15T10:30:00Z"
    - type: Progressing
      status: "False"
      reason: NewReplicaSetAvailable
```

---

# Standard Condition Types

| Type | Meaning |
|------|---------|
| `Ready` | Resource is fully operational |
| `Progressing` | Working toward desired state |
| `Degraded` | Partially working |
| `Available` | Can serve traffic |

Use `meta.SetStatusCondition` helper:

```go
meta.SetStatusCondition(&db.Status.Conditions, metav1.Condition{
    Type:    "Ready",
    Status:  metav1.ConditionTrue,
    Reason:  "AllReplicasReady",
    Message: fmt.Sprintf("%d/%d replicas ready", ready, desired),
})
```

---

# Phase vs Conditions

| Aspect | Phase | Conditions |
|--------|-------|------------|
| Cardinality | Single value | Multiple independent states |
| Complexity | Simple | Richer |
| Extensibility | Hard to add states | Easy to add conditions |
| User experience | Easy to understand | Can be overwhelming |

**Recommendation:** Use Conditions. If you need Phase for UX, derive it:

```go
status:
  phase: Running  # Derived from conditions
  conditions: [...]
```

---

# Part 6: Versioning

---

# API Version Lifecycle

```
v1alpha1  →  v1beta1  →  v1
   ↓           ↓         ↓
Unstable    Stable-ish   Stable
May break   Discouraged  Breaking changes
any time    to break     need new version
```

**Rules:**
- `alpha`: No compatibility guarantees
- `beta`: 9 months deprecation minimum
- `stable`: Years of support expected

---

# When to Create a New Version

**New version needed:**
- Removing a field
- Renaming a field
- Changing field type
- Changing validation to be stricter
- Changing semantics

**Same version OK:**
- Adding optional fields
- Relaxing validation
- Adding new enum values
- Deprecating (not removing) fields

---

# Conversion Webhooks

When you have multiple versions, the API server needs to convert:

```
User sends v1beta1 → Webhook converts → Stored as v1 (hub)
User reads v1alpha1 ← Webhook converts ← Stored as v1 (hub)
```

**Hub and Spoke Pattern:**
- One version is the "hub" (usually newest stable)
- All other versions convert to/from hub
- Avoids N×M conversion functions

---

# Hub and Spoke Implementation

```go
// v1 is the hub
func (src *DatabaseV1) ConvertTo(dst conversion.Hub) error {
    return nil // v1 IS the hub, nothing to do
}

// v1beta1 converts to hub
func (src *DatabaseV1beta1) ConvertTo(dstRaw conversion.Hub) error {
    dst := dstRaw.(*v1.Database)
    dst.Spec.Replicas = src.Spec.Size // field renamed
    return nil
}

func (dst *DatabaseV1beta1) ConvertFrom(srcRaw conversion.Hub) error {
    src := srcRaw.(*v1.Database)
    dst.Spec.Size = src.Spec.Replicas
    return nil
}
```

---

# Storage Version

Only one version is stored in etcd:

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
spec:
  versions:
    - name: v1
      served: true
      storage: true   # ← This version is stored
    - name: v1beta1
      served: true
      storage: false  # ← Converted on read/write
```

Changing storage version requires migration!

---

# Part 7: Common Patterns

---

# Reference Patterns

Three ways to reference other resources:

```go
// 1. Just the name (same namespace assumed)
SecretName string `json:"secretName"`

// 2. LocalObjectReference (explicit, same namespace)
SecretRef corev1.LocalObjectReference `json:"secretRef"`

// 3. Full reference (cross-namespace)
SecretRef corev1.ObjectReference `json:"secretRef"`
```

---

# Cross-Namespace References

Be careful with cross-namespace references:

```yaml
spec:
  # Potential security issue - can reference any namespace
  configRef:
    name: my-config
    namespace: other-namespace
```

**Best practices:**
- Default to same-namespace only
- If cross-namespace needed, require explicit RBAC
- Consider ReferenceGrant pattern (Gateway API)

---

# Embedded vs Referenced Config

**Embed when:**
- Config is small
- Config is always needed
- You want atomic updates

```yaml
spec:
  config:
    maxConnections: 100
    timeout: 30s
```

**Reference when:**
- Config is large or shared
- Config changes independently
- Secrets are involved

```yaml
spec:
  configRef:
    name: database-config
```

---

# Secrets - Never Embed

```go
// WRONG - secrets in spec
type DatabaseSpec struct {
    Password string `json:"password"`  // Visible in kubectl get!
}

// RIGHT - reference a Secret
type DatabaseSpec struct {
    PasswordSecretRef corev1.SecretKeySelector `json:"passwordSecretRef"`
}
```

```yaml
spec:
  passwordSecretRef:
    name: db-credentials
    key: password
```

---

# Part 8: Real-World Examples

---

# Good: Cert-Manager Certificate

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
spec:
  secretName: my-cert-tls      # Clear naming
  duration: 2160h              # Explicit, not magic
  renewBefore: 360h
  issuerRef:                   # Reference pattern
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:                    # Array of primitives
    - example.com
    - www.example.com
```

---

# Good: Crossplane Composition

```yaml
apiVersion: database.example.com/v1
kind: PostgreSQLInstance
spec:
  # User-friendly abstractions
  size: medium           # Not raw CPU/memory
  version: "14"          # Major version only

  # Sensible defaults via mutating webhook
  backup:
    enabled: true
    schedule: "0 2 * * *"
```

The operator translates "medium" to actual resource values.

---

# Summary

| Principle | Guidance |
|-----------|----------|
| Declarative | Describe state, not actions |
| Spec/Status | Intent vs observation |
| Pointers | Use for optional fields with meaningful zero |
| Validation | CEL > Markers > Webhooks |
| Immutability | Enforce with CEL or webhooks |
| Conditions | Prefer over Phase |
| Versioning | Hub and spoke pattern |
| Secrets | Always reference, never embed |

---

# Questions?

---

