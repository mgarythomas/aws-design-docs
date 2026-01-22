# Architecture Summary1. 
## 1. Overview
This solution implements an Event-Driven Choreography pattern designed for a high-compliance environment. It enforces strict network segmentation between a Public (DMZ) VPC and a Private Internal VPC. 

The flow manages state transitions for orders (in-progress $\rightarrow$ submitted $\rightarrow$ approved) using a "Fanout" pattern with AWS EventBridge and SQS to ensure decoupling and resilience.

## 2. Network Topology & Ingestion

### DMZ VPC (Public Subnet)

1:Edge Security: Incoming traffic is inspected by WAF/DDOS protection (Imperva/F5)
2.Entry Point: An External API Gateway 
3 exposes the /api/orders endpoint.
DMZ Proxy: A "Lambda Proxy" 4 handles the initial request, performing protocol translation or header scrubbing before crossing the network boundary.

### Network Bridge:
Traffic crosses from the DMZ to the Private network via VPC Peering or PrivateLink5555. This "Double Gateway" pattern acts as a strictly controlled air gap.

### Internal VPC (Private Subnet)

6:Internal Gatekeeper: An Internal API Gateway 7 receives the request.Publisher: A TypeScript Lambda 8 validates the payload and publishes the initial event to the Event Bus.

## 3. Event Bus & Workflow (Internal)
The Bus: An EventBridge Custom Bus (workflow-event-bus) 
9 acts as the central router.State Transition 
1: SubmittedRule: Filters for detail.state: ["submitted"]
10.Buffer: Events are routed to the order-submitted SQS Queue 
11 to handle backpressure.Consumer: The Approval Processor Lambda 
12 polls the queue, executes business logic (e.g., fraud check), and publishes a new event with state: approved back to the bus.State Transition 
2: ApprovedRule: Filters for detail.state: ["approved"]
13.Buffer: Events are routed to the order-approved SQS Queue
14.Consumer: The Fulfillment Service (Spring Boot on EKS) 
15 polls this queue to complete the order.

## 4. Design Trade-offs (DMZ Strategy)FeatureCurrent Strategy (Double Gateway)Alternative (Direct VPC Endpoint)SecurityMaximum. Full L7 inspection at both the Edge and Internal boundary.High. Relies on IAM and Security Groups; less payload inspection at boundary.CouplingLow. DMZ components only need to know the HTTP contract of the internal gateway.High. DMZ components must know AWS SDK implementation details.LatencyHigh. Includes 2x API Gateway hops and 2x Lambda cold starts.Low. Direct path from DMZ Lambda to EventBus.ComplexityMedium. Conceptually simple (HTTP $\rightarrow$ HTTP), but more infrastructure to manage.Low. Fewer moving parts, but requires configuring VPC Endpoints.