# System Design Flash Cards
# Format: Front=Back

# Basic
Load Balancing=Distributes traffic across multiple servers for reliability and availability.
Caching=Stores frequently accessed data in memory for faster access.
Database Sharding=Splits databases to handle large-scale data growth.
Replication=Copies data across replicas for availability and fault tolerance.
CAP Theorem=Trade-off between consistency, availability, and partition tolerance.
Consistent Hashing=Distributes load evenly in dynamic server environments.
Message Queues=Decouples services using asynchronous event-driven architecture.
Rate Limiting=Controls request frequency to prevent system overload.
API Gateway=Centralized entry point for routing API requests.
Microservices=Breaks systems into independent, loosely coupled services.
Service Discovery=Locates services dynamically in distributed systems.
CDN=Delivers content from edge servers for speed.
Database Indexing=Speeds up queries by indexing important fields.
Data Partitioning=Divides data across nodes for scalability and performance.
Eventual Consistency=Guarantees consistency over time in distributed databases
WebSockets=Enables bi-directional communication for live updates.
Scalability=Increases capacity by upgrading or adding machines.
Fault Tolerance=Ensures system availability during hardware/software failures.
Monitoring=Tracks metrics and logs to understand system health.
Authentication & Authorization=Controls user access and verifies identity securely.


# Scalability
Horizontal Scaling=Adding more machines to distribute load (scale out). Easier to scale infinitely but requires load balancing and stateless design.
Vertical Scaling=Adding more CPU/RAM to an existing machine (scale up). Simpler but has a hard limit and single point of failure.
Load Balancer=A server that distributes incoming traffic across multiple backend servers. Improves availability and throughput.
CAP Theorem=A distributed system can only guarantee two of three: Consistency, Availability, Partition Tolerance. You must choose which to sacrifice.
Eventual Consistency=A model where replicas may be temporarily inconsistent but will converge to the same state given enough time with no new updates.

# Caching
Cache=A high-speed storage layer that stores a subset of data so future requests are served faster than fetching from the primary store.
Cache Hit=When requested data is found in the cache, avoiding a slower database lookup.
Cache Miss=When requested data is not in the cache and must be fetched from the primary store, then optionally added to cache.
LRU Cache=Least Recently Used — eviction policy that removes the item that hasn't been accessed for the longest time when cache is full.
Write-Through Cache=Data is written to both cache and database simultaneously. Strong consistency but higher write latency.
Write-Back Cache=Data is written to cache first, and asynchronously flushed to database. Fast writes but risk of data loss on crash.
CDN=Content Delivery Network — geographically distributed servers that cache static assets close to users to reduce latency.

# Databases
SQL=Relational database with structured tables, fixed schema, and ACID transactions. Good for complex queries and strong consistency.
NoSQL=Non-relational database with flexible schema. Types include document (MongoDB), key-value (Redis), wide-column (Cassandra), graph (Neo4j).
Sharding=Horizontal partitioning — splitting a database across multiple machines by a shard key. Improves write throughput and storage capacity.
Replication=Copying data to multiple nodes. Primary-replica replication handles read scaling; multi-primary handles write availability.
Index=A data structure (often B-tree) that speeds up read queries at the cost of slower writes and extra storage.
ACID=Atomicity, Consistency, Isolation, Durability — properties that guarantee database transactions are processed reliably.
BASE=Basically Available, Soft state, Eventual consistency — the alternative to ACID used by many NoSQL systems for higher availability.

# Networking
DNS=Domain Name System — translates human-readable domain names (google.com) into IP addresses that machines use to communicate.
HTTP vs HTTPS=HTTP is unencrypted. HTTPS adds TLS encryption, authenticating the server and encrypting data in transit.
REST=Representational State Transfer — an architectural style using HTTP methods (GET, POST, PUT, DELETE) and stateless requests.
WebSocket=A protocol providing full-duplex communication over a single TCP connection. Used for real-time features like chat and live feeds.
API Gateway=A server that acts as entry point for clients, handling routing, authentication, rate limiting, and load balancing.

# System Design Concepts
Rate Limiting=Controlling the number of requests a client can make in a given time window. Protects against abuse and ensures fair usage.
Message Queue=A buffer that decouples producers and consumers. Enables async processing and absorbs traffic spikes (e.g. Kafka, RabbitMQ).
Consistent Hashing=A hashing technique that minimises remapping of keys when nodes are added/removed from a distributed system.
Bloom Filter=A probabilistic data structure that tests whether an element is in a set. May have false positives but never false negatives.
Back-of-Envelope=A quick estimation technique using rough numbers to validate if a design can meet scale requirements before detailed design.
