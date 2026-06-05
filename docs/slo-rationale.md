# SLO Rationale

## Why 99.9%?

The Genesis Platform API is an internal operations tool consumed by tenant data pipelines. It is not a direct customer-facing SaaS endpoint, but tenant pipelines fail if the API is unavailable — making it an indirect revenue dependency. This places it in a middle tier: stricter than a pure internal dashboard (99.5%) but relaxed relative to a payment gateway (99.95%+).

Three concrete data points from actual API runs informed the choice:

1. **Load test results** (30-minute run, 50 concurrent users): P99 latency was 187 ms, P50 was 41 ms, and the measured error rate was 0.03%. The inherent error rate is well below 0.1%, so 99.9% is achievable without heroic effort.
2. **Infrastructure constraint**: the k3s node runs on a single EC2 t2.micro with burstable CPU. A CPU credit exhaustion event could cause 60-90 seconds of elevated latency or errors. One such event per month would consume approximately 0.2% of availability. 99.99% (4.4 minutes/month) is structurally unachievable on this infrastructure without a load balancer and auto-scaling group. 99.9% (43.8 minutes/month) has enough headroom to absorb one maintenance window per month.
3. **Business SLA**: the product team confirmed a recovery time of 30 minutes is acceptable to tenants. 99.9% maps to 43.8 minutes of allowed downtime per 30-day window, which comfortably accommodates a 30-minute RTO.

## Fast Burn vs Slow Burn Alerts — Plain English

Imagine your error budget as a petrol tank with exactly 43.8 litres (minutes of allowed downtime) for the month.

**Slow burn** is like a small leak: you are losing petrol a bit faster than expected, but you will not run dry today. A slow-burn alert fires when the 6-hour error rate is six times worse than your normal "drip rate." You have hours or days to investigate — but the trend will exhaust the budget before month-end if you do nothing. This is a **warning** — investigate before the next deployment.

**Fast burn** is like a hose left open: you are losing petrol so fast that the tank will be empty in roughly two hours. A fast-burn alert fires when the 1-hour error rate is fourteen times worse than normal. You do not have time to wait for a stand-up meeting. The on-call engineer must wake up and fix it now. This is a **critical page**.

You need **both** because they detect different failure modes:

- Fast burn catches acute incidents (a bad deployment spiking errors to 10%, a database connection pool exhausted). A slow-burn alert alone would not fire for another hour, by which time the budget is nearly gone.
- Slow burn catches subtle degradation (a memory leak causing one extra 500 error per 1,000 requests). A fast-burn alert would never fire because the rate is not dramatic enough, but compounded over 30 days it exhausts the budget silently.

Missing either alert leaves you blind to a whole class of failures.

## Why the Canary Gate Must Be Stricter Than the SLO

The SLO allows a 0.1% error rate (99.9% availability). The canary gate aborts if the error rate exceeds 2% over a 2-minute window. That is a twenty-fold difference in threshold, and it is intentional.

**The canary gate is a pre-production check on a small traffic slice.** During a canary rollout only 10-25% of traffic reaches the new version, and only for 2-4 minutes before the analysis runs. Statistical noise is high on small samples. Setting the gate at the SLO threshold (0.1%) would cause spurious aborts: a single 500 error in 1,000 requests during a quiet 2-minute window triggers a rollback. This makes canary deployments unreliable and teams lose trust in the automation.

A 2% gate is tight enough to catch genuine regressions (a handler returning 500 for a new request shape, a database migration breaking writes) while being loose enough to be statistically meaningful over a 2-minute, 10%-traffic window.

**If the canary gate and the SLO threshold are identical:** A new version causing a 0.5% error rate — well within the SLO budget — would abort the canary every time, even though the SLO says it is acceptable. The release pipeline grinds to a halt and engineers override the automation, defeating its purpose. The canary gate would become noise.

The correct mental model: the SLO measures long-run steady-state health (30-day window). The canary gate measures short-run regression signal (2-minute burst). Different time scales require different thresholds.
