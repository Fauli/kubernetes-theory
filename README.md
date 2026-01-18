# Kubernetes Operator Theory

Presentation materials for Kubernetes operator developers.

## Quick Start

```bash
./run.sh          # Interactive menu
./run.sh operator # Direct launch
./run.sh 2        # By number
```

Opens the presentation at [http://localhost:1948](http://localhost:1948)

## Presentations

| # | File | Topic | Status |
|---|------|-------|--------|
| 1 | `operator-presentation.md` | Kubernetes Operator Internals | Complete |
| 2 | `crd-design.md` | CRD Design Patterns | Complete |
| 3 | `testing-operators.md` | Testing Operators | Complete |
| 4 | `debugging-operators.md` | Debugging Operators | Outline |
| 5 | `admission-webhooks.md` | Admission Webhooks | Outline |

**Shortcuts:** `operator`, `crd`, `testing`, `debugging`, `webhooks`

## Contents

| File | Description |
|------|-------------|
| `kubernetes-theme.css` | Custom Kubernetes-themed styling |
| `demos/` | Live demo scripts for key concepts |
| `images/` | Presentation images |
| `build.sh` | Export to static HTML |

## Live Demos

Run during the operator presentation to reinforce concepts:

```bash
./demos/level-triggered.sh        # Pod recreation (state vs events)
./demos/finalizers.sh             # Deletion as state
./demos/gc-cascade.sh             # Garbage collection
./demos/watch-resourceversion.sh  # Watch streams
./demos/conflict-409.sh           # Optimistic concurrency
./demos/ssa-ownership.sh          # Server-Side Apply
```

## Requirements

- [reveal-md](https://github.com/webpro/reveal-md): `npm install -g reveal-md`
- `kubectl` with cluster access (for demos)
