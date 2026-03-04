# SYSTEM DESIGN INTERVIEW: Distributed Cache System
**Redis / Memcached at Hyperscale**

> **Staff Software Engineer — FANG Interview Prep**
>
> High-Level System Design Round
>
> *Architecture • Deep Dives • Flow Diagrams • Trade-offs • Failure Analysis*

**Covers:** Consistent Hashing • Eviction Policies • Replication • Cluster Topologies • Write Strategies • Hot Keys • Cache Warming • Redis Internals

**Table of Contents**

---
## SECTION 1 — PROBLEM FRAMING & REQUIREMENTS
---

### 1. Problem Framing & Requirements
At the Staff level, interviewers expect you to frame why a distributed cache is needed before discussing what it does. The cache exists to solve three fundamental problems: database read amplification, latency at scale, and hot-spot traffic shielding.

> **Staff-Level Framing — Lead with the Problem**
>
> Without a cache: A social graph query touching 50M user records reads from a DB whose P99 is 20ms.
>
> At 100K RPS that is 100K concurrent DB reads. Most OLTP databases saturate at 10K-50K QPS.
>
> The cache absorbs 95%+ of reads, keeping DB QPS under 5K — well within its operating envelope.
>
> The core design challenge is not 'how to cache' but 'how to maintain cache correctness, handle failures, and scale consistently while the cache cluster itself evolves (resharding, node failures, rolling deploys)'.

#### 1.1 Functional Requirements
**Core Operations (P0)**
* **GET(key) → value**: Read a value by key; return null on miss.
* **SET(key, value, ttl)**: Write a key with an optional time-to-live expiry.
* **DELETE(key)**: Explicit key eviction/invalidation.
* **EXISTS(key)**: Check key presence without reading value.
* **EXPIRE(key, ttl)**: Set or update the TTL on an existing key.

**Extended Operations (P1)**
* **Atomic counter operations**: `INCR`, `DECR`, `INCRBY` — for rate limiting, counters.
* **Batch operations**: `MGET(keys[])`, `MSET(kvs[])` — reduce round trips.
* **GETSET / Compare-and-Swap**: Atomic read-then-write for distributed locking.
* **Data structure support**: Lists, Sets, Sorted Sets, Hashes, Bitmaps (Redis-style).
* **Pub/Sub messaging**: Publish to channels, subscribe to keys for invalidation events.
* **Lua scripting**: Atomic multi-step operations via server-side scripts.
* **Namespace isolation**: Logical database separation (Redis DB index) or key-prefix namespacing.

**Operational Requirements (P0)**
* **High availability**: No single point of failure; survive node loss without data loss.
* **Horizontal scalability**: Add capacity by adding nodes without downtime.
* **Cluster management**: Automatic failover, rebalancing, health detection.
* **Observability**: Hit/miss ratio, eviction rate, memory pressure, latency percentiles per keyspace.

#### 1.2 Non-Functional Requirements
| Requirement | Target | Justification |
| :--- | :--- | :--- |
| **Read Latency (P99)** | < 1 ms | Cache must be faster than DB by 10-100x to justify complexity. |
| **Write Latency (P99)** | < 5 ms | Writes include replication acknowledgment. |
| **Throughput** | 1M+ ops/second per cluster | Aggregate across all nodes; single Redis node ~100K ops/s. |
| **Availability** | 99.999% (5.26 min/year) | Cache unavailability directly degrades product experience. |
| **Data Capacity** | 1 TB–10 TB per cluster | Driven by working set size of the application layer. |
| **Consistency** | Tunable (eventual to strong) | Application chooses based on use case. |
| **Durability** | Optional (configurable) | Pure caches: none. Session stores: required. |
| **Replication Lag** | < 10 ms | Near-synchronous replication for hot standby. |

#### 1.3 Cache Use Cases Taxonomy
| Use Case | Key Pattern | TTL | Consistency Req. | Example |
| :--- | :--- | :--- | :--- | :--- |
| **DB Query Result Cache** | `query:{hash}` | 5–60 min | Eventual OK | `SELECT * FROM users WHERE id=123`. |
| **Session Store** | `session:{token}` | 30 min sliding | Strong | User auth JWT / server-side session. |
| **Rate Limiter** | `rl:{user}:{window}` | 1–60 sec fixed | Strong (atomic) | API throttle: 100 req/min/user. |
| **Distributed Lock** | `lock:{resource}` | Seconds | Strong (CAS) | Mutex for distributed cron jobs. |
| **Leaderboard / Rank** | `lb:{game}:{period}` | Minutes | Eventual OK | Top 100 scores in real-time game. |
| **Feature Flags** | `ff:{flag}` | 1–5 min | Eventual OK | A/B test config, kill switches. |
| **Computed Aggregation** | `agg:{metric}:{window}`| Minutes–hours | Eventual OK | DAU count, trending hashtags. |
| **Object Cache** | `obj:{type}:{id}` | Variable | Eventual OK | User profile, product catalog item. |

---
## SECTION 2 — CAPACITY ESTIMATION
---

### 2. Capacity Estimation
Capacity drives the number of shards, replication factor, and memory per node. Always estimate the working set, not the full dataset — only hot data belongs in cache.

**2.1 Assumptions**
* Target service: Social media platform — 500M DAU, 1B registered users.
* Cacheable data: User profiles, friend lists, timeline posts, session tokens, rate limit counters.
* Desired cache hit rate: 95% (i.e., only 5% of requests reach the database).
* Average cached object size: 2 KB (mix of small tokens and larger profile JSON).
* Working set (hot data): Top 20% of objects account for 80% of reads (Pareto principle).

> **Working Set Size Calculation**
>
> * Total cacheable objects = 1B users x 5 objects/user = 5 billion objects.
> * Hot working set (20%) = 1 billion objects.
> * Memory per object = 2 KB avg + 200 bytes overhead = ~2.2 KB.
> * Raw working set memory = 1B x 2.2 KB = 2.2 TB.
> * With replication (3x) = 6.6 TB raw storage across cluster.
> * With 25% headroom = **~8.25 TB total cluster RAM required**.
> * Node sizing: 128 GB RAM per node (production cache node).
> * Nodes required = 8.25 TB / 128 GB = ~66 nodes.
> * Recommended: 72 nodes (24 shards x 3 replicas).

**2.2 QPS & Bandwidth**
* **Peak read RPS**: 500M DAU x 50 reads/day / 86,400s x 10 peak factor = ~3M reads/second.
* **Cache absorbs 95%**: Cache QPS = 2.85M reads/sec; DB QPS = 150K reads/sec.
* **Write RPS**: ~300K writes/second (cache invalidation + new session creation).
* **Network bandwidth per node (72 nodes)**: 3.15M ops/s / 72 = ~44K ops/s per node.
* **Bandwidth**: 44K x 2.2 KB average = ~97 MB/s per node — within 10 GbE NIC capacity.

**2.3 Cluster Sizing Summary**
| Parameter | Value | Notes |
| :--- | :--- | :--- |
| **Total cluster RAM** | 8.25 TB | Working set + replication + headroom. |
| **Nodes (128 GB each)** | 72 nodes | 24 primary shards x 3 replicas = 72. |
| **Peak cluster QPS** | 3.15M ops/sec | 2.85M reads + 300K writes. |
| **Per-node QPS** | ~44K ops/sec | Well under single-node 100K limit. |
| **Network per node** | ~97 MB/s | Fits within 10 GbE (1.25 GB/s). |
| **Keyspace per shard** | ~42M keys | 1B hot keys / 24 primary shards. |
| **CPU per node** | 8–16 cores | Redis uses threads for async ops. |

---
## SECTION 3 — HIGH-LEVEL ARCHITECTURE
---

### 3.1 System Architecture Overview
The distributed cache sits between the application layer and the database layer. Clients use a routing layer that maps keys to shards via consistent hashing.


> **Figure 1: Distributed Cache System Architecture**
>
> ```text
> APPLICATION TIER
> ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
> │ App Svc A   │ │ App Svc B   │ │ App Svc C   │ │ App Svc D   │
> └──────┬──────┘ └──────┬──────┘ └──────┬──────┘ └──────┬──────┘
>        │               │               │               │
> ┌──────┴───────────────┴───────────────┴───────────────┴──────┐
> │ Cache Client Library                                        │
> │ (Consistent hashing, connection pool, retry, circuit breaker)│
> └──────────────────────────────┬──────────────────────────────┘
>                                ▼
>           ROUTING LAYER (embedded in client OR proxy)
> ┌─────────────────────────────────────────────────────────────┐
> │            CONSISTENT HASH RING (Virtual Nodes)             │
> └──────┬──────────┬──────────┬──────────┬──────────┬──────────┘
>        │          │          │          │          │
> CACHE CLUSTER (24 primary shards, each with 2 replicas)
> ┌────────▼───┐ ┌────▼───────┐ ┌───▼────────┐ ┌────▼───────┐
> │  SHARD 0   │ │  SHARD 1   │ │  SHARD 2   │ │  SHARD 3   │ ...
> │ Primary R/W│ │ Primary R/W│ │ Primary R/W│ │ Primary R/W│
> │ Replica 1  │ │ Replica 1  │ │ Replica 1  │ │ Replica 1  │
> └────────────┘ └────────────┘ └────────────┘ └────────────┘
> ```

**3.2 Client Library Architecture**
The intelligence lives in the client library, which performs hashing, manages connections, and implements local L1 caching.

> **Figure 2: Cache Client Library Architecture**
>
> 1. **L1 Local Cache**: In-process LRU (64–512 MB). Short TTL (1–10s).
> 2. **Hash Ring Router**: Maps key → shard using MurmurHash3. Uses virtual nodes.
> 3. **Connection Pool**: Persistent TCP connections (10–50 per shard).
> 4. **Circuit Breaker**: Opens if error rate > 10% in 10s window. Fail-fast to DB.
> 5. **Retry & Timeout Logic**: 2ms cache timeout; exponential backoff.

---
## SECTION 4 — CONSISTENT HASHING DEEP DIVE
---

### 4. Consistent Hashing
Consistent hashing avoids the "Massive Cache Miss Storm" by ensuring only ~1/N keys remap when nodes change.

> **Figure 3: Why Consistent Hashing vs. Modular Hashing**
>
> * **Modular:** `shard = hash(key) % N`. Adding 1 node to 100 nodes remaps 99% of keys.
> * **Consistent:** Adding 1 node to a 24-shard cluster results in only 1/25 (4%) of keys moving.

> **Figure 4: Consistent Hash Ring with Virtual Nodes**
>
> ```text
> 0 (Hash space: 0 to 2^32 - 1)
>    ┌──────────────┐
>    │  HASH RING   │
>    └──────────────┘
> Each physical node gets V virtual nodes (V=150 typical).
> Virtual node labels: 'N1:0', 'N1:1', ..., 'N1:149'.
> ```

---
## SECTION 5 — EVICTION POLICIES DEEP DIVE
---

### 5. Eviction Policies
| Policy | Algorithm | Best For | Weakness |
| :--- | :--- | :--- | :--- |
| **LRU** | DLL + HashMap | Temporal access patterns | Scan pollution. |
| **LFU** | Frequency Buckets | Long-lived popularity | New items disadvantaged. |
| **TTL** | Expire Heap | Time-bounded data | No memory control. |
| **CLOCK** | Circular Array | Page replacement | Lower precision. |

---
## SECTION 6 — CACHE WRITE STRATEGIES
---

### 6.1 Cache-Aside (Lazy Loading)
* **Read Path**: Check cache. On miss, read from DB and populate cache.
* **Write Path**: Update DB first, then **DELETE** the cache key (to avoid race conditions).

### 6.2 Write-Through
* **Write Path**: Application writes to cache; cache synchronously writes to DB. Both must ACK.
* **Pros**: Strong consistency. Cache is always warm.

### 6.3 Write-Behind (Write-Back)
* **Write Path**: Application writes to cache and returns immediately (~0.5ms). Cache flushes to DB asynchronously.
* **Trade-off**: High performance but risks data loss if the cache crashes before flushing.

---
## SECTION 7 — TECHNOLOGY STACK
---

| Component | Technology | Purpose |
| :--- | :--- | :--- |
| **Primary store** | Redis 7.x Cluster | In-memory KV; data structures. |
| **KV Only** | Memcached 1.6+ | Pure cache; ultra-high throughput. |
| **Coordination** | etcd / ZooKeeper | Membership, leader election. |
| **L1 Cache** | Caffeine / LRU-Cache | In-process hot key cache. |
| **Invalidation** | Kafka + Debezium | CDC-based reliable invalidation. |
| **Tracing** | Jaeger / AWS X-Ray | Trace cache-miss fallback paths. |

*--- End of Document ---*