# Technical Decisions Log

This log now tracks the Catalog Audit implementation only. Inventory-era entries were retired with the pivot so the file stays useful in interviews and in future context sessions.

---

## TD-001: Tenant Isolation via `acts_as_tenant`

**Date:** 2026-04-14
**Decision:** Scope all catalog data to the current `Shop` using `acts_as_tenant`.
**Why:** The app is multi-tenant by nature. Tenant scoping at the ORM boundary makes cross-shop leakage much harder to introduce accidentally.
**Trade-off:** Cross-tenant admin queries are more awkward, but the safety benefit outweighs that cost.

---

## TD-002: Embedded Shopify App Shell

**Date:** 2026-04-14
**Decision:** Keep the product embedded inside Shopify Admin and use Shopify OAuth/session auth as the public entry point.
**Why:** The product should feel native to a merchant and demonstrate Shopify platform fluency without adding a second app shell.
**Trade-off:** Embedded auth and iframe constraints add some complexity, but they are the right constraints for a Shopify portfolio project.

---

## TD-003: Encrypt Shopify Access Tokens

**Date:** 2026-04-14
**Decision:** Keep `Shop` access tokens encrypted at rest.
**Why:** Tokens grant direct store access. Encryption reduces the blast radius if the database is exposed.
**Trade-off:** Requires the Rails master key to decrypt in runtime, but that is the correct security model.

---

## TD-004: One Sync Path, One Audit Path

**Date:** 2026-04-14
**Decision:** Keep catalog sync and catalog audit as the only substantive backend workflows.
**Why:** The product needs to stay explainable and small. One task per service is easier to reason about, test, and maintain than the old inventory stack.
**Trade-off:** Fewer automated side systems in v1, but much lower complexity and a clearer code story.

---

## TD-005: Compute Issues From Current Catalog State

**Date:** 2026-04-14
**Decision:** Derive audit issues from the current synced product and variant data instead of building a broad historical subsystem.
**Why:** The user need is immediate visibility into catalog quality, not a long-lived warehouse of inventory history.
**Trade-off:** Less historical richness in v1, but faster implementation and a cleaner product surface.

---

## TD-006: Session Continuity Files as Durable Context

**Date:** 2026-04-14
**Decision:** Maintain `ACTIVE_CONTEXT.md`, `AGENT_WORKBOARD.md`, and `CRITIC_LOG.md` as durable session memory.
**Why:** The repo should be resumable from files alone, even after a chat or agent session ends.
**Trade-off:** A little extra documentation work each round, but much better handoff quality.

---

## TD-007: High-Signal LLM Comment Blocks

**Date:** 2026-04-14
**Decision:** Require short context-recovery comment blocks around non-obvious code paths.
**Why:** Future sessions need fast intent reconstruction when reading the codebase cold.
**Trade-off:** Slightly more inline documentation, but only where it helps explain non-obvious contracts.

