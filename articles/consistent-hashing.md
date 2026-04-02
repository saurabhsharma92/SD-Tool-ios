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

