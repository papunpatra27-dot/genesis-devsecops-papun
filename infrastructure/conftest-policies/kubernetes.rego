# OPA/Conftest policies for Kubernetes manifest validation
# Enforces guardrails beyond standard Kyverno admission control.
# Run: conftest test --policy infrastructure/conftest-policies/ k8s/
#
# Guardrails implemented:
#   1. All Deployments/Rollouts must have a liveness probe configured.
#   2. No Namespace may be named "default" for application workloads.
#   3. All Services of type LoadBalancer must carry a cost-centre annotation.
#   4. All Deployments/Rollouts must have at least one replica.

package main

import future.keywords.if
import future.keywords.in

##############################################################################
# Guardrail 1 — Liveness probe required on all Deployments and Rollouts
##############################################################################
deny[msg] if {
  input.kind in {"Deployment", "Rollout"}
  container := input.spec.template.spec.containers[_]
  not container.livenessProbe
  msg := sprintf(
    "%s '%s': container '%s' is missing a livenessProbe. Add a livenessProbe to detect hung processes.",
    [input.kind, input.metadata.name, container.name],
  )
}

##############################################################################
# Guardrail 2 — Application workload Namespaces must not be named "default"
##############################################################################
deny[msg] if {
  input.kind == "Namespace"
  input.metadata.name == "default"
  msg := "Namespace 'default' must not be used for application workloads. Create a dedicated namespace (e.g., staging, production)."
}

# Also block Deployments/Rollouts from being placed in the default namespace
deny[msg] if {
  input.kind in {"Deployment", "Rollout"}
  input.metadata.namespace == "default"
  msg := sprintf(
    "%s '%s' is deployed into the 'default' namespace. Move it to a dedicated application namespace.",
    [input.kind, input.metadata.name],
  )
}

##############################################################################
# Guardrail 3 — Services of type LoadBalancer must carry a cost-centre annotation
##############################################################################
deny[msg] if {
  input.kind == "Service"
  input.spec.type == "LoadBalancer"
  not input.metadata.annotations["cost-centre"]
  msg := sprintf(
    "Service '%s' is of type LoadBalancer but is missing the 'cost-centre' annotation. Add 'cost-centre: <team>' to track cloud spend.",
    [input.metadata.name],
  )
}

##############################################################################
# Guardrail 4 — Deployments must declare at least one replica explicitly
##############################################################################
deny[msg] if {
  input.kind == "Deployment"
  replicas := object.get(input.spec, "replicas", 0)
  replicas < 1
  msg := sprintf(
    "Deployment '%s' must explicitly set spec.replicas >= 1.",
    [input.metadata.name],
  )
}

##############################################################################
# Warnings (non-blocking)
##############################################################################
warn[msg] if {
  input.kind in {"Deployment", "Rollout"}
  container := input.spec.template.spec.containers[_]
  not container.readinessProbe
  msg := sprintf(
    "%s '%s': container '%s' has no readinessProbe. Traffic may be routed before the container is ready.",
    [input.kind, input.metadata.name, container.name],
  )
}
