#------------------------------------------------------------------------------
# Misc
#------------------------------------------------------------------------------
variable "app_prefix" {
  type        = string
  description = "App prefix for naming resources in AWS. For most resources, -civiform is appended to this string."
}

variable "aws_region" {
  type        = string
  description = "Region the task runs in. Used for the awslogs log driver and the metrics scraper."
}

variable "tags" {
  type        = map(string)
  description = "Additional resource tags, merged over the module's defaults."
  default     = {}
}

#------------------------------------------------------------------------------
# CiviForm server container
#------------------------------------------------------------------------------
variable "civiform_image_repo" {
  type        = string
  description = "Docker repository with CiviForm images."
  default     = "civiform/civiform"
}

variable "image_tag" {
  type        = string
  description = "Image tag of the CiviForm docker image to deploy."
  default     = "prod"
}

variable "port" {
  type        = string
  description = "Port the CiviForm server listens on."
  default     = "9000"
}

variable "ecs_server_container_memory" {
  type        = number
  description = "The amount (in MiB) of memory to present to the server container."
  default     = 4096
}

variable "ecs_server_container_memory_reservation" {
  type        = number
  description = "The soft limit (in MiB) of memory to reserve for the server container."
  default     = 2048
}

variable "civiform_server_environment_variables" {
  type        = map(string)
  description = "CiviForm server environment variables passed directly to the container environment. Merged over the variables the module sets itself."
  default     = {}
}

variable "log_group_name" {
  type        = string
  description = "CloudWatch log group the server container logs to. The module does not create the group; the awslogs driver is configured with awslogs-create-group."
}

#------------------------------------------------------------------------------
# Metrics scraper container
#------------------------------------------------------------------------------
variable "scraper_image" {
  type        = string
  description = "Fully qualified image tag for the metrics scraper."
  default     = "docker.io/civiform/aws-metrics-scraper:latest"
}

variable "ecs_metrics_scraper_container_memory" {
  type        = number
  description = "The amount (in MiB) of memory to present to the metrics scraper container."
  default     = 2048
}

variable "ecs_metrics_scraper_container_memory_reservation" {
  type        = number
  description = "The soft limit (in MiB) of memory to reserve for the metrics scraper container."
  default     = 1024
}

variable "prometheus_remote_write_endpoint" {
  type        = string
  description = "Prometheus remote write endpoint the metrics scraper pushes to, including the api/v1/remote_write path. Empty when no monitoring stack is deployed."
  default     = ""
}

variable "scraper_log_group_name" {
  type        = string
  description = "CloudWatch log group the metrics scraper container logs to. The module does not create the group; the awslogs driver is configured with awslogs-create-group."
}

#------------------------------------------------------------------------------
# Task definitions
#------------------------------------------------------------------------------
variable "ecs_task_cpu" {
  type        = number
  description = "CPU of each ECS task. See [these docs](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html#fargate-tasks-size) for potential values."
  default     = 1024
}

variable "ecs_task_memory" {
  type        = number
  description = "Memory of each ECS task. See [these docs](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html#fargate-tasks-size) for potential values."
  default     = 6144
}

#------------------------------------------------------------------------------
# Resources the app consumes. The module reads these; it does not create them.
#------------------------------------------------------------------------------
variable "secrets" {
  description = <<-EOT
    Secrets injected into the CiviForm container and granted to the task
    execution role.

      name       - environment variable name read by the CiviForm server
      value_arn  - ARN of the secret *version*, referenced by the container
      secret_arn - ARN of the secret itself, granted to the execution role

    Order is significant. It determines the order of the `secrets` array in the
    generated container definition; reordering produces a new task definition
    revision and therefore a rolling redeploy.
  EOT

  type = list(object({
    name       = string
    value_arn  = string
    secret_arn = string
  }))
}

variable "db_jdbc_string" {
  type        = string
  description = "Full JDBC connection string for the CiviForm database, including query parameters. For example jdbc:postgresql://HOST:PORT/postgres?ssl=true&sslmode=require."
}

variable "file_storage_bucket_name" {
  type        = string
  description = "Name of the S3 bucket holding applicant-uploaded files."
}

variable "file_storage_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket holding applicant-uploaded files. Granted to the task execution role, along with its contents."
}

variable "public_file_storage_bucket_name" {
  type        = string
  description = "Name of the S3 bucket holding publicly readable files, such as program images."
}

variable "kms_key_arns" {
  type        = list(string)
  description = "KMS key ARNs the task execution role may encrypt and decrypt with. Typically the key protecting the secrets and the key protecting the file storage bucket."

  validation {
    condition     = length(var.kms_key_arns) > 0
    error_message = "At least one KMS key ARN is required; an IAM statement with an empty resource list is invalid."
  }
}
