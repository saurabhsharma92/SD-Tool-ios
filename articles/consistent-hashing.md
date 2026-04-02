# Consistent Hashing
## Introduction  
In a **distributed system**, horizontal scaling is essential as data outgrows the capacity of a single machine. To manage this, data is partitioned across a cluster of nodes. Knowing exactly which node holds specific data—without relying on a slow, centralized lookup table—requires Hashing.  
Hashing acts as a deterministic GPS: given the same input, it always produces the same output, allowing any node to calculate a data location independently. However, traditional 'Modulo N' hashing (key mod n) is brittle. Because the formula depends on the total number of nodes (n), adding or removing a single server changes the mapping for nearly every key in the system. This triggers a data migration storm and massive cache misses, as the system struggles to re-allocate almost all existing data to new locations.

```mermaid
graph BT
    subgraph Keys ["Data Keys"]
        K1((Key A))
        K2((Key B))
        K3((Key C))
    end

    subgraph Ring ["The Virtual Ring Layer"]
        V1[VN_01]:::blue
        V2[VN_02]:::red
        V3[VN_03]:::blue
        V4[VN_04]:::red
    end

    subgraph Hardware ["Physical Infrastructure"]
        Server1[("Server 1 (Blue)")]:::blue
        Server2[("Server 2 (Red)")]:::red
    end

    %% Mapping
    K1 --> V1
    K2 --> V2
    K3 --> V3

    V1 & V3 --> Server1
    V2 & V4 --> Server2

    classDef blue fill:#e1f5fe,stroke:#01579b
    classDef red fill:#ffebee,stroke:#b71c1c
```

Sequence diagram: Requect Routing lifecycle in a Consistent Hashing system
```mermaid
sequenceDiagram
    participant Client
    participant HashFunc as Hash Function (MD5/Murmur)
    participant Ring as The Hash Ring (0-360°)
    participant Nodes as Physical Cluster (Redis/S3)

    Client->>HashFunc: Send Key (e.g., "user_123")
    HashFunc->>HashFunc: Generate Hash Value
    HashFunc->>Ring: Map Hash to Degree (e.g., 142°)
    
    Note over Ring: Find the first Virtual Node<br/>clockwise from 142°
    
    Ring->>Nodes: Route Request to Node B (Virtual #7)
    Nodes-->>Client: Return Data / Success
```

## Why Consistent Hashing?
#### The Core Problem
As described above, Consistent hashing solves the "rehash" problem. When a cluster changes size, only K/n keys need to be remapped (where K is the total keys and n is the number of nodes), preventing a system-wide "cache storm."

#### The Hash Ring (Logical Topology)
Imagine all possible hash values arranged in a fixed circle. For a 32-bit hash, the Hash Space ranges from 0 to 2<sup>32</sup>−1.
- **Placing Nodes**: Each server is hashed (by ID or IP) and placed at a specific coordinate on this ring.
- **Placing Keys**: Each data key is hashed using the same function and mapped onto the same ring.
- **The Lookup**: To find which server owns a key, you move clockwise from the key's position until you hit the first available server.

#### Handling Cluster Changes
Because mapping depends on relative positions, the impact of a change is localized:
- **Adding a Node**: A new node only "captures" keys located between itself and its immediate counter-clockwise neighbor. All other nodes remain unaffected.
```mermaid
flowchart TD
    Start([Scale Up: Add New Node D]) --> HashV["Generate V-Nodes for Node D"]
    HashV --> Inject["Inject V-Nodes into gaps on the Ring"]
    
    subgraph Impact ["Data Movement"]
        Direction[Clockwise Ownership Change]
        Direction --> Stay["80% of Keys: Previous owners stay the same"]
        Direction --> Move["20% of Keys: Re-mapped to New Node D"]
    end

    Inject --> Impact
    Impact --> End([Cluster Rebalanced with Minimal Churn])

    style Stay fill:#d4edda,stroke:#28a745
    style Move fill:#fff3cd,stroke:#856404
```
- **Removing a Node**: If a node fails, its keys simply "slide" clockwise to the next available neighbor. Only the keys from the failed node are remapped.
```mermaid
flowchart TD
    Start([Scale Down: Remove Node D]) --> Identify["Identify V-Nodes for Node D"]
    Identify --> Remove["Remove V-Nodes from the Ring"]
    
    subgraph Impact ["Data Movement"]
        Direction[Clockwise Handover]
        Direction --> Stay["75% of Keys: Owners (A, B, C) remain unchanged"]
        Direction --> Move["25% of Keys: Handed over from D to A, B, or C"]
    end

    Remove --> Impact
    Impact --> End([Cluster Rebalanced: Only Node D's data moved])

    style Stay fill:#d4edda,stroke:#28a745
    style Move fill:#f8d7da,stroke:#dc3545
```

#### Skewness (The problem of Hotspot)
In basic implementation, the nodes might not be distributed uniformly around the ring. This can lead to non-uniform distribution of keys where one server needs to handle 70% of traffic while others sit idle.
**Virtual Nodes**: To fix this issue, Virtual nodes are used. Instead of hashing one server once, we hash it multiple times. This places one server at multiple points on the ring which makes distribution more granular and balanced.
