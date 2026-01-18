# Debugging Operators
### Finding and Fixing Controller Issues
#### A Troubleshooting Guide

---

# Part 1: Observability Basics

---

# The Three Pillars

- **Logs** - What happened
- **Metrics** - How much/how often
- **Traces** - Request flow (less common for operators)

---

# Structured Logging

TODO: Why structured logging matters
TODO: controller-runtime logging

```go
log := ctrl.LoggerFrom(ctx)
log.Info("reconciling", "name", obj.Name, "generation", obj.Generation)
log.Error(err, "failed to create deployment", "deployment", deploy.Name)
```

---

# Log Levels

| Level | Use For |
|-------|---------|
| Error | Failures that need attention |
| Info | Normal operations, state changes |
| Debug | Detailed troubleshooting |
| Trace | Very verbose, rarely used |

---

# Part 2: Common Issues

---

# Objects Stuck in Terminating

**Symptoms:** Object has deletionTimestamp but won't delete

**Causes:**
- Finalizer not being removed
- Cleanup code failing silently
- Controller not running

**Debug:**
```bash
kubectl get <resource> -o yaml | grep -A5 finalizers
kubectl logs <operator-pod> | grep <resource-name>
```

---

# Controller Not Reconciling

**Symptoms:** Changes to CR don't trigger reconcile

**Causes:**
- RBAC missing (can't watch resource)
- Watch not set up correctly
- Controller crashed

**Debug:**
```bash
kubectl auth can-i watch <resource> --as=system:serviceaccount:<ns>:<sa>
kubectl logs <operator-pod>
```

---

# Reconcile Loops (Hot Loops)

**Symptoms:** CPU spike, constant reconciliation

**Causes:**
- Always returning Requeue: true
- Status update triggers new reconcile
- Comparing objects incorrectly (timestamps, etc.)

**Debug:**
```bash
kubectl logs <operator-pod> | grep "Reconciling" | head -100
# Check metrics for reconcile rate
```

---

# Conflicts (409 Errors)

**Symptoms:** Intermittent update failures

**Causes:**
- Multiple controllers updating same resource
- Long reconcile with stale object
- Not using SSA or retry

**Debug:**
```bash
kubectl logs <operator-pod> | grep -i conflict
kubectl get <resource> -o yaml | grep managedFields
```

---

# Part 3: Debugging Tools

---

# kubectl Basics

```bash
# Watch events
kubectl get events --watch --field-selector involvedObject.name=<name>

# Check RBAC
kubectl auth can-i --list --as=system:serviceaccount:ns:sa

# Debug pods
kubectl logs -f deployment/<operator> -c manager
kubectl exec -it deployment/<operator> -- sh
```

---

# Increasing Log Verbosity

TODO: controller-runtime log levels
TODO: Zap logger configuration

```bash
# Run with verbose logging
./manager --zap-log-level=debug

# Or set via environment
LOG_LEVEL=debug
```

---

# Using Delve (Debugger)

TODO: Remote debugging setup
TODO: Breakpoints in Reconcile

---

# Part 4: Metrics

---

# Built-in Controller Metrics

controller-runtime exposes:
- `controller_runtime_reconcile_total`
- `controller_runtime_reconcile_errors_total`
- `controller_runtime_reconcile_time_seconds`
- `workqueue_depth`
- `workqueue_adds_total`

---

# Custom Metrics

TODO: Adding custom metrics
TODO: Prometheus ServiceMonitor

---

# Alerting

TODO: Key alerts for operators
TODO: Runbooks

---

# Part 5: Production Debugging

---

# Leader Election Issues

**Symptoms:** Multiple instances reconciling, or none

**Debug:**
```bash
kubectl get lease -n <namespace>
kubectl describe lease <operator-lock>
```

---

# Memory Leaks

**Symptoms:** OOMKilled, growing memory usage

**Causes:**
- Caching too many resources
- Not releasing informer watches
- Goroutine leaks

**Debug:**
```bash
kubectl top pod <operator-pod>
# pprof endpoint if enabled
```

---

# Webhook Failures

**Symptoms:** Create/Update rejected, timeouts

**Debug:**
```bash
kubectl logs <operator-pod> | grep webhook
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations
```

---

# Summary

1. **Check logs first** - Most issues are obvious in logs
2. **Check RBAC** - Can the controller see resources?
3. **Check events** - kubectl get events
4. **Check metrics** - Reconcile rate, errors, queue depth
5. **Check finalizers** - For stuck objects

---

# Questions?

---
