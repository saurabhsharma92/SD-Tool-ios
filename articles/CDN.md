# CDN
## About CDN
Modern applications face the challenge of serving a globally distributed user base. High latency in content delivery directly impacts application performance and user adoption. To mitigate this, Content Delivery Networks (CDNs) utilize distributed caching to serve content based on the requester's geographical proximity.
By leveraging a network of edge servers, CDNs minimize the distance between the user and the data. While primarily optimized for large-scale static assets, CDNs are also increasingly used to accelerate dynamic content, such as API responses. When a request occurs, the CDN routes the user to the nearest edge server; if the content is not already cached (cache miss), it is fetched from the origin, stored at the edge, and delivered to the user. This architecture ensures high-speed, reliable delivery across diverse global sectors.

## How does CDN work?
A CDN relies on three primary architectural components to minimize latency and optimize content delivery based on geographical proximity:
Edge Servers / PoPs (Point of Presence): Distributed servers that cache and serve content directly to users within a specific geographic region.
Origin Server: The authoritative source of truth (the primary application server) where the original versions of assets are stored.
DNS (Domain Name System): The routing layer that resolves requests to the IP of the optimal Edge Server rather than the Origin.

#### The Request Lifecycle
DNS Resolution: When a user requests an asset, the browser initiates a DNS query. The CDN’s authoritative DNS identifies the requester’s location and returns the IP address of the geographically nearest Edge Server.
Request Routing: The user’s request is routed to that Edge Server.
Cache Inspection (Hit vs. Miss):
Cache Hit: If the Edge Server has a valid, non-expired copy of the asset, it serves the request immediately.
Cache Miss: If the asset is missing or expired, the Edge Server acts as a reverse proxy, fetching the content from the Origin Server.
Ingestion & Delivery: Upon receiving the response from the Origin, the Edge Server stores the asset in its local cache and simultaneously delivers it to the user.

#### Cache Freshness and TTL
To prevent the delivery of stale content, CDNs utilize a TTL (Time-to-Live) value.
Expiration: Once the TTL expires, the content is marked as stale.
Revalidation: Upon the next request for a stale item, the Edge Server sends a conditional request to the Origin (using headers like If-Modified-Since) to verify if the content has changed. If unchanged, the TTL is reset; if updated, the Edge fetches the new version.

## Content Ingestion Strategies
When implementing a CDN, you must choose a mechanism for how data is populated from the origin to the edge:
1. Pull CDN (Origin Fetch)
In a Pull model, the CDN acts reactively. The edge server is configured with the origin’s address, but it only fetches content when a user specifically requests it and a cache miss occurs.
Best For: Massive-scale applications with large libraries of content (e.g., video streaming, image hosting).
Key Advantages:
Automated Management: Content is automatically cached based on demand.
Cost-Efficient Storage: Only "hot" (frequently requested) data occupies edge storage, while rarely accessed files remain on the origin.

2. Push CDN (Content Pre-fetching)
In a Push model, the application actively uploads content to the CDN before a user ever requests it. The CDN acts more like a distributed storage bucket.
Best For: Time-sensitive or critical content delivery where even the very first request must have zero latency.
Key Use Cases:
Software Updates: Distributing a new app version or patch.
Marketing Campaigns: Launching high-traffic landing pages where a "first-request miss" is unacceptable.
Key Advantage: Guarantees a 100% Cache Hit ratio for the pushed assets from the moment they are deployed.

