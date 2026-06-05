# Datadog Strategy Document

## Data Model Translation: Prometheus Labels vs Datadog Tags

Prometheus models time series as a metric name plus a set of key-value label pairs. Every unique label combination is a distinct time series stored in Prometheus's TSDB. The `genesis_units_created_total` metric with a `tenant_id` label generates one time series per tenant, e.g. `genesis_units_created_total{tenant_id="acme-corp"}`. Aggregating across tenants uses PromQL's `sum by()` or `without()` operators on the label dimension.

Datadog's equivalent concept is **tags**. A tag is a `key:value` string attached to a metric data point at collection time. The conceptual difference is subtle but important: Prometheus labels are part of the metric's identity (they define the time series); Datadog tags are metadata that can be added, changed, or filtered after the fact using the Datadog platform's query engine. When migrating `genesis_units_created_total{tenant_id="acme-corp"}` to Datadog, the metric would be emitted as `genesis.units.created.total` with the tag `tenant_id:acme-corp`. The Datadog Agent (or a StatsD client using `dogstatsd-python`) handles tag attachment.

**What changes in migration:** the Prometheus client library call `UNITS_CREATED_TOTAL.labels(tenant_id=tenant_id).inc()` becomes `statsd.increment("genesis.units.created.total", tags=[f"tenant_id:{tenant_id}"])`. The cardinality concern is identical — high-cardinality tenant IDs must be bounded or Datadog's Custom Metrics pricing escalates quickly. In Prometheus, high cardinality is a storage problem; in Datadog it is a billing problem. Both require the same engineering discipline: enumerate expected tenant IDs, reject unknown values at the application boundary.

## Dashboard Migration: Grafana (PromQL) → Datadog

The Grafana error rate panel uses this PromQL expression:

```
100 * sum(rate(http_requests_total{namespace="staging",status_code=~"5.."}[5m]))
     / sum(rate(http_requests_total{namespace="staging"}[5m]))
```

In Datadog, the equivalent uses the **Metrics Query** editor with Datadog Query Language (DQL):

```
100 * (sum:http.requests.total{namespace:staging, status_code:5*}.as_rate() /
       sum:http.requests.total{namespace:staging}.as_rate())
```

**What changes:** the filter syntax switches from PromQL label matchers `{}` to Datadog tag filters `{}` using `key:value` format. Regex matching (`status_code=~"5.."`) becomes wildcard matching (`status_code:5*`). The `rate()` window is implicit in Datadog's `as_rate()` — it uses the rollup interval set on the widget.

**What stays conceptually equivalent:** division of filtered sum by total sum, multiplication by 100 to get a percentage.

**Datadog-specific capabilities that improve this panel:**

- The **SLO Widget** natively renders error budget burn rate alongside the error rate — no custom PromQL arithmetic required.
- **Formula functions** like `clamp_min()` prevent display anomalies when the denominator is zero (a problem that requires `or vector(0)` workarounds in PromQL).
- **Anomaly detection** (`anomalies()`) can overlay ML-based baseline bands without requiring a separate recording rule.

## Alerting Translation: PrometheusRule + Alertmanager → Datadog Monitors

The fast-burn alert in `k8s/prometheus-rules.yaml` is a PrometheusRule CRD evaluated by the Prometheus Operator, routed through Alertmanager to PagerDuty/Slack. The Datadog equivalent is a **Metric Monitor** (type: `metric alert`) with a threshold condition on the error rate metric. For the burn-rate alert specifically, Datadog's built-in **SLO Alert Monitor** is a direct equivalent — it natively understands fast and slow burn windows without requiring the engineer to manually calculate the 14× multiplier.

The **Datadog advantage over the manual Prometheus setup:** in Prometheus, multi-window burn rate alerting requires writing and maintaining separate PrometheusRule expressions for each window, testing them in a local Prometheus, and configuring Alertmanager routing separately. In Datadog, the SLO Alert Monitor generates the fast/slow burn alerts from a single SLO definition — the math is built into the platform. Composite monitors (alert only when fast burn AND slow burn are both elevated) are a UI toggle in Datadog vs. multi-step PromQL in Prometheus.

For pod crash-loop alerts, the Datadog equivalent is a **Live Process Monitor** or a **Kubernetes Integration Monitor** (auto-configured when the Datadog Agent is installed with the Kubernetes integration).

## Honest Gap Assessment — 30-Day Learning Plan

Areas I understand conceptually from the Prometheus/Grafana work, which map closely to Datadog:

- **Metrics and dashboards**: the mental model (time series, aggregation, percentile histograms) transfers directly. DQL syntax is the learning curve, estimated 3-5 days.
- **Alerting**: threshold-based and burn-rate alerting concepts map 1:1. Datadog Monitor types and routing configuration need hands-on time — 2-3 days.
- **Log management**: Loki (in-cluster) experience gives familiarity with log querying concepts. Datadog Logs uses a similar filter/facet model but with a proprietary query syntax and the Log Archives / Rehydration pattern is new to me — 3-4 days.

Areas that are genuinely new and require structured learning:

- **APM (Application Performance Monitoring)**: distributed traces, flame graphs, service maps. I understand the concept (OpenTelemetry) but have not operated Datadog APM instrumentation. Instrumenting the FastAPI app with `ddtrace` and reading trace data would take 4-5 days of hands-on work.
- **RUM (Real User Monitoring)**: browser-side session replay and Core Web Vitals. No current experience — not applicable to an API-only service but important for the wider role. Estimated 3-4 days to reach productive proficiency.
- **Synthetics**: API and browser tests that run on Datadog's global infrastructure. Conceptually similar to Playwright tests but managed externally. Would replace the Stage 13 smoke test with a persistent synthetic monitor — 2-3 days.
- **Custom Metrics pricing and cardinality management**: Prometheus is self-hosted so cardinality is an engineering problem. Datadog charges per custom metric (p95 usage). I understand the billing model conceptually but have not managed it in a real production account — this requires hands-on experience with the Metrics Summary UI and estimated cardinality dashboards.

Total estimated ramp time to productive contribution: 3-4 weeks with access to a Datadog trial account and the existing Genesis platform as the instrumentation target.
