# Research Path — verified archived publication state

This change connects the existing seven-stage Research Path's portfolio stage to the published, operator-pinned HistoricalPortfolioSource already used by the standalone Historical Portfolios screen.

The stage reads the existing validated GET collection with offset=0 and limit=10, uses the returned server-authorized total and reports three distinct outcomes: unpublished/empty, observed historical publications, and unavailable/invalid API. Demo/disconnected mode never establishes verified publication. A non-zero publication count is explicitly **not** an investment eligibility, live performance, PIT/OOS qualification, source custody, or brokerage approval.

The Research Path links to the full historical catalog and never generates a portfolio or synthesizes missing data. The historical API remains opt-in, operator-pinned and loopback-only; iPhone localhost is not Mac localhost. The independent Operational Market stage remains unavailable until its separate snapshot reader is merged and reviewed. Real archive execution, operator approval, physical device testing and approved KRX data capture are not claimed.

Tests cover absent, empty, observed, unavailable and demo stages without silently upgrading evidence.
