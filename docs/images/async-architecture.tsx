import React from 'react';

const ArchitectureDiagram = () => {
  return (
    <div className="w-full h-full bg-slate-50 p-8 overflow-auto">
      <div className="max-w-7xl mx-auto">
        <h2 className="text-2xl font-bold text-center mb-8 text-slate-800">
          EventBridge Workflow Architecture - Multi-VPC Design
        </h2>
        
        <svg viewBox="0 0 1400 950" className="w-full">
          {/* Define arrow marker */}
          <defs>
            <marker
              id="arrowhead"
              markerWidth="10"
              markerHeight="10"
              refX="9"
              refY="3"
              orient="auto">
              <polygon points="0 0, 10 3, 0 6" fill="#475569" />
            </marker>
          </defs>

          {/* DMZ VPC */}
          <g>
            <rect x="30" y="30" width="650" height="320" fill="#fef3c7" stroke="#f59e0b" strokeWidth="3" strokeDasharray="8,4" rx="12" />
            <text x="50" y="60" fill="#92400e" fontSize="18" fontWeight="bold">DMZ VPC (Public Subnet)</text>
            <text x="50" y="80" fill="#92400e" fontSize="12" opacity="0.8">External-facing resources</text>
          </g>

          {/* Internal VPC */}
          <g>
            <rect x="30" y="400" width="1340" height="520" fill="#dbeafe" stroke="#2563eb" strokeWidth="3" strokeDasharray="8,4" rx="12" />
            <text x="50" y="430" fill="#1e3a8a" fontSize="18" fontWeight="bold">Internal VPC (Private Subnet)</text>
            <text x="50" y="450" fill="#1e3a8a" fontSize="12" opacity="0.8">Internal services and event processing</text>
          </g>

          {/* Internet boundary */}
          <line x1="0" y1="370" x2="1400" y2="370" stroke="#ef4444" strokeWidth="3" />
          <text x="700" y="390" textAnchor="middle" fill="#ef4444" fontSize="14" fontWeight="bold">
            ▼ VPC Peering / PrivateLink ▼
          </text>

          {/* NextJS App */}
          <g>
            <rect x="60" y="100" width="140" height="100" fill="#0ea5e9" rx="8" />
            <text x="130" y="135" textAnchor="middle" fill="white" fontSize="14" fontWeight="bold">
              NextJS App
            </text>
            <text x="130" y="155" textAnchor="middle" fill="white" fontSize="12">
              (AWS Amplify)
            </text>
            <text x="130" y="175" textAnchor="middle" fill="white" fontSize="10" opacity="0.8">
              CloudFront CDN
            </text>
            <circle cx="90" cy="120" r="12" fill="white" opacity="0.3" />
            <circle cx="170" cy="120" r="12" fill="white" opacity="0.3" />
          </g>

          {/* Arrow to External API Gateway */}
          <path d="M 200 150 L 300 150" stroke="#475569" strokeWidth="2" markerEnd="url(#arrowhead)" />
          <text x="250" y="140" textAnchor="middle" fill="#475569" fontSize="11">HTTPS</text>

          {/* External API Gateway */}
          <g>
            <rect x="300" y="100" width="160" height="120" fill="#f97316" rx="8" />
            <text x="380" y="130" textAnchor="middle" fill="white" fontSize="15" fontWeight="bold">
              API Gateway
            </text>
            <text x="380" y="150" textAnchor="middle" fill="white" fontSize="13">
              (External)
            </text>
            <text x="380" y="170" textAnchor="middle" fill="white" fontSize="11" opacity="0.9">
              /api/orders
            </text>
            <text x="380" y="188" textAnchor="middle" fill="white" fontSize="10" opacity="0.8">
              Authentication
            </text>
            <text x="380" y="203" textAnchor="middle" fill="white" fontSize="10" opacity="0.8">
              Rate Limiting
            </text>
            
            {/* Shield icon */}
            <circle cx="440" cy="115" r="15" fill="white" opacity="0.3" />
            <text x="440" y="122" textAnchor="middle" fill="white" fontSize="16">🛡</text>
          </g>

          {/* Imperva/F5 indicator */}
          <g>
            <rect x="500" y="110" width="150" height="35" fill="#dc2626" rx="6" />
            <text x="575" y="132" textAnchor="middle" fill="white" fontSize="11" fontWeight="bold">
              Imperva / F5
            </text>
          </g>

          {/* Arrow to Lambda Proxy */}
          <path d="M 380 220 L 380 280" stroke="#475569" strokeWidth="2" markerEnd="url(#arrowhead)" />
          <text x="410" y="250" fill="#475569" fontSize="11">invoke</text>

          {/* Lambda Proxy (External) */}
          <g>
            <rect x="300" y="280" width="160" height="50" fill="#8b5cf6" rx="8" />
            <text x="380" y="307" textAnchor="middle" fill="white" fontSize="13" fontWeight="bold">
              Lambda Proxy
            </text>
            <text x="380" y="322" textAnchor="middle" fill="white" fontSize="10" opacity="0.8">
              (External Gateway)
            </text>
          </g>

          {/* Arrow crossing VPC boundary */}
          <path d="M 380 330 L 380 480" stroke="#475569" strokeWidth="3" markerEnd="url(#arrowhead)" />
          <text x="410" y="380" fill="#475569" fontSize="11" fontWeight="bold">VPC Peering</text>
          <text x="410" y="395" fill="#475569" fontSize="10">or PrivateLink</text>
          {/* Connection box */}
          <rect x="350" y="360" width="60" height="30" fill="#fbbf24" stroke="#f59e0b" strokeWidth="2" rx="4" />
          <text x="380" y="380" textAnchor="middle" fill="#78350f" fontSize="10" fontWeight="bold">Private</text>

          {/* Internal API Gateway */}
          <g>
            <rect x="300" y="480" width="160" height="120" fill="#f97316" rx="8" />
            <text x="380" y="510" textAnchor="middle" fill="white" fontSize="15" fontWeight="bold">
              API Gateway
            </text>
            <text x="380" y="530" textAnchor="middle" fill="white" fontSize="13">
              (Internal)
            </text>
            <text x="380" y="550" textAnchor="middle" fill="white" fontSize="11" opacity="0.9">
              /internal/events
            </text>
            <text x="380" y="568" textAnchor="middle" fill="white" fontSize="10" opacity="0.8">
              VPC Endpoint
            </text>
            <text x="380" y="583" textAnchor="middle" fill="white" fontSize="10" opacity="0.8">
              Private Access Only
            </text>
            
            {/* Lock icon */}
            <circle cx="330" cy="495" r="12" fill="white" opacity="0.3" />
            <text x="330" y="502" textAnchor="middle" fill="white" fontSize="14">🔒</text>
          </g>

          {/* Arrow to Lambda Publisher */}
          <path d="M 460 540 L 560 540" stroke="#475569" strokeWidth="2" markerEnd="url(#arrowhead)" />
          <text x="510" y="530" textAnchor="middle" fill="#475569" fontSize="11">invoke</text>

          {/* Lambda Publisher */}
          <g>
            <rect x="560" y="490" width="160" height="100" fill="#8b5cf6" rx="8" />
            <text x="640" y="525" textAnchor="middle" fill="white" fontSize="14" fontWeight="bold">
              Lambda
            </text>
            <text x="640" y="545" textAnchor="middle" fill="white" fontSize="12">
              State Publisher
            </text>
            <text x="640" y="565" textAnchor="middle" fill="white" fontSize="11" opacity="0.8">
              (TypeScript)
            </text>
            <text x="640" y="578" textAnchor="middle" fill="white" fontSize="9" opacity="0.7">
              Private Subnet
            </text>
          </g>

          {/* Arrow to EventBridge */}
          <path d="M 640 590 L 640 650" stroke="#475569" strokeWidth="2" markerEnd="url(#arrowhead)" />
          <text x="680" y="620" fill="#475569" fontSize="11">PutEvents</text>

          {/* EventBridge */}
          <g>
            <rect x="510" y="650" width="260" height="120" fill="#ec4899" rx="8" />
            <text x="640" y="685" textAnchor="middle" fill="white" fontSize="16" fontWeight="bold">
              EventBridge
            </text>
            <text x="640" y="705" textAnchor="middle" fill="white" fontSize="12">
              workflow-event-bus
            </text>
            
            {/* Event Rules */}
            <rect x="530" y="720" width="100" height="35" fill="white" fillOpacity="0.2" rx="4" />
            <text x="580" y="735" textAnchor="middle" fill="white" fontSize="10">Rule: submitted</text>
            <text x="580" y="748" textAnchor="middle" fill="white" fontSize="9" opacity="0.8">state filter</text>
            
            <rect x="650" y="720" width="100" height="35" fill="white" fillOpacity="0.2" rx="4" />
            <text x="700" y="735" textAnchor="middle" fill="white" fontSize="10">Rule: approved</text>
            <text x="700" y="748" textAnchor="middle" fill="white" fontSize="9" opacity="0.8">state filter</text>
          </g>

          {/* Arrows to SQS Queues */}
          <path d="M 580 770 L 340 830" stroke="#475569" strokeWidth="2" markerEnd="url(#arrowhead)" />
          <path d="M 700 770 L 960 830" stroke="#475569" strokeWidth="2" markerEnd="url(#arrowhead)" />

          {/* SQS Queue - Submitted */}
          <g>
            <rect x="200" y="830" width="180" height="90" fill="#10b981" rx="8" />
            <text x="290" y="860" textAnchor="middle" fill="white" fontSize="14" fontWeight="bold">
              SQS Queue
            </text>
            <text x="290" y="880" textAnchor="middle" fill="white" fontSize="12">
              order-submitted
            </text>
            <text x="290" y="900" textAnchor="middle" fill="white" fontSize="10" opacity="0.8">
              + DLQ
            </text>
          </g>

          {/* SQS Queue - Approved */}
          <g>
            <rect x="960" y="830" width="180" height="90" fill="#10b981" rx="8" />
            <text x="1050" y="860" textAnchor="middle" fill="white" fontSize="14" fontWeight="bold">
              SQS Queue
            </text>
            <text x="1050" y="880" textAnchor="middle" fill="white" fontSize="12">
              order-approved
            </text>
            <text x="1050" y="900" textAnchor="middle" fill="white" fontSize="10" opacity="0.8">
              + DLQ
            </text>
          </g>

          {/* Private Subnet Label for Consumers */}
          <rect x="60" y="785" width="1290" height="30" fill="#93c5fd" fillOpacity="0.3" stroke="#3b82f6" strokeWidth="1" strokeDasharray="4,2" rx="4" />
          <text x="70" y="805" fill="#1e40af" fontSize="12" fontWeight="bold">Private Subnet - Event Consumers</text>

          {/* Lambda Consumer */}
          <g>
            <rect x="810" y="650" width="140" height="80" fill="#8b5cf6" rx="8" />
            <text x="880" y="680" textAnchor="middle" fill="white" fontSize="13" fontWeight="bold">
              Lambda
            </text>
            <text x="880" y="700" textAnchor="middle" fill="white" fontSize="11">
              Approval
            </text>
            <text x="880" y="717" textAnchor="middle" fill="white" fontSize="10" opacity="0.8">
              Processor
            </text>
          </g>

          {/* Arrow from SQS to Lambda Consumer */}
          <path d="M 880 730 L 880 825" stroke="#475569" strokeWidth="2" markerEnd="url(#arrowhead)" strokeDasharray="5,3" />
          <text x="910" y="775" fill="#475569" fontSize="10">trigger</text>

          {/* Spring Boot / EKS Consumer */}
          <g>
            <rect x="1180" y="650" width="160" height="80" fill="#06b6d4" rx="8" />
            <text x="1260" y="675" textAnchor="middle" fill="white" fontSize="13" fontWeight="bold">
              Spring Boot
            </text>
            <text x="1260" y="693" textAnchor="middle" fill="white" fontSize="11">
              Fulfillment
            </text>
            <text x="1260" y="712" textAnchor="middle" fill="white" fontSize="10" opacity="0.8">
              (EKS Pod)
            </text>
          </g>

          {/* Arrow from SQS to Spring Boot */}
          <path d="M 1260 730 L 1260 825" stroke="#475569" strokeWidth="2" markerEnd="url(#arrowhead)" strokeDasharray="5,3" />
          <text x="1290" y="775" fill="#475569" fontSize="10">poll</text>

          {/* Legend */}
          <g transform="translate(50, 895)">
            <text x="0" y="0" fontSize="12" fontWeight="bold" fill="#475569">Legend:</text>
            <rect x="0" y="10" width="20" height="15" fill="#0ea5e9" rx="2" />
            <text x="25" y="22" fontSize="10" fill="#475569">Frontend</text>
            
            <rect x="100" y="10" width="20" height="15" fill="#f97316" rx="2" />
            <text x="125" y="22" fontSize="10" fill="#475569">API Gateway</text>
            
            <rect x="220" y="10" width="20" height="15" fill="#8b5cf6" rx="2" />
            <text x="245" y="22" fontSize="10" fill="#475569">Lambda</text>
            
            <rect x="320" y="10" width="20" height="15" fill="#ec4899" rx="2" />
            <text x="345" y="22" fontSize="10" fill="#475569">EventBridge</text>
            
            <rect x="450" y="10" width="20" height="15" fill="#10b981" rx="2" />
            <text x="475" y="22" fontSize="10" fill="#475569">SQS</text>
            
            <rect x="540" y="10" width="20" height="15" fill="#06b6d4" rx="2" />
            <text x="565" y="22" fontSize="10" fill="#475569">EKS/Spring</text>

            <rect x="680" y="10" width="30" height="15" fill="none" stroke="#f59e0b" strokeWidth="2" strokeDasharray="4,2" rx="2" />
            <text x="715" y="22" fontSize="10" fill="#475569">DMZ VPC</text>

            <rect x="800" y="10" width="30" height="15" fill="none" stroke="#2563eb" strokeWidth="2" strokeDasharray="4,2" rx="2" />
            <text x="835" y="22" fontSize="10" fill="#475569">Internal VPC</text>
          </g>
        </svg>

        <div className="mt-6 grid grid-cols-2 gap-4">
          <div className="p-4 bg-amber-50 border-2 border-amber-300 rounded-lg">
            <h3 className="font-bold text-amber-900 mb-2">🛡 DMZ VPC (Public Layer):</h3>
            <ul className="text-sm text-amber-800 space-y-1 ml-4 list-disc">
              <li>Imperva/F5 WAF protection (upstream)</li>
              <li>External API Gateway with public endpoint</li>
              <li>Lambda Proxy for request transformation</li>
              <li>Forwards validated requests to internal VPC</li>
            </ul>
          </div>
          
          <div className="p-4 bg-blue-50 border-2 border-blue-300 rounded-lg">
            <h3 className="font-bold text-blue-900 mb-2">🔒 Internal VPC (Private Layer):</h3>
            <ul className="text-sm text-blue-800 space-y-1 ml-4 list-disc">
              <li>Internal API Gateway (VPC endpoint only)</li>
              <li>EventBridge, SQS, Lambda, EKS services</li>
              <li>No direct internet access</li>
              <li>Connected via VPC Peering or PrivateLink</li>
            </ul>
          </div>
        </div>

        <div className="mt-4 p-4 bg-purple-50 border border-purple-200 rounded-lg">
          <h3 className="font-bold text-purple-900 mb-2">Architecture Flow:</h3>
          <ol className="text-sm text-purple-800 space-y-1 ml-4">
            <li>1. User initiates request from NextJS app (CloudFront/Amplify)</li>
            <li>2. Request hits External API Gateway in DMZ VPC (public subnet)</li>
            <li>3. WAF filters malicious traffic, API Gateway validates & authenticates</li>
            <li>4. Request forwarded to Internal API Gateway via VPC Peering/PrivateLink</li>
            <li>5. Internal API Gateway invokes Lambda publisher (private subnet)</li>
            <li>6. Lambda publishes event to EventBridge</li>
            <li>7. EventBridge routes to SQS queues based on state filters</li>
            <li>8. Consumers (Lambda/Spring Boot) process messages asynchronously</li>
          </ol>
        </div>
      </div>
    </div>
  );
};

export default ArchitectureDiagram;