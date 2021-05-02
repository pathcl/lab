# Deploy

    $ make init
    $ make build

## Why?

I decided to go for terraform/helm since it provides a good level of abstraction around a common language: HCL. Also providers (helm/kubernetes/acme)
has been improved lately. Having one single tool reduces the cognitive load.

[Keda](https://keda.sh) thesedays already supports prometheus metrics as one source of scaling applications. Compared to common HPA gives much more granularity basically we can instrument our application as we want and then describe an ScaledObject referring to which metric should be used.

Modsecurity and nginx was configured on defaults but is enough to prove it works against common threats.

Dashboard was taken from grafana.com [nginx-ingress](https://grafana.com/grafana/dashboards/9614).

Regarding performance/security protections there's some configuration around LimitRange, NetworkPolicies, PodDisruptionBudget. Kyverno/OPA might also be worth considering.


## TODO: 

- grafana dashboards red/use 
- external-dns
- kyverno
- gh actions/tf cloud
