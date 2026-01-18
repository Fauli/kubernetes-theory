# Admission Webhooks
### Intercepting and Modifying Kubernetes Requests
#### A Deep Dive for Platform Engineers

---

# Part 1: What Are Admission Webhooks?

---

# The API Server Pipeline (Recap)

```
Request → AuthN → AuthZ → Mutating → Validating → Persist → Watch
                            ↑            ↑
                         Webhooks     Webhooks
```

Webhooks intercept requests **before** they're persisted to etcd.

---

# Two Types of Webhooks

| Type | Purpose | Can Modify? |
|------|---------|-------------|
| **Mutating** | Inject defaults, sidecars, labels | Yes |
| **Validating** | Enforce policies, reject bad config | No |

Order: Mutating runs first, then Validating.

---

# Why Use Webhooks?

- Inject sidecar containers (Istio, Vault)
- Enforce security policies
- Set defaults that CRD defaults can't handle
- Cross-resource validation
- Policy enforcement (OPA/Gatekeeper)

---

# Part 2: Mutating Webhooks

---

# Common Use Cases

- Inject sidecar containers
- Add default labels/annotations
- Set resource limits
- Inject environment variables
- Modify pod security settings

---

# How Mutation Works

TODO: Request/Response format
TODO: JSON Patch vs JSON Merge Patch

```go
func (w *Webhook) Handle(ctx context.Context, req admission.Request) admission.Response {
    pod := &corev1.Pod{}
    if err := w.decoder.Decode(req, pod); err != nil {
        return admission.Errored(http.StatusBadRequest, err)
    }

    // Mutate the pod
    pod.Labels["injected"] = "true"

    return admission.PatchResponseFromRaw(req.Object.Raw, marshaledPod)
}
```

---

# Sidecar Injection Example

TODO: Real sidecar injection code
TODO: Handling existing containers

---

# Part 3: Validating Webhooks

---

# Common Use Cases

- Enforce naming conventions
- Require labels/annotations
- Block privileged containers
- Validate cross-resource references
- Enforce quotas beyond ResourceQuota

---

# How Validation Works

TODO: Request/Response format
TODO: Allowed vs Denied

```go
func (w *Webhook) Handle(ctx context.Context, req admission.Request) admission.Response {
    pod := &corev1.Pod{}
    if err := w.decoder.Decode(req, pod); err != nil {
        return admission.Errored(http.StatusBadRequest, err)
    }

    if pod.Spec.HostNetwork {
        return admission.Denied("hostNetwork is not allowed")
    }

    return admission.Allowed("")
}
```

---

# Validation Patterns

TODO: Multiple validation rules
TODO: Warning vs Deny
TODO: Dry-run handling

---

# Part 4: Webhook Configuration

---

# MutatingWebhookConfiguration

TODO: Full YAML example
TODO: Key fields explained

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: my-webhook
webhooks:
  - name: my-webhook.example.com
    clientConfig:
      service:
        name: webhook-service
        namespace: default
        path: /mutate
    rules:
      - operations: ["CREATE"]
        resources: ["pods"]
```

---

# Matching Rules

TODO: operations, resources, apiGroups
TODO: namespaceSelector
TODO: objectSelector

---

# Failure Policy

| Policy | Behavior |
|--------|----------|
| `Fail` | Reject request if webhook unavailable |
| `Ignore` | Allow request if webhook unavailable |

**Default:** `Fail` - be careful!

---

# Part 5: Implementation

---

# Setting Up with controller-runtime

TODO: Registering webhooks
TODO: Cert management with cert-manager

---

# TLS Certificates

TODO: Why TLS is required
TODO: cert-manager integration
TODO: Self-signed certs for development

---

# Testing Webhooks

TODO: envtest with webhooks
TODO: Integration testing

---

# Part 6: Operational Concerns

---

# Performance

- Webhooks add latency to every matched request
- Keep logic fast
- Avoid external calls if possible

---

# High Availability

- Run multiple replicas
- Proper health checks
- Graceful shutdown

---

# Debugging Webhook Issues

TODO: Common failure modes
TODO: Debugging steps

```bash
# Check webhook configuration
kubectl get mutatingwebhookconfigurations
kubectl get validatingwebhookconfigurations

# Check if webhook is being called
kubectl logs <webhook-pod>

# Test webhook directly
kubectl create --dry-run=server -f pod.yaml
```

---

# Avoiding Deadlocks

**Danger:** If your webhook depends on resources in the cluster,
and those resources need the webhook to be created...

TODO: How to avoid
TODO: Namespace selectors to exclude system namespaces

---

# Summary

| Aspect | Mutating | Validating |
|--------|----------|------------|
| Purpose | Modify requests | Reject bad requests |
| Order | Runs first | Runs second |
| Response | Patch | Allow/Deny |
| Use case | Defaults, injection | Policy enforcement |

---

# Questions?

---
