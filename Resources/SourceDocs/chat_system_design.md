**SYSTEM DESIGN**

**Facebook Messenger / WhatsApp**

*Real-Time Chat System at Scale*

+-----------------------------------------------------------------------+
| **Senior Software Engineer Interview Prep**                           |
|                                                                       |
| FANG System Design Round                                              |
|                                                                       |
| *High-Level Architecture & Deep Dives*                                |
+-----------------------------------------------------------------------+

Covers: Architecture • Scale Estimation • Deep Dives • Trade-offs • Flow
Diagrams

**Table of Contents**

  -----------------------------------------------------------------------
  **SECTION 1: REQUIREMENTS GATHERING**

  -----------------------------------------------------------------------

**1. Requirements Gathering**

In a FANG system design interview, requirements gathering is the
critical first step. Spend approximately 5-8 minutes here. The goal is
to clarify scope, identify constraints, and align expectations before
diving into the design.

+-----------------------------------------------------------------------+
| **💡 Interview Tip**                                                  |
|                                                                       |
| Always clarify requirements before drawing any diagrams. Interviewers |
| penalize candidates who jump to design without understanding the      |
| problem.                                                              |
|                                                                       |
| Ask: What scale are we designing for? What features are P0 vs         |
| nice-to-have? What are the consistency requirements?                  |
+-----------------------------------------------------------------------+

**1.1 Functional Requirements**

**Core (P0 --- Must Have)**

-   One-on-one messaging: Users can send and receive text messages in
    real-time between two users

-   Group messaging: Support group conversations (up to 500 members per
    group)

-   Message delivery guarantees: At-least-once delivery with
    deduplication; online/offline handling

-   Online presence: Show online/offline status and last seen timestamp

-   Message status indicators: Sent ✓, Delivered ✓✓, Read ✓✓ (blue)
    indicators

-   Push notifications: Deliver notifications for messages when user is
    offline

-   Message history: Users can scroll back and load historical messages
    (pagination)

-   Media support: Share images, videos, documents, and voice messages

**Extended (P1 --- Should Have)**

-   End-to-end encryption (E2EE): Messages encrypted on device, server
    only sees ciphertext

-   Message reactions: Emoji reactions to individual messages

-   Reply and threading: Reply to specific messages with quote reference

-   Story/Status: 24-hour disappearing status updates (WhatsApp Stories)

-   Multi-device support: Login on up to 5 devices simultaneously
    (linked devices)

**Out of Scope (for this interview)**

-   Payments (WhatsApp Pay)

-   Channels / Broadcast lists

-   Voice and video calling

-   Sticker / GIF marketplace

**1.2 Non-Functional Requirements**

  ------------------------------------------------------------------------
  **Requirement**               **Target**         **Justification**
  ----------------------------- ------------------ -----------------------
  Availability                  99.99% (52         Core communication
                                min/year downtime) service --- outages
                                                   have massive user
                                                   impact

  Message Latency (P99)         \< 100ms for       Real-time feel; human
                                online users       perception threshold
                                                   \~200ms

  Throughput                    100B+ messages/day Peak: \~2M
                                (WhatsApp scale)   messages/second

  Message Ordering              Causal ordering    Users expect messages
                                per conversation   in logical order

  Consistency                   Eventual           AP system ---
                                consistency        availability \> strict
                                (acceptable)       consistency

  Durability                    Messages must      Once delivered, message
                                never be lost      must be persisted

  Scalability                   Horizontal,        Traffic spikes (New
                                auto-scaling       Year, major events)

  Security                      E2EE, TLS in       User trust and
                                transit, at-rest   regulatory compliance
                                encryption         (GDPR)

  Data Retention                Indefinite (on     Server-side messages
                                device) / 30 days  purged after delivery
                                (server)           
  ------------------------------------------------------------------------

  -----------------------------------------------------------------------
  **SECTION 2: CAPACITY ESTIMATION & SCALE**

  -----------------------------------------------------------------------

**2. Capacity Estimation**

Back-of-the-envelope estimation demonstrates engineering judgment and
helps drive architectural decisions. Always state your assumptions
clearly.

**2.1 Traffic Estimation**

**Assumptions**

-   2 billion registered users (WhatsApp scale)

-   Daily Active Users (DAU): 1 billion (50% of registered)

-   Average messages sent per DAU per day: 100 messages

-   Average message size: 200 bytes (text), 1-5 MB (media --- handled
    separately)

+-----------------------------------------------------------------------+
| **📊 Message Throughput Calculation**                                 |
|                                                                       |
| Total messages/day = 1B DAU × 100 messages = 100 Billion messages/day |
|                                                                       |
| Average RPS = 100B / 86,400 seconds ≈ 1.16 Million messages/second    |
|                                                                       |
| Peak RPS (3x average) ≈ 3.5 Million messages/second                   |
|                                                                       |
| Write RPS ≈ 1.16M / 2 (sender + receiver) = \~580K writes/second      |
|                                                                       |
| Read RPS ≈ Much higher (10-100x writes) --- message history loading   |
+-----------------------------------------------------------------------+

**2.2 Storage Estimation**

**Message Storage**

-   Text message size: 200 bytes avg

-   Metadata per message: 200 bytes (message_id, timestamps, status,
    sender, conversation_id)

-   Total per message: \~400 bytes

-   Daily storage: 100B messages × 400 bytes = 40 TB/day

-   Annual storage: 40 TB × 365 = \~14.6 PB/year

**Media Storage (CDN + Object Store)**

-   Assume 10% of messages contain media, average 500 KB

-   Media daily: 10B media messages × 500 KB = 5 PB/day

-   CDN caching reduces origin load by \~80%

+-----------------------------------------------------------------------+
| **💾 Storage Recommendation**                                         |
|                                                                       |
| Message DB: Distributed wide-column store (Apache Cassandra / HBase)  |
| --- optimized for write-heavy, time-series data                       |
|                                                                       |
| Media: Distributed object storage (Amazon S3 / Google Cloud Storage)  |
| behind CDN                                                            |
|                                                                       |
| Hot data: Last 7 days in hot tier (SSD-backed nodes)                  |
|                                                                       |
| Warm/Cold: Tiered storage --- older data moves to cheaper storage     |
| automatically                                                         |
+-----------------------------------------------------------------------+

**2.3 Network Bandwidth**

-   Inbound (write) bandwidth: 580K messages/s × 400 bytes = \~232 MB/s
    = \~1.8 Gbps

-   Outbound (read/fan-out) bandwidth: \~5-10x inbound = \~10-18 Gbps

-   Peak outbound (3x): \~55 Gbps --- need multiple edge PoPs

**2.4 Connection Estimation**

-   1 billion DAU, each maintaining 1 persistent WebSocket connection

-   Each WebSocket server can handle \~50,000 concurrent connections

-   WebSocket servers needed: 1B / 50,000 = 20,000 chat servers

-   With geographic distribution: \~40-50 clusters × 500 servers per
    cluster

  -----------------------------------------------------------------------
  **SECTION 3: HIGH-LEVEL ARCHITECTURE**

  -----------------------------------------------------------------------

**3. High-Level Architecture**

**3.1 System Architecture Overview**

The chat system is built on a microservices architecture with each
service independently scalable. The core insight is: messaging is
fundamentally an asynchronous fan-out problem, not a simple
request-response pattern.

+-----------------------------------------------------------------------+
| **Figure 1: High-Level System Architecture**                          |
|                                                                       |
| ┌─────────                                                            |
| ────────────────────────────────────────────────────────────────────┐ |
|                                                                       |
| │ CHAT SYSTEM ARCHITECTURE │                                          |
|                                                                       |
| └─────────                                                            |
| ────────────────────────────────────────────────────────────────────┘ |
|                                                                       |
| CLIENT TIER (Mobile / Web / Desktop)                                  |
|                                                                       |
| ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                       |
|                                                                       |
| │ iOS App │ │ Android App │ │ Web App │                               |
|                                                                       |
| │ (Swift) │ │ (Kotlin) │ │ (React) │                                  |
|                                                                       |
| └──────┬──────┘ └──────┬──────┘ └──────┬──────┘                       |
|                                                                       |
| │ │ │                                                                 |
|                                                                       |
| └────────────────┴────────────────┘                                   |
|                                                                       |
| │                                                                     |
|                                                                       |
| \[TLS / WSS\]                                                         |
|                                                                       |
| │                                                                     |
|                                                                       |
| EDGE TIER                                                             |
|                                                                       |
| ┌───────────────────────▼─────────────────────────┐                   |
|                                                                       |
| │ LOAD BALANCER / API GATEWAY │                                       |
|                                                                       |
| │ (AWS ALB / NGINX / Envoy Proxy) │                                   |
|                                                                       |
| │ • L7 routing • Rate limiting • SSL termination│                     |
|                                                                       |
| │ • Auth token validation (JWT) • DDoS shield │                       |
|                                                                       |
| └────┬────────────────┬────────────────┬───────────┘                  |
|                                                                       |
| │ │ │                                                                 |
|                                                                       |
| CORE SERVICES TIER                                                    |
|                                                                       |
| ┌────▼──────┐ ┌──────▼──────┐ ┌────▼─────────┐                        |
|                                                                       |
| │ CHAT │ │ USER / │ │ MEDIA │                                         |
|                                                                       |
| │ SERVICE │ │ PRESENCE │ │ SERVICE │                                  |
|                                                                       |
| │(WebSocket │ │ SERVICE │ │(Upload/CDN) │                             |
|                                                                       |
| │ Servers) │ │ │ │ │                                                  |
|                                                                       |
| └────┬──────┘ └──────┬──────┘ └────┬─────────┘                        |
|                                                                       |
| │ │ │                                                                 |
|                                                                       |
| MESSAGING BACKBONE                                                    |
|                                                                       |
| ┌────▼────────────────▼────────────────▼──────────┐                   |
|                                                                       |
| │ MESSAGE BROKER (Apache Kafka) │                                     |
|                                                                       |
| │ Topics: messages, notifications, events │                           |
|                                                                       |
| └────┬────────────────┬────────────────────────────┘                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| ┌────▼──────┐ ┌──────▼────────────────────────────┐                   |
|                                                                       |
| │NOTIF. │ │ FANOUT / DELIVERY SERVICE │                               |
|                                                                       |
| │SERVICE │ │ (Routes to online/offline users) │                       |
|                                                                       |
| │(APNs/FCM) │ │ │                                                     |
|                                                                       |
| └───────────┘ └──────────────────────────────────┘                    |
|                                                                       |
| │                                                                     |
|                                                                       |
| DATA TIER                                                             |
|                                                                       |
| ┌───────────┐ ┌────────▼──────┐ ┌──────────────┐                      |
|                                                                       |
| │ USER DB │ │ MESSAGE DB │ │ CACHE LAYER │                            |
|                                                                       |
| │(PostgreSQL│ │ (Cassandra / │ │ (Redis │                             |
|                                                                       |
| │ / MySQL) │ │ ScyllaDB) │ │ Cluster) │                               |
|                                                                       |
| └───────────┘ └───────────────┘ └──────────────┘                      |
|                                                                       |
| ┌─────────────────────────────────────────────────┐                   |
|                                                                       |
| │ OBJECT STORAGE (S3 / GCS) + CDN │                                   |
|                                                                       |
| │ (Media Files) │                                                     |
|                                                                       |
| └─────────────────────────────────────────────────┘                   |
+-----------------------------------------------------------------------+

**3.2 Key Architectural Patterns**

**Pattern 1: WebSocket for Real-Time Communication**

Unlike HTTP (request-response), WebSocket provides a full-duplex
persistent connection. Once established, both client and server can push
data at any time without the overhead of HTTP headers on every message.

+-----------------------------------------------------------------------+
| **Why WebSocket over alternatives?**                                  |
|                                                                       |
| • HTTP Long Polling: Client repeatedly polls server. High latency     |
| (100-500ms), wasteful connections.                                    |
|                                                                       |
| • Server-Sent Events (SSE): Server push only, not bidirectional.      |
| Doesn\'t work for sending messages.                                   |
|                                                                       |
| • WebSocket: True bidirectional, low overhead, \~2-5ms latency.       |
| Industry standard for chat.                                           |
|                                                                       |
| • HTTP/2 Server Push: Not well-suited for this pattern; WebSocket     |
| remains preferred.                                                    |
+-----------------------------------------------------------------------+

**Pattern 2: Fan-Out Architecture**

When Alice sends a message to Bob, the system must \'fan out\' to
deliver to all relevant parties --- Bob\'s devices, group members,
notification services. This is the core architectural challenge.

+-----------------------------------------------------------------------+
| **Figure 2: Fan-Out Architecture**                                    |
|                                                                       |
| FAN-OUT PATTERN FOR GROUP MESSAGING                                   |
|                                                                       |
| Alice sends message to Group (500 members)                            |
|                                                                       |
| │                                                                     |
|                                                                       |
| ┌──────▼────────────────────────────────────────────┐                 |
|                                                                       |
| │ Chat Server receives via WebSocket │                                |
|                                                                       |
| │ • Validates message & persists to Cassandra │                       |
|                                                                       |
| │ • Publishes to Kafka topic: group-messages │                        |
|                                                                       |
| └──────────────────────────────────────────────────┘                  |
|                                                                       |
| │                                                                     |
|                                                                       |
| │ Kafka consumers (parallel processing)                               |
|                                                                       |
| ┌────┴────────────────────────────────────────┐                       |
|                                                                       |
| │ │ │                                                                 |
|                                                                       |
| ┌──▼──────┐ ┌──────▼──────┐ ┌───────────────▼───┐                     |
|                                                                       |
| │Online │ │ Offline │ │ Notification │                                |
|                                                                       |
| │Fan-Out │ │ Storage │ │ Service │                                    |
|                                                                       |
| │Service │ │ Queue │ │ (APNs / FCM) │                                 |
|                                                                       |
| └──┬──────┘ └──────┬──────┘ └───────────────────┘                     |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| ▼ ▼                                                                   |
|                                                                       |
| Push to Store in                                                      |
|                                                                       |
| active WS offline                                                     |
|                                                                       |
| connections inbox                                                     |
|                                                                       |
| (300 online) (200 offline)                                            |
+-----------------------------------------------------------------------+

**Pattern 3: Message Queue Decoupling (Kafka)**

Apache Kafka decouples message sending from delivery. This provides
backpressure handling, replay capability, and allows multiple consumers
(fan-out service, notification service, analytics) to independently
process messages without impacting the sender\'s experience.

  -----------------------------------------------------------------------
  **SECTION 4: DATA MODELS & DATABASE DESIGN**

  -----------------------------------------------------------------------

**4. Data Models & Database Design**

**4.1 Core Entities**

**User**

+-----------------------------------------------------------------------+
| **User Schema**                                                       |
|                                                                       |
| TABLE: users                                                          |
|                                                                       |
| ─────────────────────────────────────────────────                     |
|                                                                       |
| user_id UUID PRIMARY KEY                                              |
|                                                                       |
| phone_number VARCHAR(20) UNIQUE NOT NULL                              |
|                                                                       |
| username VARCHAR(64) UNIQUE                                           |
|                                                                       |
| display_name VARCHAR(128) NOT NULL                                    |
|                                                                       |
| profile_pic_url VARCHAR(512)                                          |
|                                                                       |
| public_key TEXT \-- E2EE public key                                   |
|                                                                       |
| status ENUM \-- ACTIVE, BANNED, DELETED                               |
|                                                                       |
| last_seen TIMESTAMP                                                   |
|                                                                       |
| created_at TIMESTAMP DEFAULT NOW()                                    |
|                                                                       |
| ─────────────────────────────────────────────────                     |
|                                                                       |
| Indexes: phone_number (for login/contact lookup)                      |
|                                                                       |
| username (for search)                                                 |
+-----------------------------------------------------------------------+

**Conversation (Chat Room)**

+-----------------------------------------------------------------------+
| **Conversation Schema**                                               |
|                                                                       |
| TABLE: conversations                                                  |
|                                                                       |
| ─────────────────────────────────────────────────                     |
|                                                                       |
| conversation_id UUID PRIMARY KEY                                      |
|                                                                       |
| type ENUM \-- DIRECT, GROUP                                           |
|                                                                       |
| name VARCHAR \-- null for 1-1 chats                                   |
|                                                                       |
| group_pic_url VARCHAR                                                 |
|                                                                       |
| created_by UUID FK -\> users.user_id                                  |
|                                                                       |
| created_at TIMESTAMP                                                  |
|                                                                       |
| last_message_id UUID FK -\> messages                                  |
|                                                                       |
| last_activity_at TIMESTAMP \-- for sorting                            |
|                                                                       |
| ─────────────────────────────────────────────────                     |
|                                                                       |
| TABLE: conversation_members                                           |
|                                                                       |
| ─────────────────────────────────────────────────                     |
|                                                                       |
| conversation_id UUID FK -\> conversations                             |
|                                                                       |
| user_id UUID FK -\> users                                             |
|                                                                       |
| role ENUM \-- MEMBER, ADMIN                                           |
|                                                                       |
| joined_at TIMESTAMP                                                   |
|                                                                       |
| last_read_seq BIGINT \-- sequence number up to which user has read    |
|                                                                       |
| is_muted BOOLEAN                                                      |
|                                                                       |
| PRIMARY KEY (conversation_id, user_id)                                |
+-----------------------------------------------------------------------+

**Message (Cassandra Schema)**

Messages are stored in Cassandra because: (1) extremely high write
throughput needed, (2) messages are naturally partitioned by
conversation, (3) time-series access pattern fits Cassandra\'s wide-row
model.

+-----------------------------------------------------------------------+
| **Message Schema (Cassandra)**                                        |
|                                                                       |
| TABLE: messages (Apache Cassandra)                                    |
|                                                                       |
| ─────────────────────────────────────────────────────────────────     |
|                                                                       |
| conversation_id UUID PARTITION KEY                                    |
|                                                                       |
| message_seq BIGINT CLUSTERING KEY (DESC \-- newest first)             |
|                                                                       |
| message_id UUID unique ID (for deduplication)                         |
|                                                                       |
| sender_id UUID                                                        |
|                                                                       |
| content_type ENUM \-- TEXT, IMAGE, VIDEO, AUDIO, DOC                  |
|                                                                       |
| content TEXT \-- encrypted message body                               |
|                                                                       |
| media_url VARCHAR \-- CDN URL for media                               |
|                                                                       |
| reply_to_seq BIGINT \-- null if not a reply                           |
|                                                                       |
| status ENUM \-- SENT, DELIVERED, READ                                 |
|                                                                       |
| reactions MAP\<UUID, TEXT\>\-- user_id -\> emoji                      |
|                                                                       |
| sent_at TIMESTAMP                                                     |
|                                                                       |
| edited_at TIMESTAMP \-- null if not edited                            |
|                                                                       |
| deleted_at TIMESTAMP \-- null if not deleted (soft delete)            |
|                                                                       |
| client_msg_id UUID \-- idempotency key from client                    |
|                                                                       |
| ─────────────────────────────────────────────────────────────────     |
|                                                                       |
| PRIMARY KEY ((conversation_id), message_seq)                          |
|                                                                       |
| \-- Partition by conversation = all messages for a chat on same node  |
|                                                                       |
| \-- Clustering DESC = newest messages read first (inbox view)         |
|                                                                       |
| ─────────────────────────────────────────────────────────────────     |
|                                                                       |
| SECONDARY INDEX: message_id \-- for deduplication lookups             |
|                                                                       |
| SECONDARY INDEX: sender_id \-- for \'messages by user\' queries       |
+-----------------------------------------------------------------------+

**4.2 Database Selection Rationale**

  ------------------------------------------------------------------------
  **Component**         **Database**       **Reason**
  --------------------- ------------------ -------------------------------
  User Profiles         PostgreSQL         Strong consistency needed;
                        (relational)       complex queries; ACID for auth

  Messages              Apache Cassandra / Write-heavy; time-series;
                        ScyllaDB           natural partitioning by
                                           conversation; linear
                                           scalability

  Presence/Sessions     Redis Cluster      Sub-millisecond reads; TTL
                                           support; pub/sub for real-time
                                           updates

  Conversation Metadata PostgreSQL         Complex joins; member
                                           management; transactional
                                           operations

  Message Queue         Apache Kafka       High throughput; durable;
                                           replay capability; consumer
                                           groups

  Media Files           S3 + CloudFront    Object storage; global CDN;
                        CDN                cost-effective for large files

  Search                Elasticsearch      Full-text search across
                                           messages; inverted index
  ------------------------------------------------------------------------

  -----------------------------------------------------------------------
  **SECTION 5: API DESIGN**

  -----------------------------------------------------------------------

**5. API Design**

**5.1 REST API Endpoints**

**Authentication**

+-----------------------------------------------------------------------+
| **Authentication APIs**                                               |
|                                                                       |
| POST /v1/auth/register \-- Register with phone number                 |
|                                                                       |
| POST /v1/auth/verify-otp \-- Verify OTP, return JWT + refresh token   |
|                                                                       |
| POST /v1/auth/refresh \-- Refresh JWT access token                    |
|                                                                       |
| POST /v1/auth/logout \-- Invalidate session                           |
+-----------------------------------------------------------------------+

**User & Profile**

+-----------------------------------------------------------------------+
| **User APIs**                                                         |
|                                                                       |
| GET /v1/users/{user_id} \-- Get user profile                          |
|                                                                       |
| PUT /v1/users/{user_id} \-- Update profile (display name, pic)        |
|                                                                       |
| GET /v1/users/search?q={query} \-- Search users by username/phone     |
|                                                                       |
| GET /v1/users/{user_id}/presence \-- Get online status                |
|                                                                       |
| PUT /v1/users/me/settings \-- Update notification settings            |
+-----------------------------------------------------------------------+

**Conversations & Messages**

+-----------------------------------------------------------------------+
| **Conversation & Message APIs**                                       |
|                                                                       |
| GET /v1/conversations \-- List user\'s conversations (paginated)      |
|                                                                       |
| POST /v1/conversations \-- Create new conversation (1-1 or group)     |
|                                                                       |
| GET /v1/conversations/{conv_id} \-- Get conversation details +        |
| members                                                               |
|                                                                       |
| POST /v1/conversations/{conv_id}/members \-- Add member to group      |
|                                                                       |
| DELETE /v1/conversations/{conv_id}/members/{user_id} \-- Remove       |
| member                                                                |
|                                                                       |
| GET /v1/conversations/{conv_id}/messages \-- Get messages (paginated) |
|                                                                       |
| ?before_seq={seq}&limit={n}                                           |
|                                                                       |
| POST /v1/conversations/{conv_id}/messages \-- Send message (REST      |
| fallback)                                                             |
|                                                                       |
| PUT /v1/conversations/{conv_id}/messages/{id} \-- Edit message        |
|                                                                       |
| DELETE /v1/conversations/{conv_id}/messages/{id} \-- Delete message   |
|                                                                       |
| POST /v1/conversations/{conv_id}/messages/{id}/react \-- Add/remove   |
| reaction                                                              |
|                                                                       |
| PUT /v1/conversations/{conv_id}/read \-- Mark messages as read        |
+-----------------------------------------------------------------------+

**5.2 WebSocket Protocol**

WebSocket is used for all real-time communication after initial HTTP
connection establishment. The protocol uses JSON payloads with a type
field for message routing.

**Connection & Authentication**

+-----------------------------------------------------------------------+
| **WebSocket Handshake**                                               |
|                                                                       |
| // Client connects to dedicated chat server                           |
|                                                                       |
| wss://chat.example.com/ws?token={JWT}&device_id={uuid}                |
|                                                                       |
| // Server assigns connection to routing table in Redis:               |
|                                                                       |
| // user_id -\> { server_id, connection_id, last_active }              |
|                                                                       |
| // Heartbeat to keep connection alive                                 |
|                                                                       |
| Client -\> Server: { \"type\": \"PING\", \"ts\": 1706123456789 }      |
|                                                                       |
| Server -\> Client: { \"type\": \"PONG\", \"ts\": 1706123456790,       |
| \"server_ts\": 1706123456791 }                                        |
+-----------------------------------------------------------------------+

**Message Events (Client → Server)**

+-----------------------------------------------------------------------+
| **Outbound Events (Client → Server)**                                 |
|                                                                       |
| // Send a message                                                     |
|                                                                       |
| {                                                                     |
|                                                                       |
| \"type\": \"SEND_MESSAGE\",                                           |
|                                                                       |
| \"client_msg_id\": \"uuid-v4\", // idempotency key                    |
|                                                                       |
| \"conversation_id\": \"conv-uuid\",                                   |
|                                                                       |
| \"content_type\": \"TEXT\",                                           |
|                                                                       |
| \"content\": \"\<encrypted_payload\>\", // base64 E2EE ciphertext     |
|                                                                       |
| \"reply_to_seq\": null, // or seq number if replying                  |
|                                                                       |
| \"ts\": 1706123456789 // client timestamp                             |
|                                                                       |
| }                                                                     |
|                                                                       |
| // Typing indicator                                                   |
|                                                                       |
| {                                                                     |
|                                                                       |
| \"type\": \"TYPING_START\",                                           |
|                                                                       |
| \"conversation_id\": \"conv-uuid\"                                    |
|                                                                       |
| }                                                                     |
|                                                                       |
| // Read receipt                                                       |
|                                                                       |
| {                                                                     |
|                                                                       |
| \"type\": \"READ_RECEIPT\",                                           |
|                                                                       |
| \"conversation_id\": \"conv-uuid\",                                   |
|                                                                       |
| \"up_to_seq\": 1234                                                   |
|                                                                       |
| }                                                                     |
+-----------------------------------------------------------------------+

**Message Events (Server → Client)**

+-----------------------------------------------------------------------+
| **Inbound Events (Server → Client)**                                  |
|                                                                       |
| // New message received                                               |
|                                                                       |
| {                                                                     |
|                                                                       |
| \"type\": \"NEW_MESSAGE\",                                            |
|                                                                       |
| \"message_id\": \"msg-uuid\",                                         |
|                                                                       |
| \"conversation_id\": \"conv-uuid\",                                   |
|                                                                       |
| \"sender_id\": \"user-uuid\",                                         |
|                                                                       |
| \"seq\": 1234, // server-assigned sequence                            |
|                                                                       |
| \"content_type\": \"TEXT\",                                           |
|                                                                       |
| \"content\": \"\<encrypted_payload\>\",                               |
|                                                                       |
| \"sent_at\": \"2024-01-24T10:30:00Z\",                                |
|                                                                       |
| \"client_msg_id\": \"uuid-v4\" // for sender\'s dedup                 |
|                                                                       |
| }                                                                     |
|                                                                       |
| // Message acknowledgment (to sender)                                 |
|                                                                       |
| {                                                                     |
|                                                                       |
| \"type\": \"MSG_ACK\",                                                |
|                                                                       |
| \"client_msg_id\": \"uuid-v4\",                                       |
|                                                                       |
| \"message_id\": \"msg-uuid\",                                         |
|                                                                       |
| \"seq\": 1234,                                                        |
|                                                                       |
| \"status\": \"SENT\"                                                  |
|                                                                       |
| }                                                                     |
|                                                                       |
| // Delivery / read receipt from recipient                             |
|                                                                       |
| {                                                                     |
|                                                                       |
| \"type\": \"STATUS_UPDATE\",                                          |
|                                                                       |
| \"message_id\": \"msg-uuid\",                                         |
|                                                                       |
| \"conversation_id\": \"conv-uuid\",                                   |
|                                                                       |
| \"status\": \"READ\", // DELIVERED \| READ                            |
|                                                                       |
| \"updated_by\": \"recipient-uuid\",                                   |
|                                                                       |
| \"updated_at\": \"2024-01-24T10:30:15Z\"                              |
|                                                                       |
| }                                                                     |
|                                                                       |
| // Presence update                                                    |
|                                                                       |
| {                                                                     |
|                                                                       |
| \"type\": \"PRESENCE_UPDATE\",                                        |
|                                                                       |
| \"user_id\": \"uuid\",                                                |
|                                                                       |
| \"status\": \"ONLINE\", // ONLINE \| OFFLINE \| TYPING                |
|                                                                       |
| \"last_seen\": \"2024-01-24T10:29:00Z\"                               |
|                                                                       |
| }                                                                     |
+-----------------------------------------------------------------------+

  -----------------------------------------------------------------------
  **SECTION 6: COMPONENT DEEP DIVES**

  -----------------------------------------------------------------------

**6. Component Deep Dives**

**6.1 Deep Dive: Message Flow (Critical Path)**

The message flow is the most important flow to understand in depth.
Let\'s trace exactly what happens when Alice sends \'Hello\' to Bob.

+-----------------------------------------------------------------------+
| **Figure 3: Detailed Message Flow**                                   |
|                                                                       |
| MESSAGE FLOW: Alice (online) sends to Bob (online)                    |
|                                                                       |
| ═══════════════════════════════════════════════════════════           |
|                                                                       |
| Step 1: Send (Alice\'s Device → Chat Server)                          |
|                                                                       |
| ──────────────────────────────────────────                            |
|                                                                       |
| Alice\'s App Chat Server S1                                           |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ WS: SEND_MESSAGE │                                                  |
|                                                                       |
| │ { client_msg_id: \'abc\', │                                         |
|                                                                       |
| │ conv_id: \'c1\', │                                                  |
|                                                                       |
| │ content: \'\<encrypted\>\' } │                                      |
|                                                                       |
| │────────────────────────────────▶│                                   |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[1\] Validate JWT + rate limit                                     |
|                                                                       |
| │ \[2\] Generate message_id, seq                                      |
|                                                                       |
| │ \[3\] Write to Cassandra (async)                                    |
|                                                                       |
| │ \[4\] Publish to Kafka topic:                                       |
|                                                                       |
| │ \'chat-messages\' partition=\'c1\'                                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │◀────────────────────────────────│                                   |
|                                                                       |
| │ WS: MSG_ACK { seq:1234, id } │                                      |
|                                                                       |
| │ (status: SENT) │                                                    |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| Step 2: Fan-Out (Kafka Consumer → Bob\'s Server)                      |
|                                                                       |
| ──────────────────────────────────────────────                        |
|                                                                       |
| Kafka Consumer (Fan-Out Service) Redis Router                         |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Consume message from Kafka │                                        |
|                                                                       |
| │ Look up Bob\'s connection: │                                        |
|                                                                       |
| │────────────── GET user:bob ────────▶│                               |
|                                                                       |
| │◀─────────── { server_id: S2 } ────│                                 |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Route to Chat Server S2: │                                          |
|                                                                       |
| │────────── gRPC forward ──────────▶ S2                               |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| Step 3: Delivery (Chat Server S2 → Bob\'s Device)                     |
|                                                                       |
| ─────────────────────────────────────────────────                     |
|                                                                       |
| Chat Server S2 Bob\'s Device                                          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ WS: NEW_MESSAGE { \... } │                                          |
|                                                                       |
| │────────────────────────────────▶│                                   |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │◀────────────────────────────────│                                   |
|                                                                       |
| │ WS: READ_RECEIPT │                                                  |
|                                                                       |
| │ (when Bob opens conversation) │                                     |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Forward status to Kafka ────▶ Kafka                                 |
|                                                                       |
| │ → Fan-out → Alice\'s S1 ──────▶ Alice                               |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[Alice sees ✓✓ blue\]                                              |
+-----------------------------------------------------------------------+

**6.2 Deep Dive: Offline Message Delivery**

When Bob is offline, the flow diverges after Kafka. The system must
store the message and deliver it when Bob reconnects.

+-----------------------------------------------------------------------+
| **Figure 4: Offline Message Delivery**                                |
|                                                                       |
| OFFLINE MESSAGE DELIVERY FLOW                                         |
|                                                                       |
| ═══════════════════════════════════════════════                       |
|                                                                       |
| Fan-Out Service checks Redis:                                         |
|                                                                       |
| GET user:bob → NULL (offline)                                         |
|                                                                       |
| │                                                                     |
|                                                                       |
| ├─── \[Path A\] Push Notification ──────▶ APNs / FCM                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Bob\'s device                                                       |
|                                                                       |
| │ shows notification                                                  |
|                                                                       |
| │                                                                     |
|                                                                       |
| └─── \[Path B\] Offline Inbox                                         |
|                                                                       |
| │                                                                     |
|                                                                       |
| RPUSH offline_inbox:bob { message_id, conv_id, seq }                  |
|                                                                       |
| (Redis list with TTL 7 days)                                          |
|                                                                       |
| │                                                                     |
|                                                                       |
| BOB RECONNECTS:                                                       |
|                                                                       |
| ──────────────                                                        |
|                                                                       |
| Bob\'s App ──── WS CONNECT ────▶ Chat Server S3                       |
|                                                                       |
| │                                                                     |
|                                                                       |
| \[1\] Auth + register in Redis                                        |
|                                                                       |
| \[2\] Fetch offline inbox:                                            |
|                                                                       |
| LRANGE offline_inbox:bob                                              |
|                                                                       |
| \[3\] Push all queued messages to Bob                                 |
|                                                                       |
| \[4\] Clear offline inbox                                             |
|                                                                       |
| \[5\] Send delivery receipts back                                     |
|                                                                       |
| to original senders via Kafka                                         |
+-----------------------------------------------------------------------+

+-----------------------------------------------------------------------+
| **Design Decision: Where to store offline messages?**                 |
|                                                                       |
| Option A --- Redis: Fast, low latency, but limited memory, TTL risk   |
|                                                                       |
| Option B --- Kafka: Ordered, durable, but higher complexity for       |
| per-user consumption                                                  |
|                                                                       |
| Option C --- Database (Cassandra): Durable, scalable, but adds read   |
| overhead on reconnect                                                 |
|                                                                       |
| Recommended: Hybrid --- Redis for recent offline messages (\< 7 days, |
| fast reconnect)                                                       |
|                                                                       |
| \+ Cassandra as fallback (messages already persisted there for        |
| history)                                                              |
+-----------------------------------------------------------------------+

**6.3 Deep Dive: Presence Service**

Presence (online/offline status) is deceptively complex at scale. 1
billion users, each needing to broadcast their status to relevant
contacts, generates enormous fan-out.

**Presence Architecture**

+-----------------------------------------------------------------------+
| **Figure 5: Presence Service Design**                                 |
|                                                                       |
| PRESENCE SERVICE ARCHITECTURE                                         |
|                                                                       |
| ══════════════════════════════════════════════════════                |
|                                                                       |
| USER COMES ONLINE:                                                    |
|                                                                       |
| ──────────────────                                                    |
|                                                                       |
| Chat Server → Redis SET user:{id}:presence \'ONLINE\' EX 30           |
|                                                                       |
| → Publish to Redis Pub/Sub channel: presence:{id}                     |
|                                                                       |
| → Kafka event: presence-updates topic                                 |
|                                                                       |
| HEARTBEAT (every 10 seconds from client):                             |
|                                                                       |
| ──────────────────────────────────────────                            |
|                                                                       |
| Client → WS: PING                                                     |
|                                                                       |
| Server → Redis: EXPIRE user:{id}:presence 30 (refresh TTL)            |
|                                                                       |
| If no ping for 30s → TTL expires → user treated as OFFLINE            |
|                                                                       |
| PRESENCE FAN-OUT (who sees your status):                              |
|                                                                       |
| ─────────────────────────────────────────                             |
|                                                                       |
| When Alice comes online:                                              |
|                                                                       |
| 1\. Look up Alice\'s contact list (all conversations + members)       |
|                                                                       |
| 2\. For each online contact who has Alice\'s conversation open:       |
|                                                                       |
| → Push presence update via their WebSocket                            |
|                                                                       |
| Scale limit: Cap fan-out at \~3000 contacts                           |
|                                                                       |
| For users with \>3000 contacts: use pull-based presence (client       |
| polls)                                                                |
|                                                                       |
| REDIS DATA STRUCTURES:                                                |
|                                                                       |
| ──────────────────────                                                |
|                                                                       |
| user:{id}:presence → STRING (\'ONLINE\') with 30s TTL                 |
|                                                                       |
| user:{id}:last_seen → TIMESTAMP (persistent, no TTL)                  |
|                                                                       |
| online_users → Redis HyperLogLog (approximate count)                  |
+-----------------------------------------------------------------------+

**Presence at Scale --- Bottleneck Analysis**

+-----------------------------------------------------------------------+
| **The Presence Fan-Out Problem**                                      |
|                                                                       |
| Problem: A celebrity user (e.g., a public figure) with 10M followers  |
| comes online.                                                         |
|                                                                       |
| Naive approach: Send 10M presence updates → system meltdown           |
|                                                                       |
| Solution 1: Cap presence sharing --- only share with users in mutual  |
| conversations                                                         |
|                                                                       |
| Solution 2: Lazy presence --- clients poll for presence only when     |
| conversation is active                                                |
|                                                                       |
| Solution 3: Subscription model --- client subscribes to specific user |
| presence feeds                                                        |
|                                                                       |
| WhatsApp approach: Only share presence with users who have you in     |
| their contacts AND have recently interacted with you                  |
+-----------------------------------------------------------------------+

**6.4 Deep Dive: Message Ordering & Consistency**

Message ordering is a critical correctness requirement. Users expect to
see messages in the order they were sent, especially in group chats.

**The Ordering Problem**

+-----------------------------------------------------------------------+
| **Figure 6: Message Ordering Solution**                               |
|                                                                       |
| ORDERING CHALLENGES IN DISTRIBUTED SYSTEMS                            |
|                                                                       |
| ══════════════════════════════════════════                            |
|                                                                       |
| Scenario: Alice and Bob both send simultaneously in a group chat      |
|                                                                       |
| Alice\'s device: A1 ──▶ Server S1 (t=100ms)                           |
|                                                                       |
| Bob\'s device: B1 ──▶ Server S2 (t=102ms)                             |
|                                                                       |
| Without coordination:                                                 |
|                                                                       |
| Carol sees: A1, B1 (in arrival order at her server S3)                |
|                                                                       |
| Dave sees: B1, A1 (different arrival order at S4)                     |
|                                                                       |
| → Inconsistency! Different group members see different order.         |
|                                                                       |
| SOLUTION: Server-assigned monotonic sequence numbers                  |
|                                                                       |
| ──────────────────────────────────────────────────────                |
|                                                                       |
| Each conversation has a dedicated sequence counter in Redis           |
|                                                                       |
| (or Zookeeper / distributed counter service)                          |
|                                                                       |
| Redis INCR conv:{id}:seq → returns unique, monotonically increasing   |
| seq                                                                   |
|                                                                       |
| Message gets seq before Kafka publish:                                |
|                                                                       |
| A1 gets seq=1001, B1 gets seq=1002 (winner determined by Redis        |
| atomicity)                                                            |
|                                                                       |
| ALL users see: A1 (1001), B1 (1002) --- consistent ordering!          |
+-----------------------------------------------------------------------+

**Sequence Counter Scalability**

+-----------------------------------------------------------------------+
| **Redis Sequence Counter --- Scaling Challenge**                      |
|                                                                       |
| Single Redis INCR is \~100K ops/sec --- enough for one conversation,  |
| but need one per conversation                                         |
|                                                                       |
| With 100M active conversations × 1000 msgs/day peak: \~1.2B           |
| increments/day per node → distribute                                  |
|                                                                       |
| Solution: Shard sequence counters --- conversation_id % N Redis       |
| shards                                                                |
|                                                                       |
| Alternative: Snowflake ID (Twitter) --- time-based unique IDs with    |
| ordering guarantee without coordination                               |
|                                                                       |
| Snowflake: 41 bits timestamp + 10 bits machine ID + 12 bits sequence  |
| = 64-bit unique ordered ID                                            |
+-----------------------------------------------------------------------+

**6.5 Deep Dive: End-to-End Encryption (E2EE)**

E2EE ensures that only the communicating users can read messages --- not
even the service provider can decrypt them. WhatsApp uses the Signal
Protocol.

+-----------------------------------------------------------------------+
| **Figure 7: E2EE Signal Protocol**                                    |
|                                                                       |
| E2EE KEY EXCHANGE (Signal Protocol --- simplified)                    |
|                                                                       |
| ═══════════════════════════════════════════════════                   |
|                                                                       |
| SETUP (one-time, on registration):                                    |
|                                                                       |
| ───────────────────────────────────                                   |
|                                                                       |
| 1\. Client generates key bundle:                                      |
|                                                                       |
| • Identity Key Pair (IK) --- long-term                                |
|                                                                       |
| • Signed Pre-Key (SPK) --- rotated periodically                       |
|                                                                       |
| • One-Time Pre-Keys (OPKs) × 100 --- used once each                   |
|                                                                       |
| 2\. Client uploads public keys to key server:                         |
|                                                                       |
| POST /v1/keys { IK_pub, SPK_pub, \[OPK_pub × 100\] }                  |
|                                                                       |
| MESSAGE ENCRYPTION (Alice → Bob, first message):                      |
|                                                                       |
| ──────────────────────────────────────────────────                    |
|                                                                       |
| 1\. Alice fetches Bob\'s key bundle from server                       |
|                                                                       |
| 2\. Alice performs X3DH (Extended Triple Diffie-Hellman):             |
|                                                                       |
| Shared_secret = DH(Alice_IK, Bob_SPK)                                 |
|                                                                       |
| \+ DH(Alice_Ephemeral, Bob_IK)                                        |
|                                                                       |
| \+ DH(Alice_Ephemeral, Bob_SPK)                                       |
|                                                                       |
| \+ DH(Alice_Ephemeral, Bob_OPK) \[if available\]                      |
|                                                                       |
| 3\. Derive encryption key from shared_secret using HKDF               |
|                                                                       |
| 4\. Encrypt message with AES-256-GCM                                  |
|                                                                       |
| 5\. Server stores/forwards ONLY the ciphertext                        |
|                                                                       |
| 6\. Server CANNOT decrypt --- it only sees encrypted blobs            |
|                                                                       |
| SUBSEQUENT MESSAGES (Double Ratchet Algorithm):                       |
|                                                                       |
| ──────────────────────────────────────────────                        |
|                                                                       |
| • Keys change with EVERY message (forward secrecy)                    |
|                                                                       |
| • Compromising one key doesn\'t expose past/future messages           |
+-----------------------------------------------------------------------+

  -----------------------------------------------------------------------
  **SECTION 7: CHAT SERVER & WEBSOCKET MANAGEMENT**

  -----------------------------------------------------------------------

**7. Chat Server & WebSocket Management**

**7.1 WebSocket Server Architecture**

The chat server (WebSocket server) is the most critical and complex
component. It maintains long-lived connections with clients and must
efficiently route messages between users.

+-----------------------------------------------------------------------+
| **Figure 8: Chat Server Internals**                                   |
|                                                                       |
| CHAT SERVER INTERNAL ARCHITECTURE                                     |
|                                                                       |
| ═══════════════════════════════════════════════════                   |
|                                                                       |
| ┌─────────────────────────────────────────────────┐                   |
|                                                                       |
| │ CHAT SERVER │                                                       |
|                                                                       |
| │ ───────────────────────────────────────────── │                     |
|                                                                       |
| │ Connection Manager │                                                |
|                                                                       |
| │ • connection_map: { user_id → WebSocket } │                         |
|                                                                       |
| │ • Handles auth, heartbeats, disconnects │                           |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Message Handler │                                                   |
|                                                                       |
| │ • Parses WS frames │                                                |
|                                                                       |
| │ • Routes by message type │                                          |
|                                                                       |
| │ • Validates & rate-limits │                                         |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Kafka Producer │                                                    |
|                                                                       |
| │ • Publishes to \'chat-messages\' topic │                            |
|                                                                       |
| │ • Partitioned by conversation_id │                                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ gRPC Server (internal) │                                            |
|                                                                       |
| │ • Receives forwarded messages from fan-out │                        |
|                                                                       |
| │ • Delivers to local WebSocket connections │                         |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Redis Client │                                                      |
|                                                                       |
| │ • Session registration │                                            |
|                                                                       |
| │ • Presence updates │                                                |
|                                                                       |
| │ • Offline inbox management │                                        |
|                                                                       |
| └─────────────────────────────────────────────────┘                   |
|                                                                       |
| Connection Registration in Redis:                                     |
|                                                                       |
| HSET user_sessions:{user_id} {                                        |
|                                                                       |
| server_id: \'chat-server-42\',                                        |
|                                                                       |
| device_id: \'iphone-uuid\',                                           |
|                                                                       |
| connected_at: timestamp,                                              |
|                                                                       |
| last_active: timestamp                                                |
|                                                                       |
| } EX 86400 (24hr TTL, refreshed on heartbeat)                         |
+-----------------------------------------------------------------------+

**7.2 Server Selection & Routing**

A key challenge is how clients connect to the right chat server, and how
inter-server messages are routed efficiently.

+-----------------------------------------------------------------------+
| **Figure 9: Chat Server Routing**                                     |
|                                                                       |
| CLIENT → SERVER ROUTING (Sticky Load Balancing)                       |
|                                                                       |
| ═══════════════════════════════════════════════════                   |
|                                                                       |
| Load Balancer uses consistent hashing:                                |
|                                                                       |
| server = hash(user_id) % num_servers                                  |
|                                                                       |
| → Same user always connects to same server (session affinity)         |
|                                                                       |
| → Server doesn\'t need external lookup for its own connections        |
|                                                                       |
| But: servers can go down, scale up/down → consistent hashing          |
|                                                                       |
| minimizes reshuffling (only K/N keys move when adding node)           |
|                                                                       |
| INTER-SERVER MESSAGE ROUTING:                                         |
|                                                                       |
| ─────────────────────────────                                         |
|                                                                       |
| Fan-Out Service:                                                      |
|                                                                       |
| 1\. Look up recipient\'s server from Redis                            |
|                                                                       |
| 2\. If recipient.server == self → push directly to WS                 |
|                                                                       |
| 3\. If recipient.server != self → gRPC call to target server          |
|                                                                       |
| Alternative: Redis Pub/Sub per user channel                           |
|                                                                       |
| • Each chat server subscribes to channels for its connected users     |
|                                                                       |
| • Fan-out publishes to user:{bob_id}:messages channel                 |
|                                                                       |
| • Bob\'s server receives and delivers immediately                     |
|                                                                       |
| • Simpler but more Redis memory/connection usage                      |
+-----------------------------------------------------------------------+

**7.3 Handling Server Failures & Reconnection**

+-----------------------------------------------------------------------+
| **Figure 10: Reconnection Protocol**                                  |
|                                                                       |
| RECONNECTION PROTOCOL                                                 |
|                                                                       |
| ═════════════════════════════════════════════════                     |
|                                                                       |
| Normal disconnect (client goes background):                           |
|                                                                       |
| ─────────────────────────────────────────────                         |
|                                                                       |
| 1\. TCP connection drops (or WS close frame)                          |
|                                                                       |
| 2\. Server removes connection from connection_map                     |
|                                                                       |
| 3\. Server publishes presence OFFLINE to Redis pub/sub                |
|                                                                       |
| 4\. Redis session TTL starts counting (30 seconds)                    |
|                                                                       |
| 5\. Offline messages queue in Redis inbox                             |
|                                                                       |
| Client reconnects:                                                    |
|                                                                       |
| ──────────────────                                                    |
|                                                                       |
| 1\. Client sends: { type: CONNECT, last_seq: 1234 }                   |
|                                                                       |
| → \'Give me all messages since seq 1234\'                             |
|                                                                       |
| 2\. Server fetches messages from Cassandra WHERE seq \> 1234          |
|                                                                       |
| 3\. Server fetches pending offline inbox from Redis                   |
|                                                                       |
| 4\. Server delivers gap messages in order                             |
|                                                                       |
| 5\. Normal operation resumes                                          |
|                                                                       |
| Server crash / failover:                                              |
|                                                                       |
| ────────────────────────                                              |
|                                                                       |
| 1\. Load balancer health check fails → marks server down              |
|                                                                       |
| 2\. Client TCP timeout → client reconnects to different server        |
|                                                                       |
| 3\. New server fetches session state from Redis                       |
|                                                                       |
| 4\. Message gap recovery via last_seq as above                        |
|                                                                       |
| → Client is stateless; any server can serve any user                  |
+-----------------------------------------------------------------------+

  -----------------------------------------------------------------------
  **SECTION 8: PUSH NOTIFICATION SERVICE**

  -----------------------------------------------------------------------

**8. Push Notification Service**

**8.1 Notification Architecture**

Push notifications are critical for message delivery when users are
offline. The system integrates with Apple Push Notification Service
(APNs) for iOS and Firebase Cloud Messaging (FCM) for Android.

+-----------------------------------------------------------------------+
| **Figure 11: Push Notification Architecture**                         |
|                                                                       |
| PUSH NOTIFICATION FLOW                                                |
|                                                                       |
| ══════════════════════════════════════════════════════════════        |
|                                                                       |
| Kafka Consumer (Notification Service)                                 |
|                                                                       |
| │ Consumes from: chat-messages, group-events topics                   |
|                                                                       |
| │                                                                     |
|                                                                       |
| ┌────▼──────────────────────────────────────────────────────┐         |
|                                                                       |
| │ NOTIFICATION SERVICE │                                              |
|                                                                       |
| │ ────────────────────────────────────────────────────── │            |
|                                                                       |
| │ 1. Check recipient online status (Redis lookup) │                   |
|                                                                       |
| │ if ONLINE → skip (WS delivery sufficient) │                         |
|                                                                       |
| │ if OFFLINE → proceed to push │                                      |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ 2. Fetch notification preferences (DB lookup) │                     |
|                                                                       |
| │ - User muted this conversation? → skip │                            |
|                                                                       |
| │ - DND hours active? → skip │                                        |
|                                                                       |
| │ - Notification tokens registered? │                                 |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ 3. Build notification payload │                                     |
|                                                                       |
| │ E2EE: Can\'t include message content! │                             |
|                                                                       |
| │ Payload: { conv_id, sender_name, \'New message\' } │                |
|                                                                       |
| │ (actual content fetched on open by client) │                        |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ 4. Send to appropriate provider: │                                  |
|                                                                       |
| │ • iOS device → APNs (Apple Push Notification) │                     |
|                                                                       |
| │ • Android → FCM (Firebase Cloud Messaging) │                        |
|                                                                       |
| │ • Web → Web Push (VAPID) │                                          |
|                                                                       |
| └─────────────────────────────────────────────────────────┘           |
|                                                                       |
| │ │ │                                                                 |
|                                                                       |
| APNs gateway FCM gateway Web Push gateway                             |
|                                                                       |
| │ │ │                                                                 |
|                                                                       |
| iOS device Android device Browser                                     |
|                                                                       |
| RELIABILITY CONSIDERATIONS:                                           |
|                                                                       |
| ───────────────────────────                                           |
|                                                                       |
| • APNs/FCM can fail → retry with exponential backoff                  |
|                                                                       |
| • Token expiry → catch token errors, delete stale tokens              |
|                                                                       |
| • Batch notifications → APNs supports 1000/batch                      |
|                                                                       |
| • Rate limits: FCM 1000 msg/s per project (use Firebase Admin SDK)    |
+-----------------------------------------------------------------------+

  -----------------------------------------------------------------------
  **SECTION 9: MEDIA SERVICE**

  -----------------------------------------------------------------------

**9. Media Service --- File Upload & Delivery**

**9.1 Media Upload Flow**

Sending media (images, videos, audio) requires a different flow than
text --- the file must be uploaded to object storage before the message
is sent.

+-----------------------------------------------------------------------+
| **Figure 12: Media Upload Flow**                                      |
|                                                                       |
| MEDIA UPLOAD FLOW (Presigned URL Pattern)                             |
|                                                                       |
| ════════════════════════════════════════════════════════════          |
|                                                                       |
| Client Media Service S3 / GCS                                         |
|                                                                       |
| │ │ │                                                                 |
|                                                                       |
| │ 1. POST /v1/media/upload │ │                                        |
|                                                                       |
| │ { file_type, size, hash } │ │                                       |
|                                                                       |
| │───────────────────────────▶│ │                                      |
|                                                                       |
| │ │ 2. Validate │                                                     |
|                                                                       |
| │ │ (type, size) │                                                    |
|                                                                       |
| │ │ 3. Generate │                                                     |
|                                                                       |
| │ │ presigned URL │                                                   |
|                                                                       |
| │ │────────────────────▶│                                             |
|                                                                       |
| │ │◀── presigned URL ──│                                              |
|                                                                       |
| │◀── { upload_url, media_id }│ │                                      |
|                                                                       |
| │                                                                     |
|                                                                       |
| │ 4. PUT {upload_url} ──────────────────────────▶│                    |
|                                                                       |
| │ (direct to S3, bypassing our servers) │                             |
|                                                                       |
| │◀───────────────────────── 200 OK ───────────────│                   |
|                                                                       |
| │                                                                     |
|                                                                       |
| │ 5. SEND_MESSAGE { content_type: IMAGE, │                            |
|                                                                       |
| │ media_id: \'xyz\', caption: \'\...\' } │                            |
|                                                                       |
| │───────────────────────────▶│ │                                      |
|                                                                       |
| WHY PRESIGNED URLS?                                                   |
|                                                                       |
| ────────────────────                                                  |
|                                                                       |
| • Client uploads directly to S3 --- bypasses our servers              |
|                                                                       |
| • No bandwidth bottleneck on media service                            |
|                                                                       |
| • Presigned URL expires (15 min) --- security                         |
|                                                                       |
| • S3 handles multipart upload for large files automatically           |
|                                                                       |
| POST-UPLOAD PROCESSING (async):                                       |
|                                                                       |
| ────────────────────────────────                                      |
|                                                                       |
| S3 Event → Lambda/Worker:                                             |
|                                                                       |
| • Generate thumbnails (images: 3 sizes)                               |
|                                                                       |
| • Transcode video (multiple resolutions)                              |
|                                                                       |
| • Run CSAM detection (child safety scanning)                          |
|                                                                       |
| • Virus scan                                                          |
|                                                                       |
| • Store media metadata in DB                                          |
|                                                                       |
| • Invalidate CDN cache if re-upload                                   |
+-----------------------------------------------------------------------+

**9.2 CDN & Media Delivery**

-   Store original in S3 (or GCS), serve via CloudFront / Akamai CDN

-   CDN edge nodes cache media geographically close to users

-   Signed CDN URLs to prevent unauthorized access to private media

-   Media URL in message:
    https://cdn.example.com/media/{media_id}/{variant}

-   Variants: thumbnail_small (100px), thumbnail_large (300px), original

-   Video: adaptive bitrate streaming (HLS) for large videos

  -----------------------------------------------------------------------
  **SECTION 10: DESIGN TRADE-OFFS & JUSTIFICATIONS**

  -----------------------------------------------------------------------

**10. Design Trade-offs & Justifications**

Every architectural decision involves trade-offs. Being able to
articulate these clearly is what separates senior engineers in FANG
interviews.

**10.1 Consistency vs. Availability (CAP Theorem)**

+-----------------------------------------------------------------------+
| **Trade-off: AP System (Available + Partition Tolerant)**             |
|                                                                       |
| Chat is an AP system --- we accept eventual consistency over strict   |
| consistency.                                                          |
|                                                                       |
| Reason: A message being slightly out-of-order momentarily is far less |
| harmful than the service being down.                                  |
|                                                                       |
| What we sacrifice: Two users might momentarily see messages in        |
| different orders.                                                     |
|                                                                       |
| How we mitigate: Server-assigned sequence numbers ensure eventual     |
| consistent ordering.                                                  |
|                                                                       |
| WhatsApp approach: Messages are causally consistent (you see replies  |
| after their parent), not linearly consistent.                         |
+-----------------------------------------------------------------------+

**10.2 Key Design Decisions**

  ---------------------------------------------------------------------------
  **Decision**   **Option A        **Option B      **Justification**
                 (Chosen)**        (Rejected)**    
  -------------- ----------------- --------------- --------------------------
  Real-time      WebSocket         HTTP Long       WebSocket: 2-5ms latency,
  transport      (full-duplex)     Polling         efficient. Polling:
                                                   100-500ms, wasteful
                                                   connections

  Message store  Cassandra (NoSQL) MySQL           Cassandra: linear write
                                   (relational)    scale, time-series fit.
                                                   MySQL: can\'t handle 1M+
                                                   writes/s economically

  Message        Kafka + Fan-out   Direct DB       Kafka: decoupled,
  routing        service           polling         backpressure, replay. DB
                                                   polling: N² queries, tight
                                                   coupling

  Sequence       Server-assigned   Client          Server-assigned:
  numbers        (Redis INCR)      timestamp       consistent global
                                                   ordering. Client
                                                   timestamp: clock skew,
                                                   conflicts

  Presence       Redis (in-memory) Database writes Redis: sub-ms TTL-based
  storage                                          tracking. DB: too slow for
                                                   1B heartbeats/30s

  Offline        Redis list +      Kafka per-user  Redis: fast reconnect
  messages       Cassandra         queue           delivery. Kafka: complex
                                                   consumer group mgmt per
                                                   user

  Media upload   Presigned S3 URLs Proxy through   Presigned: scales
                                   API             infinitely, no server
                                                   bandwidth. Proxy: server
                                                   becomes bottleneck

  Auth           JWT + Refresh     Session cookies JWT: stateless, works
                 tokens                            across services. Cookies:
                                                   need session store, sticky
                                                   sessions
  ---------------------------------------------------------------------------

**10.3 Group Chat Fan-out Strategy**

+-----------------------------------------------------------------------+
| **Fan-out on Write vs. Fan-out on Read**                              |
|                                                                       |
| Fan-out on Write (chosen for small groups \< 100): When message sent, |
| immediately write to all recipients\' inboxes. Low read latency. High |
| write amplification for large groups.                                 |
|                                                                       |
| Fan-out on Read (chosen for large groups \> 100): Store one copy of   |
| message, each client fetches on open. Lower write amplification.      |
| Higher read latency / more complex.                                   |
|                                                                       |
| Hybrid (production recommendation): Small groups → fan-out on write.  |
| Large groups → fan-out on read with last_read_seq pointer. This is    |
| how WhatsApp / Facebook Messenger work.                               |
+-----------------------------------------------------------------------+

**10.4 Database Sharding Strategy**

**Cassandra Partitioning**

-   Partition key: conversation_id --- all messages in a conversation on
    same node

-   Clustering key: message_seq DESC --- efficient range scans for
    message history

-   Hot partition problem: Very active group chats (1000 msgs/min) →
    single partition bottleneck

-   Solution: Bucket partitioning --- (conversation_id, bucket_id) where
    bucket = seq / 10000

-   Read: Query latest bucket first, fetch older buckets as user scrolls
    up

**Cassandra vs. HBase vs. ScyllaDB**

  ------------------------------------------------------------------------------
  **Feature**      **Cassandra**     **HBase**           **ScyllaDB**
  ---------------- ----------------- ------------------- -----------------------
  Write throughput Very high (\~1M   High                Very high (2-3x
                   writes/s per                          Cassandra, same
                   cluster)                              hardware)

  Operational      Medium            High (requires      Low
  complexity                         Hadoop/Zookeeper)   (Cassandra-compatible
                                                         API)

  Consistency      Tunable (ONE to   Strong              Tunable
                   ALL)                                  

  Cost efficiency  Good              Complex to optimize Best (C++ vs Java GC
                                                         pressure)

  Recommendation   ✓ Good choice     Avoid for new       ✓ Best choice if
                                     systems             greenfield
  ------------------------------------------------------------------------------

  -----------------------------------------------------------------------
  **SECTION 11: SCALING STRATEGIES**

  -----------------------------------------------------------------------

**11. Horizontal Scaling & Reliability**

**11.1 Scaling Each Layer**

**WebSocket/Chat Servers**

-   Stateless design --- connection state in Redis, not server memory

-   Scale out horizontally --- add servers as connections increase

-   Target: 50K connections per server × 20K servers = 1B connections

-   Use consistent hashing at load balancer to minimize reconnections on
    scale events

**Kafka Scaling**

-   Partition count = max parallelism --- use conversation_id as
    partition key

-   Target: 1000 partitions × 3 replicas for chat-messages topic

-   Consumer groups for independent scaling of fan-out, notification,
    analytics consumers

-   Cross-region Kafka replication (MirrorMaker 2) for disaster recovery

**Cassandra Scaling**

-   Add nodes → automatic data redistribution (virtual nodes / vnodes)

-   Replication factor = 3 (survives 2 node failures)

-   Cross-DC replication for global availability

-   Compaction strategy: TimeWindowCompactionStrategy (TWCS) ---
    optimized for time-series

**Redis Scaling**

-   Redis Cluster: 16,384 hash slots distributed across master nodes

-   Read replicas per master for presence reads (high read volume)

-   Separate Redis clusters for different use cases: sessions, presence,
    offline inbox, cache

-   Redis Sentinel for failover in each region

**11.2 Multi-Region Architecture**

+-----------------------------------------------------------------------+
| **Figure 13: Multi-Region Architecture**                              |
|                                                                       |
| MULTI-REGION DEPLOYMENT                                               |
|                                                                       |
| ═══════════════════════════════════════════════════                   |
|                                                                       |
| ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐           |
|                                                                       |
| │ US-EAST-1 │ │ EU-WEST-1 │ │ AP-SOUTHEAST │                          |
|                                                                       |
| │ │ │ │ │ │                                                           |
|                                                                       |
| │ Chat Servers │ │ Chat Servers │ │ Chat Servers │                    |
|                                                                       |
| │ Kafka Cluster │ │ Kafka Cluster │ │ Kafka Cluster │                 |
|                                                                       |
| │ Cassandra DC1 │ │ Cassandra DC2 │ │ Cassandra DC3 │                 |
|                                                                       |
| │ Redis Cluster │ │ Redis Cluster │ │ Redis Cluster │                 |
|                                                                       |
| └────────┬────────┘ └────────┬────────┘ └────────┬────────┘           |
|                                                                       |
| │ │ │                                                                 |
|                                                                       |
| └──────────── Global backbone ────────────────┘                       |
|                                                                       |
| (Kafka MirrorMaker 2 / Cassandra                                      |
|                                                                       |
| multi-DC replication)                                                 |
|                                                                       |
| USER ROUTING:                                                         |
|                                                                       |
| ─────────────                                                         |
|                                                                       |
| • DNS GeoDNS → nearest region                                         |
|                                                                       |
| • Alice (US) → US-EAST-1                                              |
|                                                                       |
| • Bob (EU) → EU-WEST-1                                                |
|                                                                       |
| • Alice → Bob: US region handles write,                               |
|                                                                       |
| cross-region Kafka replication → EU region delivers to Bob            |
|                                                                       |
| • Cross-region latency: \~80-100ms added (acceptable for chat)        |
|                                                                       |
| REGION FAILOVER:                                                      |
|                                                                       |
| ─────────────────                                                     |
|                                                                       |
| • Route53 health checks → auto-failover DNS                           |
|                                                                       |
| • Cassandra multi-DC: reads can failover to replica DC                |
|                                                                       |
| • RPO: 0 (no data loss) --- synchronous replication for writes        |
|                                                                       |
| • RTO: \< 60 seconds --- DNS propagation + connection                 |
| re-establishment                                                      |
+-----------------------------------------------------------------------+

**11.3 Rate Limiting**

-   Per-user rate limit: 1000 messages/min (prevent spam/abuse)

-   Per-conversation rate limit: 5000 messages/min (group chat flood)

-   API rate limit: 100 requests/min per user (REST endpoints)

-   Implementation: Token bucket algorithm in Redis (INCR + EXPIRE)

-   Sliding window counter for more accurate limiting: Redis sorted set
    with timestamps

**11.4 Monitoring & Observability**

  -----------------------------------------------------------------------
  **Metric**            **Tool**         **Alert Threshold**
  --------------------- ---------------- --------------------------------
  Message delivery      Prometheus +     \> 500ms sustained 5min
  latency (P99)         Grafana          

  WebSocket connection  Prometheus       \< 80% of capacity (scale-out
  count                                  trigger)

  Kafka consumer lag    Kafka Manager /  \> 10,000 messages behind
                        Burrow           

  Cassandra write       Cassandra JMX +  \> 10ms
  latency (P99)         Prometheus       

  Redis memory usage    Redis INFO stats \> 80% of max memory

  Error rate (WS drops) ELK Stack /      \> 0.1% error rate
                        Datadog          

  Push notification     Custom metrics   \< 95% delivery rate
  delivery rate                          
  -----------------------------------------------------------------------

  -----------------------------------------------------------------------
  **SECTION 12: SECURITY DESIGN**

  -----------------------------------------------------------------------

**12. Security Design**

**12.1 Security Layers**

**Transport Security**

-   TLS 1.3 for all connections --- data encrypted in transit

-   WebSocket over TLS (WSS://) mandatory

-   Certificate pinning in mobile apps --- prevents MITM attacks

-   HSTS headers for web clients

**Authentication & Authorization**

-   Phone number verification via OTP (SMS/WhatsApp OTP)

-   JWT tokens: short-lived access tokens (15 min) + long-lived refresh
    tokens (30 days)

-   Token rotation on refresh --- compromised refresh tokens invalidated
    quickly

-   Device binding --- new device login requires re-verification

-   Biometric app lock --- Touch ID / Face ID before opening app

**Data Security**

-   End-to-end encryption (Signal Protocol) for all messages

-   Encryption at rest: AES-256 for Cassandra data, S3 SSE for media

-   Key management: AWS KMS / HashiCorp Vault for service keys

-   Minimal server-side data: With E2EE, server stores only ciphertext +
    metadata

**Account Security**

-   Two-step verification (2SV): Optional PIN required on registration

-   Account lockout: Progressive delays after failed auth attempts

-   Suspicious login detection: New device/location → notify user

-   Remote session termination: User can log out all devices from app

**12.2 Abuse Prevention**

-   Spam detection: ML model scoring messages (metadata only, not
    content due to E2EE)

-   Reporting mechanism: User can report abusive messages (client-side
    decryption + report)

-   CSAM detection: PhotoDNA hash matching on media before upload

-   Rate limiting: Prevents flooding, account takeover attempts

  -----------------------------------------------------------------------
  **SECTION 13: INTERVIEW STRATEGY & TIPS**

  -----------------------------------------------------------------------

**13. Interview Strategy & Framework**

**13.1 FANG System Design Interview Framework**

+-----------------------------------------------------------------------+
| **45-Minute Interview Breakdown**                                     |
|                                                                       |
| Minutes 0-5: Clarify requirements, scope, and constraints (ASK        |
| questions!)                                                           |
|                                                                       |
| Minutes 5-10: Back-of-envelope estimation (scale, storage, bandwidth) |
|                                                                       |
| Minutes 10-20: High-level architecture --- draw the diagram, explain  |
| each component                                                        |
|                                                                       |
| Minutes 20-35: Deep dives --- pick 2-3 components, go deep (data      |
| model, flow, trade-offs)                                              |
|                                                                       |
| Minutes 35-42: Trade-offs, bottlenecks, failure scenarios             |
|                                                                       |
| Minutes 42-45: Questions for the interviewer                          |
+-----------------------------------------------------------------------+

**13.2 Common Follow-Up Questions & Answers**

**Q: How do you handle message ordering in group chats?**

Answer: Use server-assigned monotonic sequence numbers per conversation.
Redis INCR provides atomic increments. The sequence number is assigned
before Kafka publish, so all consumers see messages in a consistent
order. For multi-region, use Snowflake IDs (timestamp + machine ID +
sequence) to avoid cross-region coordination.

**Q: What happens if a Kafka consumer falls behind (high lag)?**

Answer: Scale out consumer instances --- Kafka allows up to N consumers
per N partitions. If lag is due to slow processing (e.g., notification
service), add more consumers. Implement circuit breakers --- if
notification service is down, don\'t block message delivery. Message TTL
in Kafka (retain for 7 days) ensures late consumers can catch up.

**Q: How do you prevent duplicate message delivery?**

Answer: Three-layer deduplication: (1) Client sends idempotency key
(client_msg_id) --- server checks Redis cache before inserting. (2)
Cassandra insert with IF NOT EXISTS on message_id. (3) Client-side dedup
using client_msg_id in ACK response --- if client receives duplicate
NEW_MESSAGE events, it discards based on message_id.

**Q: How does WhatsApp handle 100B messages/day with so few servers?**

Answer: WhatsApp was famously running 450 billion messages/day on \~50
engineers and a small server fleet by using Erlang/Elixir (BEAM VM ---
millions of lightweight processes), push-only delivery (no server-side
message storage beyond delivery), and extreme engineering efficiency.
Modern Facebook Messenger uses a similar push-based approach with HBase
for persistence.

**Q: How would you design the \'last seen\' feature while respecting
privacy?**

Answer: Store last_seen timestamp in Redis/DB. Privacy settings: 3
levels --- Everyone, Contacts Only, Nobody. For \'Contacts Only\', check
if requester is in target\'s contact list before returning timestamp.
Cache the privacy setting with 5-min TTL to avoid DB hit on every
presence query.

**13.3 Potential Bottlenecks --- Know These**

  -----------------------------------------------------------------------
  **Bottleneck**     **Symptom**        **Solution**
  ------------------ ------------------ ---------------------------------
  Chat server        Users can\'t       Auto-scale chat servers; increase
  connection limit   connect during     ulimit; tune kernel TCP settings
                     traffic spike      

  Redis              Sequence number    Shard by conversation_id; or use
  single-threaded    generation latency Snowflake IDs
  INCR                                  

  Cassandra hot      High read/write    Bucket partitioning; limit group
  partition          latency on viral   size; read replicas
                     group chat         

  Kafka consumer lag Delayed message    Increase partition count; scale
                     delivery           consumer group

  APNs/FCM rate      Push notifications Batching; priority queues; retry
  limiting           failing            with backoff

  Fan-out for        Message delivery   Push/pull hybrid; pre-computed
  mega-groups        takes seconds for  member shards
                     1000-member groups 
  -----------------------------------------------------------------------

**13.4 Things to Impress the Interviewer**

-   Mention client_msg_id for idempotency --- shows you\'ve thought
    about network reliability

-   Discuss the \'last_seq\' reconnection protocol --- shows
    understanding of stateful clients

-   Bring up the CAP theorem trade-off proactively --- don\'t wait to be
    asked

-   Address the thundering herd problem --- when a server restarts, all
    clients reconnect at once

-   Mention Cassandra TWCS compaction for time-series data --- shows
    deep DB knowledge

-   Discuss backpressure --- what happens when downstream services are
    slow

-   Ask clarifying questions about E2EE --- do we need it? It
    fundamentally changes the design

+-----------------------------------------------------------------------+
| **Red Flags to Avoid in Interview**                                   |
|                                                                       |
| ❌ Designing a single database for everything (no sharding            |
| discussion)                                                           |
|                                                                       |
| ❌ Using WebSocket without explaining fallback or reconnection        |
| strategy                                                              |
|                                                                       |
| ❌ Ignoring the fan-out problem for group chats                       |
|                                                                       |
| ❌ Not discussing message ordering/sequence numbers                   |
|                                                                       |
| ❌ Not mentioning rate limiting and abuse prevention                  |
|                                                                       |
| ❌ Using a relational DB (MySQL) for 100B messages/day without        |
| discussing sharding                                                   |
|                                                                       |
| ❌ Not discussing failure scenarios and recovery                      |
+-----------------------------------------------------------------------+

**14. Quick Reference Card**

**Technology Stack Summary**

  --------------------------------------------------------------------------
  **Layer**           **Technology**     **Purpose**
  ------------------- ------------------ -----------------------------------
  Load Balancer       AWS ALB / NGINX    L7 routing, SSL termination, health
                                         checks

  Chat Servers        Node.js / Go (high WebSocket connections, message
                      concurrency)       routing

  Message Queue       Apache Kafka       Async fan-out, durability, replay

  Cache & Sessions    Redis Cluster      Presence, sessions, offline inbox,
                      (7.x)              rate limiting

  Message Storage     Apache Cassandra / Time-series messages, high write
                      ScyllaDB           throughput

  User/Conversation   PostgreSQL 15+     Relational data, ACID transactions
  DB                                     

  Media Storage       Amazon S3 +        Object storage, CDN delivery
                      CloudFront         

  Search              Elasticsearch 8.x  Full-text message search

  Notifications       APNs + FCM + Web   Push to iOS, Android, Web
                      Push               

  Service Mesh        Istio / Envoy      Service discovery, mTLS,
                                         observability

  Container           Kubernetes         Auto-scaling, rolling deployments
  Orchestration                          

  Monitoring          Prometheus +       Metrics, alerts, on-call
                      Grafana +          
                      PagerDuty          
  --------------------------------------------------------------------------

**Key Numbers to Memorize**

  -----------------------------------------------------------------------
  **Metric**          **Value**         **Notes**
  ------------------- ----------------- ---------------------------------
  DAU                 1 billion         WhatsApp / Messenger scale

  Messages/day        100 billion       100 msgs × 1B DAU

  Peak RPS            \~3.5 million/s   3x average

  WebSocket           1 billion         One per active user
  connections         concurrent        

  Servers needed      \~20,000          50K connections/server

  Daily storage       40 TB/day         400 bytes/message
  (text)                                

  Daily storage       \~5 PB/day        10% media messages × 500KB avg
  (media)                               

  Message latency     \< 100ms P99      For online users
  target                                

  Availability target 99.99%            \~52 min downtime/year
  -----------------------------------------------------------------------

*--- End of Document ---*
