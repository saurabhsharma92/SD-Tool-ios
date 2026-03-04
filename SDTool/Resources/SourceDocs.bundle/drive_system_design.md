**SYSTEM DESIGN INTERVIEW**

**File Upload & Hosting Service**

*Dropbox / Google Drive at Scale*

+-----------------------------------------------------------------------+
| **Senior Software Engineer --- FANG Interview Prep**                  |
|                                                                       |
| High-Level System Design Round                                        |
|                                                                       |
| *Architecture • Deep Dives • Flow Diagrams • Trade-offs*              |
+-----------------------------------------------------------------------+

Covers: Upload Pipeline • Chunking & Deduplication • Sync Engine •
Storage Tiers • Collaboration • CDN • Security

**Table of Contents**

  -----------------------------------------------------------------------
  **SECTION 1 --- REQUIREMENTS GATHERING**

  -----------------------------------------------------------------------

**1. Requirements Gathering**

Spend the first 5--8 minutes of the interview on requirements. The file
storage domain is deceptively broad --- Google Drive, Dropbox, iCloud,
and OneDrive share a surface-level description but have very different
design priorities. Nail the scope before touching a whiteboard.

+-----------------------------------------------------------------------+
| **Interview Tip --- Questions to Ask**                                |
|                                                                       |
| What is the primary use case: personal storage, enterprise            |
| collaboration, or developer API?                                      |
|                                                                       |
| Do we need real-time co-editing (Google Docs) or just sync + share    |
| (Dropbox)?                                                            |
|                                                                       |
| What is the expected max file size? 1 GB? 5 GB? 100 GB video files?   |
|                                                                       |
| Do we need versioning? How many versions should we retain?            |
|                                                                       |
| Is deduplication across users (global dedup) in scope?                |
|                                                                       |
| What platforms: web, desktop sync client, mobile?                     |
+-----------------------------------------------------------------------+

**1.1 Functional Requirements**

**Core (P0 --- Must Have)**

-   File Upload: Users can upload any file type up to 5 GB per file via
    web or desktop client

-   File Download: Users can download any of their stored files at any
    time

-   File Management: Create folders, rename, move, copy, and delete
    files/folders

-   File Sharing: Generate shareable links (view-only or edit); share
    with specific users by email

-   File Sync: Desktop client automatically syncs local file changes to
    the cloud and across devices

-   Conflict Resolution: When the same file is edited on two devices
    simultaneously, produce a conflict copy

-   File Versioning: Retain last 30 versions of each file; users can
    restore any prior version

-   File Search: Full-text search across filenames and document content
    (PDF, DOCX, TXT)

**Extended (P1 --- Should Have)**

-   Chunked / Resumable Upload: Large files split into chunks;
    interrupted uploads resume from last checkpoint

-   Delta Sync: Only the changed portion (bytes) of a modified file is
    uploaded, not the whole file

-   Real-time Collaboration: Multiple users can edit a Google-Doc-style
    document simultaneously (OT/CRDT)

-   Offline Support: Desktop/mobile client works offline; changes queue
    and sync when back online

-   Storage Quotas: Per-user storage limits (e.g., 15 GB free tier, paid
    tiers for more)

-   Thumbnail & Preview: Generate image thumbnails, PDF previews, video
    stills inline

-   Audit Log: Record all file events (upload, download, share, delete)
    for compliance

**Out of Scope (for this interview)**

-   Real-time rich text co-editing (Google Docs internals --- CRDT/OT is
    a separate design)

-   Payments and billing infrastructure

-   Machine learning features (smart search, photo recognition)

**1.2 Non-Functional Requirements**

  -----------------------------------------------------------------------
  **Requirement**     **Target**          **Justification**
  ------------------- ------------------- -------------------------------
  Availability        99.99% (52 min      Storage is mission-critical;
                      downtime/year)      data loss is catastrophic

  Durability          99.999999999% (11   Files must never be lost ---
                      nines)              multi-region replication

  Upload Latency      \< 200 ms to first  User experience; background
                      byte accepted       upload queuing

  Download Latency    \< 500 ms TTFB via  CDN edge cache for hot files
  (P99)               CDN                 

  Throughput          10 GB/s aggregate   500K DAU × 20 MB avg daily
                      upload across fleet upload

  Consistency         Strong for          Metadata needs ACID; blob
                      metadata; eventual  propagation can lag
                      for blobs           

  Scalability         Horizontal; handle  Launch day / viral sharing
                      10x traffic spikes  events

  Security            Encryption at rest  Regulatory compliance; user
                      (AES-256) and in    trust
                      transit (TLS 1.3)   

  Data Isolation      Multi-tenant with   No user can access another\'s
                      strict isolation    private files
  -----------------------------------------------------------------------

  -----------------------------------------------------------------------
  **SECTION 2 --- CAPACITY ESTIMATION & SCALE**

  -----------------------------------------------------------------------

**2. Capacity Estimation**

Always state your assumptions explicitly. Interviewers want to see your
reasoning process, not just numbers.

**2.1 Traffic Estimation**

**Assumptions**

-   Total registered users: 500 million

-   Daily Active Users (DAU): 100 million (20% of registered)

-   Average files uploaded per DAU per day: 2

-   Average file size: 500 KB (mix of documents, images, and large
    files)

-   Read-to-write ratio: 10:1 (files read more often than written)

+-----------------------------------------------------------------------+
| **Back-of-the-Envelope Calculation**                                  |
|                                                                       |
| Daily uploads = 100M DAU × 2 files = 200 million files/day            |
|                                                                       |
| Upload RPS = 200M / 86,400 = \~2,315 writes/second (avg)              |
|                                                                       |
| Peak upload RPS = 2,315 × 3 (peak factor) = \~7,000 writes/second     |
|                                                                       |
| Download RPS = 7,000 × 10 (read:write) = \~70,000 reads/second        |
|                                                                       |
| Metadata ops/sec = 70,000 + 7,000 = \~77,000 ops/second               |
+-----------------------------------------------------------------------+

**2.2 Storage Estimation**

**File Storage (Object Store)**

-   New data per day: 200M files × 500 KB = 100 TB/day

-   Replication factor: 3x (for durability) → 300 TB raw/day

-   Annual growth: 100 TB × 365 = \~36.5 PB/year (before replication)

-   With deduplication savings (\~30%): net \~26 PB/year

**Metadata Storage (Relational / Key-Value)**

-   Per file metadata: \~2 KB (name, path, size, hash, timestamps, ACLs,
    version pointers)

-   Files stored after 5 years: 200M/day × 365 × 5 = \~365 billion file
    records

-   Metadata storage: 365B × 2 KB = \~730 TB --- requires sharded
    relational DB

**Version Storage**

-   30 versions per file average, but most files have \< 5 versions

-   Effective version overhead: \~2x on modified files

-   Deduplication of unchanged chunks reduces version overhead
    dramatically (delta storage)

**2.3 Bandwidth Estimation**

-   Inbound (upload): 7,000 RPS × 500 KB avg = 3.5 GB/s inbound
    bandwidth

-   Outbound (download): 70,000 RPS × 500 KB avg = 35 GB/s outbound

-   CDN offload (\~80%): Origin outbound = 7 GB/s --- manageable

-   Peak outbound with CDN edge: \~175 GB/s across all CDN PoPs globally

  -----------------------------------------------------------------------
  **SECTION 3 --- HIGH-LEVEL ARCHITECTURE**

  -----------------------------------------------------------------------

**3. High-Level Architecture**

The architecture separates three core concerns: (1) the control plane
--- metadata, auth, and coordination; (2) the data plane --- raw file
bytes stored in object storage; and (3) the sync engine --- keeping
clients consistent. This separation allows each to scale independently.

+-----------------------------------------------------------------------+
| **Figure 1: High-Level System Architecture**                          |
|                                                                       |
| ┌──────────                                                           |
| ────────────────────────────────────────────────────────────────────┐ |
|                                                                       |
| │ FILE HOSTING SERVICE --- SYSTEM OVERVIEW │                          |
|                                                                       |
| └──────────                                                           |
| ────────────────────────────────────────────────────────────────────┘ |
|                                                                       |
| CLIENT TIER                                                           |
|                                                                       |
| ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐   |
|                                                                       |
| │ Web Browser │ │Desktop Client│ │ Mobile App │ │ SDK / API │         |
|                                                                       |
| │ (React SPA) │ │(Electron/Qt) │ │(iOS/Android) │ │ (3rd party) │     |
|                                                                       |
| └──────┬───────┘ └──────┬───────┘ └──────┬───────┘ └──────┬───────┘   |
|                                                                       |
| └─────────────────┴──────────────────┴─────────────────┘              |
|                                                                       |
| │                                                                     |
|                                                                       |
| TLS 1.3 / HTTPS                                                       |
|                                                                       |
| │                                                                     |
|                                                                       |
| EDGE / INGRESS                                                        |
|                                                                       |
| ┌─────                                                                |
| ────────────────────────────▼───────────────────────────────────────┐ |
|                                                                       |
| │ CDN + API GATEWAY (CloudFront / Cloudflare + Kong) │                |
|                                                                       |
| │ SSL termination • Rate limiting • Auth token validation • Routing │ |
|                                                                       |
| └─────                                                                |
| ─────┬───────────────────────┬──────────────────────────────────────┘ |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ (Control Plane) │ (Data Plane)                                      |
|                                                                       |
| ┌──────────▼──────────┐                                               |
| ┌─────────▼──────────────────────────────────┐                        |
|                                                                       |
| │ API GATEWAY / │ │ UPLOAD SERVICE │                                  |
|                                                                       |
| │ METADATA SERVICE │ │ (Chunking, Resumable, Dedup, Presigned) │      |
|                                                                       |
| │ │ └────────────────┬───────────────────────────┘                    |
|                                                                       |
| │ • Auth Service │ │                                                  |
|                                                                       |
| │ • File Metadata DB │ ┌────────────────▼───────────────────────────┐ |
|                                                                       |
| │ • Share Service │ │ OBJECT STORAGE LAYER │                          |
|                                                                       |
| │ • Search Service │ │ (S3 / GCS / Azure Blob + MinIO internal) │     |
|                                                                       |
| │ • Quota Service │ │ Hot / Warm / Cold Storage Tiers │               |
|                                                                       |
| └──────────┬──────────┘                                               |
| └────────────────┬───────────────────────────┘                        |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| ┌──────────▼──────────┐                                               |
| ┌────────────────▼───────────────────────────┐                        |
|                                                                       |
| │ SYNC ENGINE │ │ BACKGROUND WORKERS │                                |
|                                                                       |
| │ (Delta tracking, │ │ • Thumbnail/Preview Generator │                |
|                                                                       |
| │ conflict detect, │ │ • Virus Scanner │                              |
|                                                                       |
| │ change notify) │ │ • Content Indexer (Search) │                     |
|                                                                       |
| └──────────┬──────────┘ │ • Storage Tier Migrator │                   |
|                                                                       |
| │ │ • Replication Verifier │                                          |
|                                                                       |
| MESSAGE BUS│ └─────────────────────────────────────────────┘          |
|                                                                       |
| ┌──                                                                   |
| ────────▼───────────────────────────────────────────────────────────┐ |
|                                                                       |
| │ Apache Kafka / Google Pub/Sub │                                     |
|                                                                       |
| │ Topics: file-events, sync-notifications, audit-log, search-index │  |
|                                                                       |
| └──                                                                   |
| ────────────────────────────────────────────────────────────────────┘ |
|                                                                       |
| │                                                                     |
|                                                                       |
| ┌──────────────┐ ┌──────────▼──────────┐ ┌────────────────────────┐   |
|                                                                       |
| │ Metadata DB │ │ Notification │ │ Search Index │                     |
|                                                                       |
| │ (PostgreSQL │ │ Service (WebSocket │ │ (Elasticsearch) │            |
|                                                                       |
| │ + Citus) │ │ + Push/SSE) │ │ │                                      |
|                                                                       |
| └──────────────┘ └─────────────────────┘ └────────────────────────┘   |
+-----------------------------------------------------------------------+

**3.1 Key Architectural Principles**

**1. Separate Control Plane from Data Plane**

The metadata (what files exist, who owns them, sharing ACLs) never flows
through the same path as raw bytes. This allows the metadata service to
be a strongly-consistent relational system while the object storage
layer optimizes purely for throughput and durability.

**2. Client-Side Chunking Before Upload**

Files are split into fixed-size chunks (4 MB default) on the client
before transmission. Each chunk is hashed (SHA-256). The server checks
which chunks already exist (deduplication) so only novel chunks are
actually transferred --- the core of Dropbox\'s performance advantage.

**3. Asynchronous Processing Pipeline**

Heavy operations (thumbnail generation, virus scanning, content
indexing, replication verification) are decoupled from the upload
critical path via Kafka. Upload returns success once chunks are durably
written; enrichment happens asynchronously.

  -----------------------------------------------------------------------
  **SECTION 4 --- DATA MODELS & DATABASE DESIGN**

  -----------------------------------------------------------------------

**4. Data Models & Database Design**

The metadata layer is the heart of the system. It must support complex
hierarchical queries (folder trees), ACL lookups, version history, and
sharing --- all with strong consistency. Raw file content lives entirely
in the object store, referenced only by content-hash.

**4.1 Core Entity Schemas**

**Users & Accounts**

+-----------------------------------------------------------------------+
| **User Schema**                                                       |
|                                                                       |
| TABLE: users                                                          |
|                                                                       |
| ───────────────────────────────────────────────────────               |
|                                                                       |
| user_id UUID PRIMARY KEY                                              |
|                                                                       |
| email VARCHAR(320) UNIQUE NOT NULL                                    |
|                                                                       |
| display_name VARCHAR(128)                                             |
|                                                                       |
| password_hash VARCHAR(256) \-- Argon2id                               |
|                                                                       |
| storage_used_bytes BIGINT DEFAULT 0                                   |
|                                                                       |
| storage_quota_bytes BIGINT DEFAULT 15_000_000_000 \-- 15 GB           |
|                                                                       |
| plan ENUM \-- FREE, PRO, BUSINESS, ENTERPRISE                         |
|                                                                       |
| created_at TIMESTAMPTZ                                                |
|                                                                       |
| last_login_at TIMESTAMPTZ                                             |
|                                                                       |
| mfa_enabled BOOLEAN                                                   |
|                                                                       |
| ───────────────────────────────────────────────────────               |
|                                                                       |
| INDEX: email (login)                                                  |
+-----------------------------------------------------------------------+

**Files & Folders --- the Namespace**

+-----------------------------------------------------------------------+
| **Nodes (Files + Folders) Schema**                                    |
|                                                                       |
| TABLE: nodes (unified table for both files and folders)               |
|                                                                       |
| ─────────────────────────────────────────────────────────────────     |
|                                                                       |
| node_id UUID PRIMARY KEY                                              |
|                                                                       |
| owner_id UUID FK -\> users.user_id                                    |
|                                                                       |
| parent_id UUID FK -\> nodes.node_id (NULL = root)                     |
|                                                                       |
| name VARCHAR(1024) NOT NULL                                           |
|                                                                       |
| node_type ENUM \-- FILE \| FOLDER                                     |
|                                                                       |
| size_bytes BIGINT \-- 0 for folders                                   |
|                                                                       |
| mime_type VARCHAR(128)                                                |
|                                                                       |
| current_version INTEGER DEFAULT 1                                     |
|                                                                       |
| content_hash VARCHAR(64) \-- SHA-256 of full file (NULL for folders)  |
|                                                                       |
| is_deleted BOOLEAN DEFAULT FALSE \-- soft delete (trash)              |
|                                                                       |
| deleted_at TIMESTAMPTZ                                                |
|                                                                       |
| created_at TIMESTAMPTZ DEFAULT NOW()                                  |
|                                                                       |
| modified_at TIMESTAMPTZ DEFAULT NOW()                                 |
|                                                                       |
| ─────────────────────────────────────────────────────────────────     |
|                                                                       |
| UNIQUE (owner_id, parent_id, name) WHERE NOT is_deleted               |
|                                                                       |
| INDEX: (owner_id, parent_id) \-- list folder contents                 |
|                                                                       |
| INDEX: (content_hash) \-- dedup / version lookups                     |
|                                                                       |
| NOTE: We use the Closure Table pattern for deep folder hierarchies    |
|                                                                       |
| (see Section 4.2 for details)                                         |
+-----------------------------------------------------------------------+

**File Versions**

+-----------------------------------------------------------------------+
| **File Versions Schema**                                              |
|                                                                       |
| TABLE: file_versions                                                  |
|                                                                       |
| ─────────────────────────────────────────────────────────────────     |
|                                                                       |
| version_id UUID PRIMARY KEY                                           |
|                                                                       |
| node_id UUID FK -\> nodes.node_id                                     |
|                                                                       |
| version_number INTEGER NOT NULL                                       |
|                                                                       |
| size_bytes BIGINT                                                     |
|                                                                       |
| content_hash VARCHAR(64) \-- SHA-256 of full file                     |
|                                                                       |
| storage_path VARCHAR(512) \-- path in object store (or chunk manifest |
| ref)                                                                  |
|                                                                       |
| uploader_id UUID FK -\> users                                         |
|                                                                       |
| upload_device_id VARCHAR(64) \-- which device created this version    |
|                                                                       |
| created_at TIMESTAMPTZ                                                |
|                                                                       |
| is_current BOOLEAN DEFAULT TRUE                                       |
|                                                                       |
| delta_base_version_id UUID \-- for delta encoding reference           |
|                                                                       |
| ─────────────────────────────────────────────────────────────────     |
|                                                                       |
| PRIMARY KEY (node_id, version_number)                                 |
|                                                                       |
| RETENTION: versions older than 30 days (or \> 30 count) are purged    |
+-----------------------------------------------------------------------+

**Chunks (Content-Addressable Storage)**

+-----------------------------------------------------------------------+
| **Chunks & Chunk-Map Schema**                                         |
|                                                                       |
| TABLE: chunks (global, de-duplicated chunk registry)                  |
|                                                                       |
| ─────────────────────────────────────────────────────────────────     |
|                                                                       |
| chunk_hash VARCHAR(64) PRIMARY KEY \-- SHA-256                        |
|                                                                       |
| size_bytes INTEGER                                                    |
|                                                                       |
| storage_key VARCHAR(512) \-- S3 key: chunks/{hash\[0:2\]}/{hash}      |
|                                                                       |
| reference_count INTEGER DEFAULT 1 \-- \# of files referencing this    |
| chunk                                                                 |
|                                                                       |
| compressed_size INTEGER \-- after LZ4/Zstd compression                |
|                                                                       |
| created_at TIMESTAMPTZ                                                |
|                                                                       |
| ─────────────────────────────────────────────────────────────────     |
|                                                                       |
| TABLE: file_chunk_map (ordered mapping of file -\> chunks)            |
|                                                                       |
| ─────────────────────────────────────────────────────────────────     |
|                                                                       |
| version_id UUID FK -\> file_versions                                  |
|                                                                       |
| chunk_index INTEGER \-- 0-based sequence                              |
|                                                                       |
| chunk_hash VARCHAR(64) FK -\> chunks                                  |
|                                                                       |
| byte_offset BIGINT \-- start byte of this chunk in file               |
|                                                                       |
| PRIMARY KEY (version_id, chunk_index)                                 |
+-----------------------------------------------------------------------+

**Sharing & Permissions**

+-----------------------------------------------------------------------+
| **Shares & Permissions Schema**                                       |
|                                                                       |
| TABLE: shares                                                         |
|                                                                       |
| ─────────────────────────────────────────────────────────────────     |
|                                                                       |
| share_id UUID PRIMARY KEY                                             |
|                                                                       |
| node_id UUID FK -\> nodes                                             |
|                                                                       |
| shared_by UUID FK -\> users                                           |
|                                                                       |
| share_type ENUM \-- LINK \| USER \| GROUP                             |
|                                                                       |
| recipient_id UUID FK -\> users (NULL if LINK share)                   |
|                                                                       |
| permission ENUM \-- VIEWER \| COMMENTER \| EDITOR \| OWNER            |
|                                                                       |
| link_token VARCHAR(64) UNIQUE (hashed random token for URL shares)    |
|                                                                       |
| password_hash VARCHAR(256) \-- optional link password                 |
|                                                                       |
| expires_at TIMESTAMPTZ \-- NULL = no expiry                           |
|                                                                       |
| download_limit INTEGER \-- NULL = unlimited                           |
|                                                                       |
| download_count INTEGER DEFAULT 0                                      |
|                                                                       |
| created_at TIMESTAMPTZ                                                |
|                                                                       |
| ─────────────────────────────────────────────────────────────────     |
|                                                                       |
| INDEX: (node_id, share_type) \-- ACL checks                           |
|                                                                       |
| INDEX: (link_token) \-- public link resolution                        |
|                                                                       |
| INDEX: (recipient_id) \-- \'shared with me\' query                    |
+-----------------------------------------------------------------------+

**4.2 Folder Hierarchy: Closure Table Pattern**

A naive adjacency list (parent_id pointer) requires N recursive queries
to traverse a deep folder tree. Google Drive uses a Closure Table, which
pre-materializes all ancestor-descendant relationships for O(1) subtree
queries.

+-----------------------------------------------------------------------+
| **Figure 2: Closure Table for Folder Hierarchy**                      |
|                                                                       |
| CLOSURE TABLE for folder hierarchy:                                   |
|                                                                       |
| ─────────────────────────────────────────────────────────────────     |
|                                                                       |
| TABLE: node_closure                                                   |
|                                                                       |
| ancestor_id UUID FK -\> nodes                                         |
|                                                                       |
| descendant_id UUID FK -\> nodes                                       |
|                                                                       |
| depth INTEGER \-- 0 = self, 1 = direct child, 2 = grandchild \...     |
|                                                                       |
| PRIMARY KEY (ancestor_id, descendant_id)                              |
|                                                                       |
| Example: /Root/Work/Reports/Q4.pdf                                    |
|                                                                       |
| ─────────────────────────────────────────────────────────────────     |
|                                                                       |
| ancestor_id descendant_id depth                                       |
|                                                                       |
| Root Root 0                                                           |
|                                                                       |
| Root Work 1                                                           |
|                                                                       |
| Root Reports 2                                                        |
|                                                                       |
| Root Q4.pdf 3                                                         |
|                                                                       |
| Work Work 0                                                           |
|                                                                       |
| Work Reports 1                                                        |
|                                                                       |
| Work Q4.pdf 2                                                         |
|                                                                       |
| Reports Reports 0                                                     |
|                                                                       |
| Reports Q4.pdf 1                                                      |
|                                                                       |
| Q4.pdf Q4.pdf 0                                                       |
|                                                                       |
| ─────────────────────────────────────────────────────────────────     |
|                                                                       |
| Query all contents of /Root: SELECT descendant_id FROM node_closure   |
|                                                                       |
| WHERE ancestor_id = \'Root\' AND depth \> 0                           |
|                                                                       |
| Get full path of Q4.pdf: SELECT ancestor_id FROM node_closure         |
|                                                                       |
| WHERE descendant_id = \'Q4.pdf\' ORDER BY depth DESC                  |
+-----------------------------------------------------------------------+

**4.3 Database Technology Decisions**

  -----------------------------------------------------------------------
  **Store**          **Technology**     **Reason**
  ------------------ ------------------ ---------------------------------
  File/Folder        PostgreSQL + Citus ACID, complex joins, ACL queries;
  Metadata           (sharded)          Citus shards by owner_id

  Chunk Registry     PostgreSQL or      High-frequency dedup lookups by
                     DynamoDB           hash; DynamoDB for pure KV speed

  File Content       Amazon S3 / Google Industry-standard; 11-nines
  (blobs)            GCS                durability; lifecycle rules for
                                        tiering

  Session / Auth     Redis Cluster      Sub-ms TTL-based token validation
  Tokens                                

  Upload State       Redis + PostgreSQL Track chunk upload progress;
  (in-progress)                         persist for resumability

  Search Index       Elasticsearch      Full-text across filename +
                                        content; inverted index

  Change Feed /      Apache Kafka       Async processing pipeline; sync
  Events                                notification backbone

  Audit Log          Cassandra /        Append-only, high-write,
                     ClickHouse         time-series; compliance retention
  -----------------------------------------------------------------------

  -----------------------------------------------------------------------
  **SECTION 5 --- API DESIGN**

  -----------------------------------------------------------------------

**5. API Design**

The API surface is split into two groups: the Metadata API (control
plane, authenticated REST) and the Transfer API (data plane, often
token-scoped for direct cloud storage access). All requests carry a JWT
Bearer token; sharing links use a signed token in the query string.

**5.1 Authentication API**

+-----------------------------------------------------------------------+
| **Authentication Endpoints**                                          |
|                                                                       |
| POST /v1/auth/register Body: { email, password, display_name }        |
|                                                                       |
| POST /v1/auth/login Body: { email, password } → JWT + refresh         |
|                                                                       |
| POST /v1/auth/refresh Body: { refresh_token } → new JWT               |
|                                                                       |
| POST /v1/auth/logout Invalidates refresh token                        |
|                                                                       |
| POST /v1/auth/mfa/verify Body: { totp_code }                          |
|                                                                       |
| GET /v1/auth/devices List active sessions                             |
|                                                                       |
| DELETE /v1/auth/devices/{id} Remote logout                            |
+-----------------------------------------------------------------------+

**5.2 File & Folder (Namespace) API**

+-----------------------------------------------------------------------+
| **Namespace API Endpoints**                                           |
|                                                                       |
| ─── LISTING ────────────────────────────────────────────────────      |
|                                                                       |
| GET /v1/files List root; ?parent_id= for subfolders                   |
|                                                                       |
| Response: { items: \[Node\], next_cursor }                            |
|                                                                       |
| GET /v1/files/{node_id} Get single node metadata                      |
|                                                                       |
| GET /v1/files/{node_id}/path Get full path string                     |
|                                                                       |
| ─── FOLDER OPERATIONS ──────────────────────────────────────────      |
|                                                                       |
| POST /v1/folders Body: { name, parent_id }                            |
|                                                                       |
| PUT /v1/files/{id} Body: { name?, parent_id? } (rename/move)          |
|                                                                       |
| DELETE /v1/files/{id} Soft-delete (move to Trash)                     |
|                                                                       |
| POST /v1/files/{id}/restore Restore from Trash                        |
|                                                                       |
| DELETE /v1/files/{id}/permanent Hard-delete (irreversible)            |
|                                                                       |
| POST /v1/files/{id}/copy Body: { dest_parent_id, new_name? }          |
|                                                                       |
| ─── VERSIONS ───────────────────────────────────────────────────      |
|                                                                       |
| GET /v1/files/{id}/versions List all versions                         |
|                                                                       |
| POST /v1/files/{id}/versions/{v}/restore Restore to version v         |
|                                                                       |
| DELETE /v1/files/{id}/versions/{v} Delete a specific version          |
+-----------------------------------------------------------------------+

**5.3 Upload API (Data Plane)**

Upload uses a two-phase protocol. Phase 1 is a metadata handshake (what
am I about to upload?). Phase 2 is direct chunk transfer, often
bypassing application servers entirely via presigned URLs.

+-----------------------------------------------------------------------+
| **Upload API --- 3-Phase Protocol**                                   |
|                                                                       |
| ─── PHASE 1: INITIATE ──────────────────────────────────────────      |
|                                                                       |
| POST /v1/uploads/initiate                                             |
|                                                                       |
| Body: {                                                               |
|                                                                       |
| parent_id: \'folder-uuid\',                                           |
|                                                                       |
| filename: \'report.pdf\',                                             |
|                                                                       |
| size_bytes: 52428800, // 50 MB                                        |
|                                                                       |
| mime_type: \'application/pdf\',                                       |
|                                                                       |
| content_hash:\'sha256-of-full-file\', // for whole-file dedup check   |
|                                                                       |
| chunks: \[ // chunk manifest                                          |
|                                                                       |
| { index:0, hash:\'sha256\...\', size:4194304 },                       |
|                                                                       |
| { index:1, hash:\'sha256\...\', size:4194304 },                       |
|                                                                       |
| \...{ index:12, hash:\'sha256\...\', size:2097152 } // last chunk     |
| smaller                                                               |
|                                                                       |
| \]                                                                    |
|                                                                       |
| }                                                                     |
|                                                                       |
| Response: {                                                           |
|                                                                       |
| upload_id: \'upload-uuid\',                                           |
|                                                                       |
| existing_chunks: \[\'sha256\...\', \'sha256\...\'\], // chunks        |
| already in store                                                      |
|                                                                       |
| upload_urls: { // presigned S3 PUT URLs (5-min expiry)                |
|                                                                       |
| \'0\': \'https://s3.amazonaws.com/\...\',                             |
|                                                                       |
| \'3\': \'https://s3.amazonaws.com/\...\', // only novel chunks        |
|                                                                       |
| \...                                                                  |
|                                                                       |
| }                                                                     |
|                                                                       |
| }                                                                     |
|                                                                       |
| ─── PHASE 2: UPLOAD CHUNKS (Direct to Object Store) ────────────      |
|                                                                       |
| PUT {presigned_url} Binary chunk data                                 |
|                                                                       |
| Response: 200 OK (ETag header = chunk hash confirmation)              |
|                                                                       |
| ─── PHASE 3: COMPLETE ──────────────────────────────────────────      |
|                                                                       |
| POST /v1/uploads/{upload_id}/complete                                 |
|                                                                       |
| Body: { uploaded_chunks: \[ { index:0, etag:\'\...\' }, \... \] }     |
|                                                                       |
| Response: { node_id, version_id, file_url }                           |
|                                                                       |
| ─── RESUMABLE UPLOAD ────────────────────────────────────────────     |
|                                                                       |
| GET /v1/uploads/{upload_id}/status                                    |
|                                                                       |
| Response: { received_chunks: \[0,1,2,5\], missing_chunks:             |
| \[3,4,6..12\] }                                                       |
+-----------------------------------------------------------------------+

**5.4 Download API**

+-----------------------------------------------------------------------+
| **Download API**                                                      |
|                                                                       |
| GET /v1/files/{node_id}/download                                      |
|                                                                       |
| ?version={n} (optional; defaults to current)                          |
|                                                                       |
| Response: 302 Redirect → signed CDN URL (1-hour expiry)               |
|                                                                       |
| OR Range request for streaming large files                            |
|                                                                       |
| GET /v1/files/{node_id}/download?inline=true                          |
|                                                                       |
| For browser preview (PDF, images) --- serves with                     |
| Content-Disposition: inline                                           |
|                                                                       |
| GET /v1/share/{link_token}/download                                   |
|                                                                       |
| Public link download (no auth required; token validated)              |
|                                                                       |
| Range download (resumable):                                           |
|                                                                       |
| GET /v1/files/{node_id}/download                                      |
|                                                                       |
| Headers: Range: bytes=0-4194303 (chunk 0)                             |
|                                                                       |
| Range: bytes=4194304-8388607 (chunk 1)                                |
|                                                                       |
| Response: 206 Partial Content                                         |
+-----------------------------------------------------------------------+

**5.5 Sharing API**

+-----------------------------------------------------------------------+
| **Sharing API**                                                       |
|                                                                       |
| POST /v1/files/{id}/shares                                            |
|                                                                       |
| Body: { share_type:\'LINK\'\|\'USER\',                                |
| permission:\'VIEWER\'\|\'EDITOR\',                                    |
|                                                                       |
| recipient_email?, expires_at?, password?, download_limit? }           |
|                                                                       |
| Response: { share_id, link_url?, share_token? }                       |
|                                                                       |
| GET /v1/files/{id}/shares List shares on a node                       |
|                                                                       |
| PUT /v1/shares/{share_id} Update permission or expiry                 |
|                                                                       |
| DELETE /v1/shares/{share_id} Revoke share                             |
|                                                                       |
| GET /v1/files/shared-with-me Files others shared with you             |
|                                                                       |
| GET /v1/files/shared-by-me Files you have shared                      |
+-----------------------------------------------------------------------+

  -----------------------------------------------------------------------
  **SECTION 6 --- COMPONENT DEEP DIVES**

  -----------------------------------------------------------------------

**6. Component Deep Dives**

**6.1 Deep Dive: Chunked Upload & Content-Addressable Storage**

Chunking is the single most important design decision in a file storage
system. It enables resumability, deduplication, parallel upload, and
delta sync --- all at once. This is the core innovation behind
Dropbox\'s original architecture.

+-----------------------------------------------------------------------+
| **Figure 3: Chunked Upload Pipeline**                                 |
|                                                                       |
| CHUNKED UPLOAD PIPELINE --- End to End                                |
|                                                                       |
| ══════════════════════════════════════════════════════════════════    |
|                                                                       |
| CLIENT SIDE (before any network call):                                |
|                                                                       |
| ─────────────────────────────────────                                 |
|                                                                       |
| Large File (50 MB)                                                    |
|                                                                       |
| │                                                                     |
|                                                                       |
| ├── Chunk 0: bytes \[0 .. 4194303 \] SHA-256 → hash_0                 |
|                                                                       |
| ├── Chunk 1: bytes \[4194304 .. 8388607\] SHA-256 → hash_1            |
|                                                                       |
| ├── Chunk 2: bytes \[8388608 ..12582911\] SHA-256 → hash_2            |
|                                                                       |
| │ \... \...                                                           |
|                                                                       |
| └── Chunk 12: bytes\[50331648..52428799\] SHA-256 → hash_12           |
|                                                                       |
| Also compute: content_hash = SHA-256( hash_0 \|\| hash_1 \|\| \...    |
| \|\| hash_12 )                                                        |
|                                                                       |
| This is the \'Merkle-style\' root hash representing the whole file.   |
|                                                                       |
| STEP 1: Deduplication Check (POST /v1/uploads/initiate)               |
|                                                                       |
| ─────────────────────────────────────────────────────────             |
|                                                                       |
| Client sends chunk manifest: \[ (index, hash, size) × 13 \]           |
|                                                                       |
| Server queries chunks table: SELECT chunk_hash FROM chunks            |
|                                                                       |
| WHERE chunk_hash IN (\...all 13 hashes\...)                           |
|                                                                       |
| Response: existing = \[hash_0, hash_2, hash_5\] ← server already has  |
| these!                                                                |
|                                                                       |
| novel = \[hash_1, hash_3, hash_4, hash_6 \... hash_12\]               |
|                                                                       |
| Presigned PUT URLs generated ONLY for novel chunks                    |
|                                                                       |
| STEP 2: Parallel Chunk Upload (Direct to S3)                          |
|                                                                       |
| ─────────────────────────────────────────────                         |
|                                                                       |
| Client uploads novel chunks in parallel (up to 5 concurrent):         |
|                                                                       |
| PUT presigned_url_for_hash_1 ──────────────────────▶ S3               |
|                                                                       |
| PUT presigned_url_for_hash_3 ──────────────────────▶ S3               |
|                                                                       |
| PUT presigned_url_for_hash_4 ──────────────────────▶ S3               |
|                                                                       |
| (Each PUT is binary chunk data; S3 validates ETag = hash)             |
|                                                                       |
| STEP 3: Reassembly Manifest (POST /v1/uploads/{id}/complete)          |
|                                                                       |
| ──────────────────────────────────────────────────────────────        |
|                                                                       |
| Server inserts into file_chunk_map:                                   |
|                                                                       |
| version_id \| chunk_index \| chunk_hash \| byte_offset                |
|                                                                       |
| \-\-\-\-\-\-\-\-\-\--\|\-\-\-                                         |
| \-\-\-\-\-\-\-\-\--\|\-\-\-\-\-\-\-\-\-\-\--\|\-\-\-\-\-\-\-\-\-\-\-- |
|                                                                       |
| ver-001 \| 0 \| hash_0 \| 0                                           |
|                                                                       |
| ver-001 \| 1 \| hash_1 \| 4194304                                     |
|                                                                       |
| \... \| 12 \| hash_12 \| 50331648                                     |
|                                                                       |
| Increments reference_count for each chunk used.                       |
|                                                                       |
| Updates nodes.content_hash and file_versions.storage_path.            |
|                                                                       |
| Publishes file-events Kafka message → async workers.                  |
+-----------------------------------------------------------------------+

+-----------------------------------------------------------------------+
| **Why Content-Addressable Storage (CAS)?**                            |
|                                                                       |
| 1\. Global Deduplication: If 10,000 users upload the same PDF, only   |
| ONE copy is stored.                                                   |
|                                                                       |
| Storage cost: 1x instead of 10,000x. Dropbox reports 70%+ storage     |
| savings from dedup.                                                   |
|                                                                       |
| 2\. Integrity Checking: SHA-256 hash validates data correctness ---   |
| bit rot is instantly detected.                                        |
|                                                                       |
| 3\. Delta Sync: Modified file reuses unchanged chunks. Only changed   |
| chunks are re-uploaded.                                               |
|                                                                       |
| 4\. Immutability: Chunks are write-once, never mutated.               |
| Cache-forever, simplifies replication.                                |
|                                                                       |
| 5\. Garbage Collection: Reference counting on chunks enables safe     |
| cleanup of unreferenced data.                                         |
+-----------------------------------------------------------------------+

**6.2 Deep Dive: Resumable Upload Protocol**

Network interruptions during large file uploads are inevitable. The
system must allow resumption from the last successfully uploaded chunk,
not restart from zero.

+-----------------------------------------------------------------------+
| **Figure 4: Resumable Upload State Machine**                          |
|                                                                       |
| RESUMABLE UPLOAD STATE MACHINE                                        |
|                                                                       |
| ══════════════════════════════════════════════════════════════════    |
|                                                                       |
| Upload states stored in Redis (TTL: 72 hours):                        |
|                                                                       |
| Key: upload:{upload_id}                                               |
|                                                                       |
| Value: {                                                              |
|                                                                       |
| owner_id, node_id, filename, total_chunks: 13,                        |
|                                                                       |
| received_chunks: Set{0, 1, 2, 5}, ← bitmask or Set in Redis           |
|                                                                       |
| created_at, expires_at, status: \'IN_PROGRESS\'                       |
|                                                                       |
| }                                                                     |
|                                                                       |
| NORMAL FLOW: INTERRUPTED & RESUMED:                                   |
|                                                                       |
| ───────────────────── ─────────────────────────────────────           |
|                                                                       |
| 1\. POST /initiate 1. Network drops after chunks 0,1,2,5              |
|                                                                       |
| 2\. Upload chunks 0-12 2. Client reconnects (hours later)             |
|                                                                       |
| 3\. POST /complete 3. GET /uploads/{id}/status                        |
|                                                                       |
| 4\. File available Response: { missing: \[3,4,6..12\] }               |
|                                                                       |
| 4\. Server issues new presigned URLs                                  |
|                                                                       |
| for missing chunks only                                               |
|                                                                       |
| 5\. Client uploads chunks 3,4,6-12                                    |
|                                                                       |
| 6\. POST /complete → success                                          |
|                                                                       |
| CHUNK UPLOAD IDEMPOTENCY:                                             |
|                                                                       |
| ─────────────────────────                                             |
|                                                                       |
| If a chunk PUT is retried (network timeout):                          |
|                                                                       |
| • S3 presigned PUT is idempotent (same hash → same object)            |
|                                                                       |
| • Server checks chunk exists before re-registering                    |
|                                                                       |
| • No duplicate data in object store                                   |
|                                                                       |
| UPLOAD EXPIRY:                                                        |
|                                                                       |
| ──────────────                                                        |
|                                                                       |
| • Incomplete uploads expire after 72 hours                            |
|                                                                       |
| • S3 lifecycle rule purges orphaned chunk objects after 3 days        |
|                                                                       |
| • Redis TTL automatically cleans upload state                         |
+-----------------------------------------------------------------------+

**6.3 Deep Dive: File Sync Engine**

The sync engine is what makes Dropbox feel magical --- changes on one
device appear on all others within seconds. It is the most
architecturally complex component and involves change detection,
conflict resolution, and efficient delta transfer.

+-----------------------------------------------------------------------+
| **Figure 5: Sync Engine Architecture**                                |
|                                                                       |
| SYNC ENGINE ARCHITECTURE                                              |
|                                                                       |
| ══════════════════════════════════════════════════════════════════    |
|                                                                       |
| ┌──────────────────────────────────────────────────────────────┐      |
|                                                                       |
| │ DESKTOP CLIENT SYNC PROCESS │                                       |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ File Watcher (inotify/FSEvents/ReadDirectoryChanges) │              |
|                                                                       |
| │ │ detects: create/modify/delete/rename/move │                       |
|                                                                       |
| │ ▼ │                                                                 |
|                                                                       |
| │ Local Change Queue │                                                |
|                                                                       |
| │ │ debounced (500ms) to coalesce rapid changes │                     |
|                                                                       |
| │ ▼ │                                                                 |
|                                                                       |
| │ Hasher: compute content_hash of changed file │                      |
|                                                                       |
| │ Compare with last known hash (local DB / SQLite) │                  |
|                                                                       |
| │ │ if hash unchanged → skip (no real change) │                       |
|                                                                       |
| │ │ if hash changed → proceed to upload │                             |
|                                                                       |
| │ ▼ │                                                                 |
|                                                                       |
| │ Chunk Splitter + Dedup Check → Upload Service │                     |
|                                                                       |
| │ ▼ │                                                                 |
|                                                                       |
| │ Local DB update: { node_id, version, hash, synced_at } │            |
|                                                                       |
| └──────────────────────────────────────────────────────────────┘      |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| Upload changes Poll for remote changes                                |
|                                                                       |
| to server (or long-poll / SSE)                                        |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| ┌────▼────────────────────────────────────▼───────────────────┐       |
|                                                                       |
| │ SYNC SERVER │                                                       |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Change Notification Service │                                       |
|                                                                       |
| │ • Long-poll: GET /v1/sync/changes?cursor={cursor}&timeout=30│       |
|                                                                       |
| │ • SSE: GET /v1/sync/stream (text/event-stream) │                    |
|                                                                       |
| │ • WebSocket: wss://sync.example.com/ws │                            |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Cursor-based Change Feed from Kafka/DB: │                           |
|                                                                       |
| │ { cursor, changes: \[ {node_id, op, version, hash} \] } │           |
|                                                                       |
| └──────────────────────────────────────────────────────────────┘      |
|                                                                       |
| │                                                                     |
|                                                                       |
| Remote changes pushed/polled to all connected devices                 |
|                                                                       |
| Each device downloads only changed chunks (delta sync)                |
+-----------------------------------------------------------------------+

**Conflict Resolution**

Conflicts occur when the same file is edited on two devices while one or
both are offline. There is no single correct answer --- the system must
not silently discard data.

+-----------------------------------------------------------------------+
| **Figure 6: Conflict Resolution**                                     |
|                                                                       |
| CONFLICT DETECTION & RESOLUTION                                       |
|                                                                       |
| ══════════════════════════════════════════════════════════════════    |
|                                                                       |
| SCENARIO: Alice edits report.pdf on Laptop while offline.             |
|                                                                       |
| Bob edits the same report.pdf on Desktop (online).                    |
|                                                                       |
| Bob\'s version is saved as version 5.                                 |
|                                                                       |
| Alice comes online --- her local version is based on version 4.       |
|                                                                       |
| Conflict Detection:                                                   |
|                                                                       |
| ──────────────────                                                    |
|                                                                       |
| Alice\'s client sends: POST /v1/uploads/initiate                      |
|                                                                       |
| Body: { node_id: X, base_version: 4, content_hash: \'alice_hash\' }   |
|                                                                       |
| Server checks: nodes.current_version == 5 (not 4 as Alice expects)    |
|                                                                       |
| AND 5.content_hash != \'alice_hash\'                                  |
|                                                                       |
| → CONFLICT DETECTED                                                   |
|                                                                       |
| Server response: { status: \'CONFLICT\', current_version: 5 }         |
|                                                                       |
| Conflict Resolution Strategy (Dropbox approach):                      |
|                                                                       |
| ──────────────────────────────────────────────────                    |
|                                                                       |
| 1\. Server accepts Alice\'s upload as a NEW file:                     |
|                                                                       |
| \'report (Alice conflicted copy 2024-01-24).pdf\'                     |
|                                                                       |
| 2\. Both versions preserved --- NO DATA LOSS                          |
|                                                                       |
| 3\. User is notified: \'A conflict copy was created\'                 |
|                                                                       |
| 4\. User manually resolves (merge, pick one, delete other)            |
|                                                                       |
| Alternative Strategies:                                               |
|                                                                       |
| ───────────────────────                                               |
|                                                                       |
| • Last-Write-Wins (LWW): Simplest, but loses data → NOT acceptable    |
|                                                                       |
| • Three-Way Merge: Only possible for text files with diff algorithms  |
|                                                                       |
| • CRDT (Conflict-free Replicated Data Types): For real-time           |
| collaboration                                                         |
|                                                                       |
| (used in Google Docs, Notion, Figma) --- out of scope for file sync   |
+-----------------------------------------------------------------------+

**6.4 Deep Dive: Delta Sync**

When a user edits a 500 MB video file by adding a 1-second clip, naive
sync re-uploads the entire 500 MB. Delta sync re-uploads only the
changed chunks --- perhaps 4--8 MB.

+-----------------------------------------------------------------------+
| **Figure 7: Delta Sync via Content-Defined Chunking**                 |
|                                                                       |
| DELTA SYNC MECHANISM                                                  |
|                                                                       |
| ══════════════════════════════════════════════════════════════════    |
|                                                                       |
| Original file (version 1) chunk map:                                  |
|                                                                       |
| chunk_0: AAAA chunk_1: BBBB chunk_2: CCCC chunk_3: DDDD               |
|                                                                       |
| After edit (version 2) --- middle section changed:                    |
|                                                                       |
| chunk_0: AAAA chunk_1: XXXX chunk_2: YYYY chunk_3: DDDD               |
|                                                                       |
| (changed) (changed) (unchanged)                                       |
|                                                                       |
| Client computes hashes of new chunks:                                 |
|                                                                       |
| chunk_0 hash: hash_A (same as before → EXISTS on server)              |
|                                                                       |
| chunk_1 hash: hash_X (new → MUST UPLOAD)                              |
|                                                                       |
| chunk_2 hash: hash_Y (new → MUST UPLOAD)                              |
|                                                                       |
| chunk_3 hash: hash_D (same as before → EXISTS on server)              |
|                                                                       |
| Upload savings: only 2/4 chunks (50%) transferred                     |
|                                                                       |
| For a 500 MB file with 4 MB chunks (125 chunks):                      |
|                                                                       |
| If only 2 chunks changed → 8 MB upload instead of 500 MB = 98.4%      |
| savings                                                               |
|                                                                       |
| ROLLING HASH FOR SUB-CHUNK DELTA (rsync algorithm):                   |
|                                                                       |
| ────────────────────────────────────────────────────                  |
|                                                                       |
| Problem: Inserting bytes at start shifts ALL chunk boundaries         |
|                                                                       |
| Solution: Content-Defined Chunking (Rabin fingerprinting)             |
|                                                                       |
| • Chunk boundary is defined by content, not fixed byte offset         |
|                                                                       |
| • Insert 1 byte → only 1-2 boundary chunks change                     |
|                                                                       |
| • Dropbox uses LBFS-style CDC; Bup uses Rabin; restic uses FastCDC    |
|                                                                       |
| Fixed-size chunking: Simple but fragile to insertions                 |
|                                                                       |
| Content-defined chunking: More CPU but dramatically better delta      |
| savings                                                               |
+-----------------------------------------------------------------------+

**6.5 Deep Dive: Storage Tiering**

Not all data is accessed equally. A file uploaded today is accessed
frequently. A file uploaded 3 years ago is rarely touched. Intelligent
tiering reduces storage cost by 70-80% without affecting user
experience.

+-----------------------------------------------------------------------+
| **Figure 8: Storage Tier Lifecycle**                                  |
|                                                                       |
| STORAGE TIER LIFECYCLE                                                |
|                                                                       |
| ══════════════════════════════════════════════════════════════════    |
|                                                                       |
| ┌─────────────────────────────────────────────────────────────┐       |
|                                                                       |
| │ HOT TIER (S3 Standard / GCS Standard) │                             |
|                                                                       |
| │ Access time: milliseconds Cost: \$0.023/GB/month │                  |
|                                                                       |
| │ Criteria: Files accessed in last 30 days │                          |
|                                                                       |
| │ Replication: 3x within same region; cross-AZ │                      |
|                                                                       |
| └────────────────────────┬────────────────────────────────────┘       |
|                                                                       |
| │ No access for 30 days                                               |
|                                                                       |
| │ (S3 Lifecycle Rule / GCS Object Lifecycle)                          |
|                                                                       |
| ┌────────────────────────▼────────────────────────────────────┐       |
|                                                                       |
| │ WARM TIER (S3 Standard-IA / GCS Nearline) │                         |
|                                                                       |
| │ Access time: milliseconds Cost: \$0.0125/GB/month │                 |
|                                                                       |
| │ Criteria: Infrequently accessed, but quick retrieval needed │       |
|                                                                       |
| │ Minimum storage: 30 days │                                          |
|                                                                       |
| └────────────────────────┬────────────────────────────────────┘       |
|                                                                       |
| │ No access for 90 days                                               |
|                                                                       |
| ┌────────────────────────▼────────────────────────────────────┐       |
|                                                                       |
| │ COLD TIER (S3 Glacier / GCS Coldline) │                             |
|                                                                       |
| │ Access time: 1--12 hours Cost: \$0.004/GB/month │                   |
|                                                                       |
| │ Criteria: Rarely accessed; compliance/backup retention │            |
|                                                                       |
| │ NOTE: Restore fee applies --- show user \'restoring\...\' UI │      |
|                                                                       |
| └────────────────────────┬────────────────────────────────────┘       |
|                                                                       |
| │ Deleted files in trash \> 30 days                                   |
|                                                                       |
| ┌────────────────────────▼────────────────────────────────────┐       |
|                                                                       |
| │ ARCHIVE TIER (S3 Glacier Deep Archive) │                            |
|                                                                       |
| │ Access time: 12--48 hours Cost: \$0.00099/GB/month │                |
|                                                                       |
| │ Criteria: Legal hold; enterprise compliance; auditing │             |
|                                                                       |
| └─────────────────────────────────────────────────────────────┘       |
|                                                                       |
| TIER TRANSITION LOGIC (background worker, runs daily):                |
|                                                                       |
| ──────────────────────────────────────────────────────                |
|                                                                       |
| SELECT chunk_hash FROM chunks                                         |
|                                                                       |
| WHERE last_accessed_at \< NOW() - INTERVAL \'30 days\'                |
|                                                                       |
| AND current_tier = \'HOT\'                                            |
|                                                                       |
| → Issue S3 CopyObject to IA storage class                             |
|                                                                       |
| → Update chunks.storage_tier in DB                                    |
|                                                                       |
| When user downloads a cold/archive file:                              |
|                                                                       |
| → Issue S3 RestoreObject request (async)                              |
|                                                                       |
| → Notify user: \'File is being prepared (est. 2 hrs)\'                |
|                                                                       |
| → Send push notification / email when ready                           |
+-----------------------------------------------------------------------+

**6.6 Deep Dive: Access Control & Sharing**

The ACL system must answer one question in \<10ms at download time:
\'Does user U have permission P on node N?\' It must also handle
inherited permissions (sharing a folder grants access to all its
children) and link-based sharing.

+-----------------------------------------------------------------------+
| **Figure 9: ACL Evaluation Flow**                                     |
|                                                                       |
| ACL EVALUATION LOGIC                                                  |
|                                                                       |
| ══════════════════════════════════════════════════════════════════    |
|                                                                       |
| Question: Can user Bob download /Alice/Reports/Q4.pdf ?               |
|                                                                       |
| Step 1: Check direct file ownership                                   |
|                                                                       |
| ─────────────────────────────────────                                 |
|                                                                       |
| nodes.owner_id = Alice → Bob is NOT the owner                         |
|                                                                       |
| Step 2: Check direct share on the file                                |
|                                                                       |
| ─────────────────────────────────────────                             |
|                                                                       |
| SELECT permission FROM shares                                         |
|                                                                       |
| WHERE node_id = \'Q4.pdf\' AND recipient_id = \'Bob\'                 |
|                                                                       |
| AND (expires_at IS NULL OR expires_at \> NOW())                       |
|                                                                       |
| → Found: permission = \'VIEWER\' → ALLOW DOWNLOAD                     |
|                                                                       |
| Step 3: Check inherited shares (walk up folder tree)                  |
|                                                                       |
| ───────────────────────────────────────────────────                   |
|                                                                       |
| If Step 2 found nothing:                                              |
|                                                                       |
| SELECT s.permission FROM shares s                                     |
|                                                                       |
| JOIN node_closure nc ON s.node_id = nc.ancestor_id                    |
|                                                                       |
| WHERE nc.descendant_id = \'Q4.pdf\'                                   |
|                                                                       |
| AND s.recipient_id = \'Bob\' AND nc.depth \> 0                        |
|                                                                       |
| → If Alice shared /Reports folder with Bob → Bob can access Q4.pdf    |
|                                                                       |
| Step 4: Check link-based access                                       |
|                                                                       |
| ─────────────────────────────────                                     |
|                                                                       |
| If request includes link_token in query string:                       |
|                                                                       |
| SELECT s.permission, s.expires_at, s.download_limit                   |
|                                                                       |
| FROM shares WHERE link_token = HASH(token)                            |
|                                                                       |
| AND node_id = \'Q4.pdf\' → ALLOW                                      |
|                                                                       |
| CACHING ACL DECISIONS:                                                |
|                                                                       |
| ───────────────────────                                               |
|                                                                       |
| Redis key: acl:{user_id}:{node_id} → permission (TTL 60s)             |
|                                                                       |
| Invalidated when: share created/revoked, file moved, owner changed    |
|                                                                       |
| Cache miss rate \~5% for hot files → database read on miss            |
+-----------------------------------------------------------------------+

**6.7 Deep Dive: Search Service**

Users need to find files by name and content. The search architecture
indexes both file metadata and content (OCR for images, text extraction
for PDFs/Office docs).

+-----------------------------------------------------------------------+
| **Figure 10: Search Pipeline & Query**                                |
|                                                                       |
| SEARCH PIPELINE                                                       |
|                                                                       |
| ══════════════════════════════════════════════════════════════════    |
|                                                                       |
| INDEXING (async, after upload completes):                             |
|                                                                       |
| ──────────────────────────────────────────                            |
|                                                                       |
| Kafka: file-events → Content Indexer Worker                           |
|                                                                       |
| │                                                                     |
|                                                                       |
| ├── For TEXT / DOCX / PDF:                                            |
|                                                                       |
| │ Extract text → Tokenize → Push to Elasticsearch                     |
|                                                                       |
| │                                                                     |
|                                                                       |
| ├── For Images (JPG/PNG):                                             |
|                                                                       |
| │ OCR via Tesseract / Google Vision API                               |
|                                                                       |
| │ → Extract text → Push to Elasticsearch                              |
|                                                                       |
| │                                                                     |
|                                                                       |
| └── For all files:                                                    |
|                                                                       |
| Index: filename, folder_path, mime_type,                              |
|                                                                       |
| owner_id, shared_with\[\], tags, modified_at                          |
|                                                                       |
| ELASTICSEARCH INDEX MAPPING:                                          |
|                                                                       |
| ─────────────────────────────                                         |
|                                                                       |
| {                                                                     |
|                                                                       |
| node_id: keyword,                                                     |
|                                                                       |
| owner_id: keyword, ← ACL filter applied at query time                 |
|                                                                       |
| filename: text (analyzed),                                            |
|                                                                       |
| path: text (analyzed),                                                |
|                                                                       |
| content: text (analyzed),                                             |
|                                                                       |
| mime_type: keyword,                                                   |
|                                                                       |
| size_bytes: long,                                                     |
|                                                                       |
| modified_at: date,                                                    |
|                                                                       |
| shared_with: keyword\[\] ← includes user IDs with access              |
|                                                                       |
| }                                                                     |
|                                                                       |
| SEARCH QUERY with ACL enforcement:                                    |
|                                                                       |
| ────────────────────────────────────                                  |
|                                                                       |
| GET /v1/search?q=quarterly+report&type=pdf&modified_after=2024-01-01  |
|                                                                       |
| Elasticsearch query:                                                  |
|                                                                       |
| {                                                                     |
|                                                                       |
| \'query\': { \'bool\': {                                              |
|                                                                       |
| \'must\': { \'multi_match\': { \'query\':\'quarterly report\',        |
|                                                                       |
| \'fields\':\[\'filename\^3\',\'content\'\] } },                       |
|                                                                       |
| \'filter\': \[ { \'term\': { \'mime_type\': \'application/pdf\' } },  |
|                                                                       |
| { \'range\': { \'modified_at\': { \'gte\': \'2024-01-01\' } } },      |
|                                                                       |
| { \'bool\': { \'should\': \[ ← ACL filter                             |
|                                                                       |
| { \'term\': { \'owner_id\': \'current_user\' } },                     |
|                                                                       |
| { \'term\': { \'shared_with\': \'current_user\' } }                   |
|                                                                       |
| \] } }                                                                |
|                                                                       |
| \]                                                                    |
|                                                                       |
| } }                                                                   |
|                                                                       |
| }                                                                     |
+-----------------------------------------------------------------------+

  -----------------------------------------------------------------------
  **SECTION 7 --- CDN & DOWNLOAD OPTIMIZATION**

  -----------------------------------------------------------------------

**7. CDN & Download Optimization**

**7.1 CDN Architecture**

Files are stored once in origin object storage (S3/GCS) and served
globally via CDN edge nodes. The CDN reduces latency from \~200ms
(origin) to \~20ms (edge) for popular files, and offloads \~80% of
bandwidth from origin.

+-----------------------------------------------------------------------+
| **Figure 11: CDN Download Flow**                                      |
|                                                                       |
| CDN ARCHITECTURE & DOWNLOAD FLOW                                      |
|                                                                       |
| ══════════════════════════════════════════════════════════════════    |
|                                                                       |
| User in Europe requests: GET /v1/files/{id}/download                  |
|                                                                       |
| API Server responds: 302 Redirect →                                   |
|                                                                       |
| https:/                                                               |
| /cdn.example.com/files/{content_hash}?token=signed_jwt&exp=1706200000 |
|                                                                       |
| User\'s Browser / Desktop Client                                      |
|                                                                       |
| │                                                                     |
|                                                                       |
| │ GET https://cdn.example.com/files/{hash}?token=\...                 |
|                                                                       |
| │                                                                     |
|                                                                       |
| ┌───────────▼───────────────────────────────────────────────┐         |
|                                                                       |
| │ CDN EDGE NODE (Frankfurt PoP) │                                     |
|                                                                       |
| │ Cloudflare / CloudFront / Akamai │                                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ 1. Validate signed token (JWT / HMAC signature) │                   |
|                                                                       |
| │ 2. Check local edge cache (LRU) │                                   |
|                                                                       |
| │ Cache HIT → Serve immediately (20ms) │                              |
|                                                                       |
| │ Cache MISS → Fetch from origin, cache, serve │                      |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Cache Key: content_hash (NOT user-specific URL) │                   |
|                                                                       |
| │ → Same file downloaded by 1000 users = 1 origin fetch │             |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Cache-Control: max-age=31536000 (1 year), immutable │               |
|                                                                       |
| │ (immutable because content_hash never changes) │                    |
|                                                                       |
| └──────────────────────┬────────────────────────────────────┘         |
|                                                                       |
| │ Cache MISS only                                                     |
|                                                                       |
| ┌──────────────────────▼────────────────────────────────────┐         |
|                                                                       |
| │ ORIGIN: S3 / GCS (us-east-1) │                                      |
|                                                                       |
| │ Serves file from object storage │                                   |
|                                                                       |
| │ Streams response to CDN edge │                                      |
|                                                                       |
| └────────────────────────────────────────────────────────────┘        |
|                                                                       |
| SECURITY: Signed URLs prevent hotlinking / unauthorized access        |
|                                                                       |
| URL includes: user_id, node_id, expiry timestamp, HMAC signature      |
|                                                                       |
| CDN validates signature at edge --- no origin call for auth           |
+-----------------------------------------------------------------------+

**7.2 Large File Download Optimization**

-   Multipart / Range requests: Client downloads large files in parallel
    4MB chunks

-   Adaptive bitrate for video: HLS/DASH streaming served from CDN for
    video files

-   Content-based cache keys: CDN cache key = content_hash → cache hit
    across all users with same file

-   Prefetching: Desktop client prefetches file metadata but defers blob
    download until needed

-   Compression: CDN applies Brotli/Gzip for compressible files (text,
    JSON, HTML) on the fly

  -----------------------------------------------------------------------
  **SECTION 8 --- SECURITY DESIGN**

  -----------------------------------------------------------------------

**8. Security Design**

**8.1 Encryption Layers**

**Encryption in Transit**

-   TLS 1.3 mandatory for all client-server communication

-   Certificate pinning in desktop and mobile clients

-   Presigned S3 URLs use HTTPS --- data encrypted during direct upload
    to S3

**Encryption at Rest**

-   S3 Server-Side Encryption: SSE-KMS with per-customer keys (AWS KMS)

-   Database encryption: PostgreSQL TDE (Transparent Data Encryption)

-   Envelope encryption: DEK (Data Encryption Key) per file, encrypted
    with KEK (Key Encryption Key) in KMS

-   Key rotation: KEKs rotated annually; re-encryption of DEKs without
    touching file blobs

+-----------------------------------------------------------------------+
| **Figure 12: Envelope Encryption**                                    |
|                                                                       |
| ENVELOPE ENCRYPTION MODEL                                             |
|                                                                       |
| ══════════════════════════════════════════════════════════════        |
|                                                                       |
| AWS KMS (Key Management Service)                                      |
|                                                                       |
| │                                                                     |
|                                                                       |
| │ holds Master Key (CMK) --- never leaves KMS                         |
|                                                                       |
| │                                                                     |
|                                                                       |
| Encryption Service                                                    |
|                                                                       |
| │ calls KMS.GenerateDataKey() → returns:                              |
|                                                                       |
| │ plaintext_DEK (used to encrypt file, then discarded)                |
|                                                                       |
| │ encrypted_DEK (stored alongside file metadata in DB)                |
|                                                                       |
| │                                                                     |
|                                                                       |
| File Upload:                                                          |
|                                                                       |
| 1\. Generate plaintext_DEK (256-bit AES key)                          |
|                                                                       |
| 2\. Encrypt file content with plaintext_DEK (AES-256-GCM)             |
|                                                                       |
| 3\. Store encrypted_DEK in file_versions.encrypted_dek                |
|                                                                       |
| 4\. Discard plaintext_DEK from memory                                 |
|                                                                       |
| 5\. Encrypted blob stored in S3 (encrypted with DEK)                  |
|                                                                       |
| File Download:                                                        |
|                                                                       |
| 1\. Fetch encrypted_DEK from DB                                       |
|                                                                       |
| 2\. Call KMS.Decrypt(encrypted_DEK) → plaintext_DEK                   |
|                                                                       |
| 3\. Decrypt blob with plaintext_DEK                                   |
|                                                                       |
| 4\. Stream decrypted bytes to user                                    |
|                                                                       |
| 5\. Discard plaintext_DEK                                             |
|                                                                       |
| Key Compromise: Only ONE file\'s DEK is compromised --- not all files |
+-----------------------------------------------------------------------+

**8.2 Content Safety**

-   Virus / malware scanning: ClamAV + commercial scanner on all
    uploaded files before making available

-   CSAM detection: PhotoDNA hash matching on image/video uploads

-   Rate limiting: 100 uploads/min per user; 1000 download requests/min

-   Quota enforcement: Check storage_used_bytes against quota before
    accepting upload

-   DDoS protection: Cloudflare Magic Transit + rate limiting at edge

  -----------------------------------------------------------------------
  **SECTION 9 --- DESIGN TRADE-OFFS & JUSTIFICATIONS**

  -----------------------------------------------------------------------

**9. Design Trade-offs & Justifications**

Every architectural decision is a trade-off. Being able to articulate
WHY you chose an approach --- and what you gave up --- is the hallmark
of a senior engineer in a FANG interview.

**9.1 Major Design Decision Table**

  ---------------------------------------------------------------------------
  **Decision**    **Chosen          **Alternative(s)   **Justification &
                  Approach**        Rejected**         Trade-off**
  --------------- ----------------- ------------------ ----------------------
  File storage    Object storage    HDFS, NFS, custom  S3: 11-nines
  backend         (S3/GCS)          block store        durability,
                                                       serverless, lifecycle
                                                       rules, CDN
                                                       integration. HDFS:
                                                       operational overhead,
                                                       not cloud-native.

  Chunk size      4 MB fixed (with  1 MB fixed, 64 MB  4 MB: balance between
                  optional CDC)     fixed              dedup granularity and
                                                       request overhead. Too
                                                       small: many requests.
                                                       Too large: poor delta
                                                       savings.

  Deduplication   Global            Per-user only      Global dedup maximizes
  scope           (cross-user)                         storage savings.
                                                       Trade-off: users can
                                                       infer if identical
                                                       content exists (hash
                                                       oracle). Mitigated by
                                                       never exposing hashes
                                                       to users.

  Folder tree     Closure Table     Adjacency list,    Closure Table: O(1)
  storage                           Nested sets, MPTT  subtree reads.
                                                       Adjacency list:
                                                       O(depth) queries.
                                                       Nested sets: expensive
                                                       writes (all siblings
                                                       update on insert).

  Sync            Long-poll + SSE   Pure polling, pure Long-poll:
  notification    (fallback WS)     WebSocket          firewall-friendly,
                                                       simple; SSE: efficient
                                                       server push.
                                                       WebSocket: added
                                                       complexity for
                                                       bidirectional needs
                                                       the sync use case
                                                       doesn\'t require.

  Conflict        Conflict copy     Last-write-wins,   Conflict copy:
  resolution      (Dropbox-style)   3-way merge        preserves all data, no
                                                       data loss. LWW: data
                                                       loss risk. 3-way
                                                       merge: only possible
                                                       for text; not general.

  CDN cache key   content_hash (not Full URL per user  Hash-based: cache hit
                  URL)                                 across all users for
                                                       identical file =
                                                       massive dedup of CDN
                                                       fetches. URL-based:
                                                       cache bust on every
                                                       share.

  Metadata DB     PostgreSQL +      MongoDB,           PostgreSQL: ACID,
                  Citus             Cassandra,         complex joins (ACL,
                                    DynamoDB           closure table).
                                                       MongoDB: flexible
                                                       schema but weaker
                                                       consistency.
                                                       Cassandra: no joins,
                                                       no transactions.

  Upload path     Client →          Client → API       Direct: API servers
                  presigned URL →   server → S3        not in data path; no
                  S3 directly                          bandwidth bottleneck.
                                                       Proxy: server becomes
                                                       throughput bottleneck
                                                       at scale.
  ---------------------------------------------------------------------------

**9.2 Strong vs. Eventual Consistency Analysis**

+-----------------------------------------------------------------------+
| **Where Strong Consistency is Required**                              |
|                                                                       |
| 1\. File Metadata (create/rename/delete): ACID transactions in        |
| PostgreSQL --- must be atomic.                                        |
|                                                                       |
| Example: Rename + move operation must not leave file unreachable if   |
| server crashes mid-op.                                                |
|                                                                       |
| 2\. Quota enforcement: Check + decrement storage_used_bytes must be   |
| atomic to prevent over-quota uploads.                                 |
|                                                                       |
| 3\. Share permission changes: Revocation of a share must take effect  |
| immediately --- not eventually.                                       |
|                                                                       |
| 4\. Version creation: Assigning version numbers must be strongly      |
| ordered --- no duplicate versions.                                    |
+-----------------------------------------------------------------------+

+-----------------------------------------------------------------------+
| **Where Eventual Consistency is Acceptable**                          |
|                                                                       |
| 1\. Chunk replication: New chunks replicate to secondary region       |
| within seconds --- tolerable.                                         |
|                                                                       |
| 2\. Search index: Elasticsearch index updates lag by 5-10 seconds --- |
| acceptable for search.                                                |
|                                                                       |
| 3\. Thumbnail generation: Thumbnails appear seconds after upload ---  |
| acceptable UX.                                                        |
|                                                                       |
| 4\. Storage tier migration: Hot→warm transition may lag by hours ---  |
| no user-visible impact.                                               |
|                                                                       |
| 5\. Sync notifications: Desktop clients may receive change            |
| notification 1-2 seconds late --- fine.                               |
+-----------------------------------------------------------------------+

**9.3 Scalability Bottleneck Analysis**

  --------------------------------------------------------------------------
  **Component**   **Bottleneck**   **Detection**     **Solution**
  --------------- ---------------- ----------------- -----------------------
  Metadata DB     Write throughput Query latency     Citus sharding by
  (PostgreSQL)    \>50K TPS on     rises, connection owner_id; read replicas
                  single node      pool exhaustion   for reads; connection
                                                     pooling (PgBouncer)

  Chunk dedup     100K hash        Slow upload       Cache chunk hashes in
  check           lookups/second   initiate API      Redis Bloom filter
                  on chunks table  response time     (probabilistic, no
                                                     false negatives);
                                                     DynamoDB for KV lookup

  Storage quota   Atomic increment Quota update      Pre-shard user quota
  check           on hot accounts  contention        counters; use
                  (celebrities)                      optimistic locking;
                                                     background
                                                     reconciliation

  Elasticsearch   Index write      Indexing lag \>   Increase shards; use
  indexing        throughput       60 seconds        index aliases with
                  ceiling                            hot/warm rotation;
                                                     async bulk indexing

  CDN origin      Traffic spike    Cache hit rate    Increase S3 request
  fetch           causes origin    drops; S3 429     rate limits; add origin
                  overload         errors            shield (regional
                                                     cache); pre-warm cache
                                                     for popular shares

  Sync long-poll  10M concurrent   Memory exhaustion Use async event-loop
                  connections on                     servers (Go/Node.js);
                  sync servers                       limit 30s timeout; shed
                                                     load gracefully
  --------------------------------------------------------------------------

  -----------------------------------------------------------------------
  **SECTION 10 --- SCALING STRATEGIES & RELIABILITY**

  -----------------------------------------------------------------------

**10. Scaling Strategies & Reliability**

**10.1 Multi-Region Architecture**

+-----------------------------------------------------------------------+
| **Figure 13: Multi-Region Active-Active Architecture**                |
|                                                                       |
| MULTI-REGION DEPLOYMENT (Active-Active)                               |
|                                                                       |
| ══════════════════════════════════════════════════════════════════    |
|                                                                       |
| ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐        |
|                                                                       |
| │ US-EAST-1 │ │ EU-WEST-1 │ │ AP-SOUTHEAST-1 │                        |
|                                                                       |
| │──────────────────│ │──────────────────│ │──────────────────│        |
|                                                                       |
| │ API Servers │ │ API Servers │ │ API Servers │                       |
|                                                                       |
| │ Sync Servers │ │ Sync Servers │ │ Sync Servers │                    |
|                                                                       |
| │ Upload Service │ │ Upload Service │ │ Upload Service │              |
|                                                                       |
| │ PostgreSQL Citus │ │ PostgreSQL Citus │ │ PostgreSQL Citus │        |
|                                                                       |
| │ Redis Cluster │ │ Redis Cluster │ │ Redis Cluster │                 |
|                                                                       |
| │ S3 Primary │ │ S3 Replica │ │ S3 Replica │                          |
|                                                                       |
| │ ES Cluster │ │ ES Cluster │ │ ES Cluster │                          |
|                                                                       |
| └────────┬─────────┘ └────────┬─────────┘ └────────┬─────────┘        |
|                                                                       |
| └──────────── Global Backbone ─────────────────┘                      |
|                                                                       |
| (AWS Global Accelerator / Anycast)                                    |
|                                                                       |
| FILE UPLOAD ROUTING:                                                  |
|                                                                       |
| • User\'s request → GeoDNS → nearest region                           |
|                                                                       |
| • File uploaded to nearest S3 bucket                                  |
|                                                                       |
| • S3 Cross-Region Replication → other regions (async, \< 15 min)      |
|                                                                       |
| • Metadata written to local PostgreSQL + async replication            |
|                                                                       |
| READ ROUTING:                                                         |
|                                                                       |
| • Download → nearest CDN edge (\< 20ms)                               |
|                                                                       |
| • CDN origin = region closest to edge PoP                             |
|                                                                       |
| • Metadata reads: local replica (eventual) or primary (strong)        |
|                                                                       |
| REGION FAILOVER:                                                      |
|                                                                       |
| • Route53 health checks; automatic DNS failover                       |
|                                                                       |
| • RPO: \< 15 min (S3 replication lag)                                 |
|                                                                       |
| • RTO: \< 2 min (DNS TTL + health check interval)                     |
+-----------------------------------------------------------------------+

**10.2 Reliability Patterns**

**Circuit Breakers**

-   Wrap all downstream calls (S3, KMS, Elasticsearch) in circuit
    breakers

-   If S3 error rate \> 5% in 30s window → open circuit → serve from
    cache or return 503

-   Elasticsearch circuit breaker: search degrades gracefully (empty
    results vs crash)

**Idempotency**

-   All upload operations use upload_id as idempotency key --- safe to
    retry

-   Chunk PUT to S3 is inherently idempotent (same hash → same object)

-   POST /complete is idempotent --- duplicate calls return same
    version_id

**Graceful Degradation**

-   Thumbnail failure: Show file icon instead of thumbnail --- never
    block download

-   Search failure: Show empty results with \'search temporarily
    unavailable\' --- never block file access

-   Quota service failure: Fail open (allow upload) with async
    reconciliation --- better than blocking

**10.3 Disaster Recovery**

  -------------------------------------------------------------------------------
  **Scenario**     **Impact**      **Recovery Strategy**  **RTO**   **RPO**
  ---------------- --------------- ---------------------- --------- -------------
  Single AZ        \~30% capacity  Auto-scaling in        \< 2 min  0 (sync
  failure          loss in one     remaining AZs; ALB               replication
                   region          removes failed AZ                within
                                                                    region)

  Full region      Region          GeoDNS failover to     \< 5 min  \< 15 min (S3
  failure          unavailable     nearest healthy region           CRR lag)

  Database         Metadata        Restore from           \< 30 min \< 5 min
  corruption       inaccessible    Point-In-Time Recovery           
                                   (PITR); max 5-min                
                                   window                           

  S3 bucket        File blobs      Object versioning +    \< 4 hrs  0 (versioned)
  accidental       inaccessible    MFA delete; restore              
  deletion                         from replica region              

  Ransomware /     User files      Object versioning +    \< 1 hr   0 (versioned)
  mass deletion    deleted         30-day delete                    
                                   retention; restore               
                                   version                          
  -------------------------------------------------------------------------------

  -----------------------------------------------------------------------
  **SECTION 11 --- INTERVIEW STRATEGY & COMMON QUESTIONS**

  -----------------------------------------------------------------------

**11. Interview Strategy & Common Questions**

+-----------------------------------------------------------------------+
| **45-Minute Interview Breakdown**                                     |
|                                                                       |
| 0-5 min: Clarify requirements --- ask 4-5 targeted questions (file    |
| size, versioning, dedup, E2E?)                                        |
|                                                                       |
| 5-10 min: Capacity estimation --- DAU, storage/day, upload RPS,       |
| bandwidth                                                             |
|                                                                       |
| 10-20 min: High-level architecture --- draw the big picture, name     |
| each component clearly                                                |
|                                                                       |
| 20-35 min: Deep dives --- pick 2-3 of: upload flow, sync engine,      |
| dedup, storage tiering, ACL                                           |
|                                                                       |
| 35-42 min: Trade-offs --- CAP theorem placement, database choices,    |
| chunking strategy                                                     |
|                                                                       |
| 42-45 min: Ask the interviewer thoughtful questions                   |
+-----------------------------------------------------------------------+

**11.1 Common Follow-Up Questions & Model Answers**

**Q: How does deduplication work when two users upload the same file?**

Answer: We use content-addressable storage --- each chunk is stored once
indexed by its SHA-256 hash. When the upload service receives a manifest
of chunk hashes, it queries the chunks table for which hashes already
exist. Existing chunks are not re-uploaded --- the new file_chunk_map
just references them. We increment the reference_count on those chunks.
The file\'s metadata (owner, name, path) is separate from the blob ---
so both users have independent file records pointing to the same
physical chunk objects. This achieves global deduplication. The
reference count ensures chunks are only garbage-collected when no files
reference them.

**Q: How do you handle a 10 GB file upload?**

Answer: The client splits the file into 4 MB chunks (2,560 chunks for a
10 GB file). The upload is initiated in three phases: (1) manifest
submission and dedup check, (2) parallel direct-to-S3 upload of novel
chunks using presigned URLs --- up to 5 concurrent chunk uploads --- and
(3) completion where we register the chunk map. If the upload is
interrupted, the client polls /uploads/{id}/status to get the list of
missing chunks and resumes from there. The client retains upload state
in local SQLite, so even an app restart doesn\'t require starting over.
Total transfer time for 10 GB at 100 Mbps is about 13 minutes.

**Q: What happens when Alice deletes a shared file?**

Answer: Deleting is a two-step process. First, the file is soft-deleted
--- its is_deleted flag is set and it moves to the Trash. All existing
shares become inaccessible immediately (ACL check fails on
is_deleted=true). If Alice permanently deletes from Trash, the node
record is hard-deleted; all shares are cascade-deleted. The
file_versions and file_chunk_map records are retained but scheduled for
GC. Reference counts on chunks are decremented; if ref_count reaches 0,
the chunk is scheduled for deletion from S3. Note: if Bob had shared
access, he receives a notification that the file is no longer available.

**Q: How would you implement Google Drive\'s real-time collaborative
editing?**

Answer: That\'s fundamentally different from file sync --- it requires
Operational Transform (OT) or CRDTs. For OT: every user edit is an
operation (insert N chars at position P, delete M chars from position
Q). The server maintains an operations log; when two concurrent edits
are submitted, the server transforms them against each other to produce
a consistent final state. Google Docs uses a proprietary OT
implementation. Notion and newer systems use CRDTs (like Yjs or
Automerge) which are mathematically guaranteed to converge without
server coordination. This is a separate, complex system design --- I\'d
flag it as out of scope for file sync.

**Q: How do you prevent users from exceeding their storage quota?**

Answer: Quota enforcement requires atomic check-and-decrement. When
upload completes, we run: UPDATE users SET storage_used_bytes =
storage_used_bytes + file_size WHERE user_id = X AND
storage_used_bytes + file_size \<= storage_quota_bytes. If this returns
0 rows updated, the quota was exceeded and we reject the upload. The
file bytes already uploaded to S3 are purged via lifecycle rule. For
performance, we cache the quota status in Redis with a 60-second TTL ---
over-quota users are rejected at the cache layer without hitting the DB.

**11.2 Things That Impress FANG Interviewers**

-   Proactively mention content-defined chunking (CDC) vs fixed-size
    chunking --- shows depth

-   Discuss the reference_count garbage collection problem --- shows you
    think about the full lifecycle

-   Bring up the closure table for folder hierarchy before being asked
    --- rare knowledge

-   Mention envelope encryption vs. SSE --- shows security depth

-   Discuss storage tiering and cost implications --- shows you think
    about real-world economics

-   Address the hash oracle problem in global dedup --- shows security
    awareness

-   Mention idempotency keys on upload operations --- shows distributed
    systems maturity

+-----------------------------------------------------------------------+
| **Red Flags to Avoid**                                                |
|                                                                       |
| NEVER store file blobs in a relational database --- even for          |
| \'small\' files, it doesn\'t scale.                                   |
|                                                                       |
| NEVER use a single database for metadata without discussing sharding  |
| at 500M users.                                                        |
|                                                                       |
| Do NOT propose \'just use UUID as folder path\' --- explain the       |
| closure table need.                                                   |
|                                                                       |
| Do NOT ignore conflict resolution --- it\'s a core correctness        |
| requirement for sync.                                                 |
|                                                                       |
| Do NOT say \'store everything in S3 directly\' without discussing the |
| metadata layer.                                                       |
|                                                                       |
| Do NOT forget ACL enforcement on every read path --- security is      |
| non-negotiable.                                                       |
|                                                                       |
| Do NOT use WebSocket for large file transfers --- HTTP/S with range   |
| requests is correct.                                                  |
+-----------------------------------------------------------------------+

  -----------------------------------------------------------------------
  **SECTION 12 --- QUICK REFERENCE CARD**

  -----------------------------------------------------------------------

**12. Quick Reference**

**12.1 Technology Stack Summary**

  -----------------------------------------------------------------------
  **Layer**        **Technology**     **Purpose**
  ---------------- ------------------ -----------------------------------
  API Gateway      Kong / AWS API     Rate limiting, auth, routing, SSL
                   Gateway            termination

  API Servers      Go / Java (Spring  Business logic, metadata ops, ACL
                   Boot)              enforcement

  Upload Service   Go (high           Chunk manifest, dedup check,
                   concurrency)       presigned URL generation

  Sync Engine      Go / Node.js       Long-poll/SSE, cursor-based change
                                      feed

  Object Storage   Amazon S3 / GCS    Raw file blobs; 11-nines
                                      durability; lifecycle tiering

  Metadata DB      PostgreSQL 15 +    File/folder metadata; ACID; sharded
                   Citus              by owner_id

  Cache            Redis Cluster 7.x  Sessions, ACL cache, quota cache,
                                      upload state

  Search           Elasticsearch 8.x  Full-text file name + content
                                      search with ACL filtering

  Message Bus      Apache Kafka       Async processing pipeline; audit
                                      log; sync events

  Background       Kubernetes Jobs    Thumbnail gen, virus scan, content
  Workers                             indexing, GC

  CDN              Cloudflare /       Global file delivery; edge caching
                   CloudFront         by content_hash

  Key Management   AWS KMS /          DEK/KEK management; envelope
                   HashiCorp Vault    encryption

  Monitoring       Prometheus +       Metrics, SLO tracking, on-call
                   Grafana +          alerting
                   PagerDuty          

  Tracing          Jaeger / AWS X-Ray Distributed request tracing across
                                      services
  -----------------------------------------------------------------------

**12.2 Key Numbers to Memorize**

  ------------------------------------------------------------------------
  **Metric**            **Value**        **Notes**
  --------------------- ---------------- ---------------------------------
  Registered Users      500 million      ---

  DAU                   100 million      20% of registered

  Uploads per day       200 million      2 per DAU
                        files            

  Storage growth        100 TB/day raw   500 KB avg file

  With dedup savings    \~70 TB/day net  \~30% dedup rate

  Upload RPS (peak)     \~7,000 writes/s 3x average

  Download RPS (peak)   \~70,000 reads/s 10:1 read:write

  Chunk size            4 MB (fixed) or  \~25 chunks per 100 MB file
                        CDC              

  Resumable upload TTL  72 hours         After which upload_id expires

  Version retention     30 versions or   Whichever limit reached first
                        30 days          

  CDN cache hit rate    \~80%            Reduces origin bandwidth by 80%

  Metadata DB           99.99%           52 min downtime/year
  availability                           

  Object storage        99.999999999%    11 nines
  durability                             
  ------------------------------------------------------------------------

*--- End of Document ---*
