
```mermaid
flowchart LR
  subgraph DhanHQ_Gem["dhanhq-client (gem)"]
    A[WS::Client] --> B[WS::Connection]
    B --> C{Dhan Feed<br/>wss://api-feed.dhan.co}
    B --> D[WebsocketPacketParser + Packets]
    D --> E[Decoder -> normalized tick]
    A -->|:tick| E
  end

  subgraph Rails_API["Rails API app"]
    E --> F[WSSupervisor]
    F --> G[TickCache (latest LTP)]
    F --> H[TickBus]
    F --> I[CandleAggregator (5m)]
    I -->|bar close| J[Strategy::SupertrendOptionLong]
    F --> K[CloseStrikesManager (ATM ±1 manager)]
    J --> L[ExecutionIntent + Signal (DB)]
    J --> M[Execution::DhanRouter]
    M -->|try SuperOrder| N((Dhan Super Orders))
    M -->|fallback| O[Market BUY + LocalTrailing]
    O --> G
    subgraph Backoffice
      P[SyncLoop] --> Q[(Positions/Holdings DB)]
    end
  end

  C -.binary frames.-> D
  K -->|subscribe CE/PE| A
  M -->|REST| N
  P -->|REST| Q

```
