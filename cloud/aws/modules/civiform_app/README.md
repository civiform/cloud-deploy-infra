# civiform_app

The CiviForm compute layer: the server container definition, the optional
metrics scraper container definition, both ECS task definitions, and the ECS
task execution role.

Pair it with `ecs_fargate_service` to run CiviForm on Fargate. Everything the
app consumes — secrets, buckets, KMS keys, the database, log groups — is an
input, so a caller can point several instances of this module at shared
infrastructure.

```hcl
module "civiform_app" {
  source = "../../modules/civiform_app"

  app_prefix = "sandbox-42"
  aws_region = "us-east-1"

  log_group_name         = "sandbox-42-civiformlogs/"
  scraper_log_group_name = "sandbox-42-civiform-scraper-logs/"

  secrets                         = local.civiform_secrets
  db_jdbc_string                  = "jdbc:postgresql://${aws_db_instance.civiform.address}:${aws_db_instance.civiform.port}/postgres?ssl=true&sslmode=require"
  file_storage_bucket_name        = aws_s3_bucket.files.id
  file_storage_bucket_arn         = aws_s3_bucket.files.arn
  public_file_storage_bucket_name = aws_s3_bucket.public_files.id
  kms_key_arns                    = [aws_kms_key.secrets.arn, aws_kms_key.files.arn]
}

module "civiform_service" {
  source = "../../modules/ecs_fargate_service"

  task_definition_arn = module.civiform_app.civiform_only_task_definition_arn
  container_name      = module.civiform_app.server_container_name
  # ... networking, cluster, load balancer
}
```

## The `secrets` input

`secrets` is the one input worth reading carefully. Each element carries three
fields:

| Field | Used by |
|---|---|
| `name` | Environment variable name read by the CiviForm server |
| `value_arn` | ARN of the secret **version**, referenced by the container definition |
| `secret_arn` | ARN of the **secret**, granted to the task execution role |

The module derives both the container's `secrets` array and the execution
role's `secretsmanager:GetSecretValue` statement from this single list. Before
this module existed, those two lists were written out separately in
`aws_oidc/app.tf`, 150 lines apart and in different orders, so adding a secret
meant editing both — and forgetting the second produced a container with a
valid `valueFrom` that the execution role could not read, which fails at task
start with an error that points at ECS rather than IAM.

**It is a list, not a map, and the order matters.** Terraform iterates map keys
in lexical order, which would re-sort the container's `secrets` array and change
the `jsonencode` output, forcing a new task definition revision and a rolling
redeploy on the next apply. A list preserves the caller's order.

## Both task definitions are always created

`civiform_only` and `civiform_with_monitoring` are both created regardless of
whether a monitoring stack exists; the caller chooses which one to run by
picking an output. Task definitions cost nothing when no service references
them, and creating both unconditionally is what `aws_oidc` has always done —
gating them on a variable would destroy one of them on existing deployments.

When there is no Prometheus workspace, leave `prometheus_remote_write_endpoint`
unset and use `civiform_only_task_definition_arn`.

## The task execution role

The role is used as both `task_role_arn` and `execution_role_arn`, so it holds
the pull-and-log permissions of an execution role alongside the runtime
permissions of a task role: reading the secrets, using the KMS keys, full
access to the file storage bucket, `ses:SendEmail`, and `aps:RemoteWrite`.

`task_execution_role_arn` is exported because S3 bucket policies need to name
the principal they grant access to. That is not a dependency cycle: this module
depends on the *bucket*, while the *bucket policy* depends on this module, and
Terraform resolves dependencies per resource rather than per module.

## State migration

The resources here were moved out of `cloud/aws/templates/aws_oidc/app.tf`. The
`moved` blocks in that root preserve their state addresses across the
extraction and must not be removed — without them, every existing deployment
would destroy and recreate its IAM role and both task definitions.

The two `cloudposse/ecs-container-definition/aws` module calls need no `moved`
block. That module declares no resources or data sources; it computes JSON and
holds no state.
