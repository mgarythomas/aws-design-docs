import React from 'react';

const SequenceDiagram = () => {
  return (
    <div className="w-full h-full bg-slate-50 p-8 overflow-auto">
      <div className="max-w-7xl mx-auto">
        <h2 className="text-2xl font-bold text-center mb-8 text-slate-800">
          Order State Transition - Sequence Diagram
        </h2>
        
        <svg viewBox="0 0 1400 1100" className="w-full">
          {/* Define arrow markers */}
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
            <marker
              id="arrowhead-return"
              markerWidth="10"
              markerHeight="10"
              refX="9"
              refY="3"
              orient="auto">
              <polygon points="0 0, 10 3, 0 6" fill="#94a3b8" />
            </marker>
          </defs>

          {/* Participants */}
          {/* User */}
          <g>
            <rect x="50" y="20" width="120" height="60" fill="#0ea5e9" rx="8" />
            <text x="110" y="55" textAnchor="middle" fill="white" fontSize="14" fontWeight="bold">
              User/NextJS
            </text>
            <line x1="110" y1="80" x2="110" y2="1050" stroke="#0ea5e9" strokeWidth="2" strokeDasharray="5,5" />
          </g>

          {/* API Gateway */}
          <g>
            <rect x="230" y="20" width="120" height="60" fill="#f97316" rx="8" />
            <text x="290" y="50" textAnchor="middle" fill="white" fontSize="14" fontWeight="bold">
              API Gateway
            </text>
            <line x1="290" y1="80" x2="290" y2="1050" stroke="#f97316" strokeWidth="2" strokeDasharray="5,5" />
          </g>

          {/* Lambda Publisher */}
          <g>
            <rect x="410" y="20" width="120" height="60" fill="#8b5cf6" rx="8" />
            <text x="470" y="45" textAnchor="middle" fill="white" fontSize="13" fontWeight="bold">
              Lambda
            </text>
            <text x="470" y="63" textAnchor="middle" fill="white" fontSize="11">
              Publisher
            </text>
            <line x1="470" y1="80" x2="470" y2="1050" stroke="#8b5cf6" strokeWidth="2" strokeDasharray="5,5" />
          </g>

          {/* EventBridge */}
          <g>
            <rect x="590" y="20" width="120" height="60" fill="#ec4899" rx="8" />
            <text x="650" y="50" textAnchor="middle" fill="white" fontSize="14" fontWeight="bold">
              EventBridge
            </text>
            <line x1="650" y1="80" x2="650" y2="1050" stroke="#ec4899" strokeWidth="2" strokeDasharray="5,5" />
          </g>

          {/* SQS Queue */}
          <g>
            <rect x="770" y="20" width="120" height="60" fill="#10b981" rx="8" />
            <text x="830" y="45" textAnchor="middle" fill="white" fontSize="13" fontWeight="bold">
              SQS Queue
            </text>
            <text x="830" y="63" textAnchor="middle" fill="white" fontSize="11">
              (submitted)
            </text>
            <line x1="830" y1="80" x2="830" y2="1050" stroke="#10b981" strokeWidth="2" strokeDasharray="5,5" />
          </g>

          {/* Lambda Consumer */}
          <g>
            <rect x="950" y="20" width="120" height="60" fill="#8b5cf6" rx="8" />
            <text x="1010" y="45" textAnchor="middle" fill="white" fontSize="13" fontWeight="bold">
              Lambda
            </text>
            <text x="1010" y="63" textAnchor="middle" fill="white" fontSize="11">
              Consumer
            </text>
            <line x1="1010" y1="80" x2="1010" y2="1050" stroke="#8b5cf6" strokeWidth="2" strokeDasharray="5,5" />
          </g>

          {/* Spring Boot Consumer */}
          <g>
            <rect x="1130" y="20" width="120" height="60" fill="#06b6d4" rx="8" />
            <text x="1190" y="45" textAnchor="middle" fill="white" fontSize="13" fontWeight="bold">
              Spring Boot
            </text>
            <text x="1190" y="63" textAnchor="middle" fill="white" fontSize="11">
              (EKS)
            </text>
            <line x1="1190" y1="80" x2="1190" y2="1050" stroke="#06b6d4" strokeWidth="2" strokeDasharray="5,5" />
          </g>

          {/* Sequence Messages */}
          
          {/* 1. User to API Gateway */}
          <path d="M 110 120 L 285 120" stroke="#475569" strokeWidth="2" markerEnd="url(#arrowhead)" />
          <text x="197" y="110" textAnchor="middle" fill="#475569" fontSize="11" fontWeight="bold">
            1. POST /api/orders/state-change
          </text>
          <text x="197" y="138" textAnchor="middle" fill="#64748b" fontSize="10">
            {`{orderId: "123", state: "submitted"}`}
          </text>

          {/* 2. API Gateway to Lambda */}
          <path d="M 290 160 L 465 160" stroke="#475569" strokeWidth="2" markerEnd="url(#arrowhead)" />
          <text x="377" y="150" textAnchor="middle" fill="#475569" fontSize="11" fontWeight="bold">
            2. Invoke Lambda
          </text>

          {/* 3. Lambda processing */}
          <rect x="450" y="180" width="40" height="60" fill="#8b5cf6" fillOpacity="0.3" stroke="#8b5cf6" strokeWidth="2" />
          <text x="540" y="210" fill="#475569" fontSize="10">
            3. Validate & prepare event
          </text>

          {/* 4. Lambda to EventBridge */}
          <path d="M 470 250 L 645 250" stroke="#475569" strokeWidth="2" markerEnd="url(#arrowhead)" />
          <text x="557" y="240" textAnchor="middle" fill="#475569" fontSize="11" fontWeight="bold">
            4. PutEvents
          </text>
          <text x="557" y="268" textAnchor="middle" fill="#64748b" fontSize="10">
            source: "order.service"
          </text>
          <text x="557" y="282" textAnchor="middle" fill="#64748b" fontSize="10">
            detail-type: "OrderStateChanged"
          </text>

          {/* 5. EventBridge processing */}
          <rect x="630" y="300" width="40" height="80" fill="#ec4899" fillOpacity="0.3" stroke="#ec4899" strokeWidth="2" />
          <text x="720" y="330" fill="#475569" fontSize="10">
            5. Match event pattern
          </text>
          <text x="720" y="345" fill="#64748b" fontSize="9">
            Filter: currentState = "submitted"
          </text>
          <text x="720" y="360" fill="#64748b" fontSize="9">
            Route to target queue
          </text>

          {/* 6. EventBridge to SQS */}
          <path d="M 650 390 L 825 390" stroke="#475569" strokeWidth="2" markerEnd="url(#arrowhead)" />
          <text x="737" y="380" textAnchor="middle" fill="#475569" fontSize="11" fontWeight="bold">
            6. Send to Queue
          </text>

          {/* 7. Return to Lambda */}
          <path d="M 645 420 L 475 420" stroke="#94a3b8" strokeWidth="2" strokeDasharray="4,4" markerEnd="url(#arrowhead-return)" />
          <text x="560" y="410" textAnchor="middle" fill="#64748b" fontSize="10">
            7. Event accepted
          </text>

          {/* 8. Return to API Gateway */}
          <path d="M 465 450 L 295 450" stroke="#94a3b8" strokeWidth="2" strokeDasharray="4,4" markerEnd="url(#arrowhead-return)" />
          <text x="380" y="440" textAnchor="middle" fill="#64748b" fontSize="10">
            8. Success 200
          </text>

          {/* 9. Return to User */}
          <path d="M 285 480 L 115 480" stroke="#94a3b8" strokeWidth="2" strokeDasharray="4,4" markerEnd="url(#arrowhead-return)" />
          <text x="200" y="470" textAnchor="middle" fill="#64748b" fontSize="10">
            9. Response
          </text>

          {/* Separation line */}
          <line x1="40" y1="520" x2="1270" y2="520" stroke="#cbd5e1" strokeWidth="1" strokeDasharray="10,5" />
          <text x="650" y="538" textAnchor="middle" fill="#64748b" fontSize="11" fontStyle="italic">
            Asynchronous Processing (milliseconds to seconds later)
          </text>

          {/* 10. Lambda polling SQS */}
          <path d="M 1010 570 L 835 570" stroke="#475569" strokeWidth="2" markerEnd="url(#arrowhead)" />
          <text x="922" y="560" textAnchor="middle" fill="#475569" fontSize="11" fontWeight="bold">
            10. Poll messages
          </text>
          <text x="922" y="588" textAnchor="middle" fill="#64748b" fontSize="10">
            (SQS trigger / long poll)
          </text>

          {/* 11. SQS returns message */}
          <path d="M 830 610 L 1005 610" stroke="#94a3b8" strokeWidth="2" strokeDasharray="4,4" markerEnd="url(#arrowhead-return)" />
          <text x="917" y="600" textAnchor="middle" fill="#64748b" fontSize="10">
            11. Message batch
          </text>

          {/* 12. Lambda processing */}
          <rect x="990" y="630" width="40" height="100" fill="#8b5cf6" fillOpacity="0.3" stroke="#8b5cf6" strokeWidth="2" />
          <text x="1080" y="660" fill="#475569" fontSize="10">
            12. Process event
          </text>
          <text x="1080" y="678" fill="#64748b" fontSize="9">
            - Parse EventBridge event
          </text>
          <text x="1080" y="693" fill="#64748b" fontSize="9">
            - Execute business logic
          </text>
          <text x="1080" y="708" fill="#64748b" fontSize="9">
            - Start approval workflow
          </text>

          {/* 13. Delete message */}
          <path d="M 1010 740 L 835 740" stroke="#475569" strokeWidth="2" markerEnd="url(#arrowhead)" />
          <text x="922" y="730" textAnchor="middle" fill="#475569" fontSize="11" fontWeight="bold">
            13. Delete message
          </text>
          <text x="922" y="758" textAnchor="middle" fill="#64748b" fontSize="10">
            (on success)
          </text>

          {/* Parallel processing - Spring Boot */}
          <text x="650" y="808" textAnchor="middle" fill="#64748b" fontSize="11" fontStyle="italic">
            In parallel (for different queue / state)
          </text>

          {/* 14. Spring Boot polling */}
          <path d="M 1190 840 L 835 840" stroke="#475569" strokeWidth="2" markerEnd="url(#arrowhead)" />
          <text x="1012" y="830" textAnchor="middle" fill="#475569" fontSize="11" fontWeight="bold">
            14. Poll queue
          </text>
          <text x="1012" y="858" textAnchor="middle" fill="#64748b" fontSize="10">
            (scheduled @1s interval)
          </text>

          {/* 15. Return messages */}
          <path d="M 830 880 L 1185 880" stroke="#94a3b8" strokeWidth="2" strokeDasharray="4,4" markerEnd="url(#arrowhead-return)" />
          <text x="1007" y="870" textAnchor="middle" fill="#64748b" fontSize="10">
            15. Messages
          </text>

          {/* 16. Spring Boot processing */}
          <rect x="1170" y="900" width="40" height="100" fill="#06b6d4" fillOpacity="0.3" stroke="#06b6d4" strokeWidth="2" />
          <text x="1090" y="930" textAnchor="end" fill="#475569" fontSize="10">
            16. Process events
          </text>
          <text x="1090" y="948" textAnchor="end" fill="#64748b" fontSize="9">
            - Deserialize JSON
          </text>
          <text x="1090" y="963" textAnchor="end" fill="#64748b" fontSize="9">
            - Execute business logic
          </text>
          <text x="1090" y="978" textAnchor="end" fill="#64748b" fontSize="9">
            - Update database
          </text>

          {/* 17. Delete messages */}
          <path d="M 1190 1010 L 835 1010" stroke="#475569" strokeWidth="2" markerEnd="url(#arrowhead)" />
          <text x="1012" y="1000" textAnchor="middle" fill="#475569" fontSize="11" fontWeight="bold">
            17. Delete messages
          </text>

          {/* Error handling note */}
          <g>
            <rect x="50" y="1060" width="600" height="30" fill="#fef3c7" stroke="#f59e0b" strokeWidth="1" rx="4" />
            <text x="60" y="1080" fill="#92400e" fontSize="10" fontWeight="bold">
              Error Handling:
            </text>
            <text x="150" y="1080" fill="#92400e" fontSize="9">
              On failure, message returns to queue after visibility timeout. After max retries → DLQ
            </text>
          </g>
        </svg>

        <div className="mt-6 grid grid-cols-2 gap-4">
          <div className="p-4 bg-purple-50 border border-purple-200 rounded-lg">
            <h3 className="font-bold text-purple-900 mb-2">Synchronous Flow (Steps 1-9):</h3>
            <ul className="text-sm text-purple-800 space-y-1 ml-4 list-disc">
              <li>User request → API Gateway → Lambda → EventBridge</li>
              <li>Fast response to user (~100-300ms)</li>
              <li>Event queued for async processing</li>
            </ul>
          </div>
          
          <div className="p-4 bg-green-50 border border-green-200 rounded-lg">
            <h3 className="font-bold text-green-900 mb-2">Asynchronous Flow (Steps 10-17):</h3>
            <ul className="text-sm text-green-800 space-y-1 ml-4 list-disc">
              <li>Consumers poll SQS independently</li>
              <li>Process messages with retries</li>
              <li>Delete on success, requeue on failure</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
};

export default SequenceDiagram;