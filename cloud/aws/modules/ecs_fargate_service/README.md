# ecs_fargate_service

Runs the CiviForm server as an ECS Fargate service behind an Application Load
Balancer.

These resources used to come from `cn-terraform/ecs-fargate-service/aws`, which
broke us frequently, so they are defined here instead. The `moved` blocks
throughout `main.tf` preserve state addresses across that migration and must not
be removed.

## Load balancer topologies

The module supports two topologies, selected by `create_load_balancer`.

### Dedicated load balancer (default)

`create_load_balancer = true` — the module creates an ALB, its security group,
the HTTP and HTTPS listeners, and optionally an access-log bucket. This is what
`cloud/aws/templates/aws_oidc` uses, and it is the behavior every existing
deployment gets without changing anything.

### Externally managed load balancer

`create_load_balancer = false` — the module creates only the target group, the
ECS service, and the task security group. No ALB, listeners, or LB security
group are created, and `public_subnets` is not needed.

This suits deployers running several CiviForm instances in one account who want
them behind a single shared ALB, sharing one wildcard certificate and domain.

The caller takes on two responsibilities:

1. Pass `existing_lb_security_group_id`, the security group of the shared load
   balancer. The module uses it to allow ingress to the ECS tasks on
   `https_target_port`, so the tasks accept traffic only from that load
   balancer.
2. Route traffic to the target group exposed by the `lb_https_target_group_arn`
   output. The module deliberately does not create a listener rule: routing
   policy (host header vs. path pattern, rule priority) belongs to whoever owns
   the shared listener.

```hcl
module "civiform_service" {
  source = "../../modules/ecs_fargate_service"

  create_load_balancer          = false
  existing_lb_security_group_id = aws_security_group.shared_alb.id

  app_prefix          = "sandbox-42"
  vpc_id              = var.vpc_id
  private_subnets     = var.private_subnet_ids
  ecs_cluster_arn     = aws_ecs_cluster.shared.arn
  ecs_cluster_name    = aws_ecs_cluster.shared.name
  task_definition_arn = aws_ecs_task_definition.civiform.arn
  container_name      = "sandbox-42-civiform"
}

resource "aws_lb_listener_rule" "civiform_service" {
  listener_arn = aws_lb_listener.shared_https.arn
  priority     = 42

  action {
    type             = "forward"
    target_group_arn = module.civiform_service.lb_https_target_group_arn
  }

  condition {
    host_header {
      values = ["sandbox-42.example.org"]
    }
  }
}
```

The `https_listener_arn`, `aws_lb_civiform_lb_arn`, and
`aws_security_group_lb_access_sg_id` outputs are `null` in this topology.

## Naming constraints

Target group names are capped at 32 characters by AWS. Since the name is
`"${app_prefix}-https-${https_target_port}"`, `app_prefix` must be at most 21
characters for the default port. A precondition on the target group catches this
at plan time.

## Tests

`tests/external_lb/topologies.tftest.hcl` is a plan-only `terraform test`
suite. Every run block plans the module against a mocked `aws` provider, so it
needs no credentials, backend, or state, and nothing is ever applied. It
covers:

- The external topology: no ALB, listeners, LB security group, or access-log
  bucket; the three LB outputs are `null`; task ingress is sourced from
  `existing_lb_security_group_id`.
- The default topology: one of each LB resource; task ingress is sourced from
  the module-managed security group.
- `lb_logging_enabled` creates the access-log bucket only when the module also
  creates the load balancer.
- `enable_http_listener = false` drops the HTTP listener and its ingress rule.
- Both target group preconditions, through `expect_failures`, plus a passing
  run at the 21-character `app_prefix` cap.

The run blocks plan the module directly rather than through the fixture root's
module call, because assertions can only address resources in the module under
test, not inside a child module. Init still happens in `tests/external_lb`, so
the fixture's provider pin is the one the suite runs against; the module itself
pins nothing. `tests/external_lb/main.tf` also remains a validate-only root
that exercises the external-load-balancer path, which no deployment template
currently uses.

`bin/validate` runs the suite after validating the fixture. To run it alone:

```sh
terraform -chdir=cloud/aws/modules/ecs_fargate_service/tests/external_lb init -backend=false
terraform -chdir=cloud/aws/modules/ecs_fargate_service/tests/external_lb test
```
