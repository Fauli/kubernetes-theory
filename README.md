# Kubernetes Internals: From YAML to Reconciliation

A deep-dive presentation for future Kubernetes operator developers.

## Quick Start

```bash
./run.sh
```

Opens the presentation at [http://localhost:1948](http://localhost:1948)

## Contents

| File | Description |
|------|-------------|
| `operator-presentation.md` | Main presentation (reveal-md format) |
| `kubernetes-theme.css` | Custom Kubernetes-themed styling |
| `demos/` | Live demo scripts for key concepts |
| `images/` | Presentation images |

## Live Demos

Run during the presentation to reinforce concepts:

```bash
./demos/level-triggered.sh    # Pod recreation (state vs events)
./demos/finalizers.sh         # Deletion as state
./demos/gc-cascade.sh         # Garbage collection
./demos/watch-resourceversion.sh  # Watch streams
./demos/conflict-409.sh       # Optimistic concurrency
./demos/ssa-ownership.sh      # Server-Side Apply
```

## Requirements

- [reveal-md](https://github.com/webpro/reveal-md): `npm install -g reveal-md`
- `kubectl` with cluster access (for demos)
