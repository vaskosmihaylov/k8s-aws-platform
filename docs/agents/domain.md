# Domain documentation

This repository uses a single platform context.

- Domain vocabulary belongs in root `CONTEXT.md`, created lazily when a term needs a durable definition.
- Existing architectural decisions live under `decisions/`; keep using that directory instead of creating a second ADR tree.
- Read relevant decisions and operating docs before changing Terraform, Argo CD, platform Helm values, or application overlays.
- `CONTEXT.md` contains vocabulary, not implementation detail. Specs and operational procedures belong in their existing documentation surfaces.
