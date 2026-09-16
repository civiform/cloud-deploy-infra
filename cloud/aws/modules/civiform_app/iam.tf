# The ECS task execution role. It is used as both task_role_arn and
# execution_role_arn on the task definitions, so it needs both the pull/log
# permissions of an execution role and the runtime permissions of a task role.
#
# `count` on the custom policy resources is vestigial: the list always holds
# exactly one element. It is kept because removing it would change the state
# addresses (`[0]` to bare) on top of the move into this module.

locals {
  civiform_ecs_task_execution_role_custom_policies = [
    jsonencode(
      {
        "Version" : "2012-10-17",
        "Statement" : [
          {
            "Effect" : "Allow",
            "Action" : [
              "secretsmanager:GetSecretValue"
            ],
            # Derived from the same ordered list that produces the container's
            # secrets array, so the two can never drift.
            "Resource" : [for secret in var.secrets : secret.secret_arn]
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "kms:Encrypt",
              "kms:Decrypt",
              "kms:ReEncrypt*",
              "kms:GenerateDataKey*",
              "kms:DescribeKey"
            ],
            "Resource" : var.kms_key_arns
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "s3:*"
            ],
            "Resource" : [
              var.file_storage_bucket_arn,
              "${var.file_storage_bucket_arn}/*",
            ]
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "ses:SendEmail"
            ],
            "Resource" : "*"
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "aps:RemoteWrite"
            ],
            "Resource" : "*"
          }
        ]
      }
    )
  ]
}

resource "aws_iam_role" "civiform_ecs_task_execution_role" {
  name               = "${local.name_prefix}-ecs-task-execution-role"
  assume_role_policy = <<JSON
    {
      "Version": "2012-10-17",
      "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ecs-tasks.amazonaws.com"
            },
            "Action": "sts:AssumeRole",
            "Sid": ""
        }
      ]
    }
JSON
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "civiform_ecs_task_execution_role_policy_attach" {
  role       = aws_iam_role.civiform_ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "civiform_ecs_task_execution_role_custom_policy" {
  count       = length(local.civiform_ecs_task_execution_role_custom_policies)
  name        = "${local.name_prefix}-ecs-task-execution-role-custom-policy-${count.index}"
  description = "A custom policy for ${local.name_prefix}-ecs-task-execution-role IAM Role"
  policy      = local.civiform_ecs_task_execution_role_custom_policies[count.index]
  tags        = local.tags
}

resource "aws_iam_role_policy_attachment" "civiform_ecs_task_execution_role_custom_policy" {
  count      = length(local.civiform_ecs_task_execution_role_custom_policies)
  role       = aws_iam_role.civiform_ecs_task_execution_role.name
  policy_arn = aws_iam_policy.civiform_ecs_task_execution_role_custom_policy[count.index].arn
}
