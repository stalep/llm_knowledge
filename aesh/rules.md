## Use TestConnection() not TestConnection(false) for plain-text test assertions
aesh-readline 3.2+ emits bracketed paste and OSC 133 escape sequences. TestConnection() strips these by default; TestConnection(false) captures raw bytes and breaks text assertions.
Promoted from hypothesis: 2026-04-10
Confirmations: 3
