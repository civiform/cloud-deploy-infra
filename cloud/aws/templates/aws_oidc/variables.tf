variable "civiform_server_environment_variables" {
  type        = map(string)
  description = "CiviForm server environment variables set in civiform_config.sh that are passed directly to the container environment."
  default     = {}
}

variable "aws_region" {
  type        = string
  description = "Region where the AWS servers will live"
  default     = "us-east-1"
}

variable "civiform_image_repo" {
  type        = string
  description = "Dockerhub repository with Civiform images"
  default     = "civiform/civiform"
}

variable "image_tag" {
  type        = string
  description = "Image tag of the Civiform docker image to deploy"
  default     = "prod"
}

variable "scraper_image" {
  type        = string
  description = "Fully qualified image tag for the metrics scraper"
  default     = "docker.io/civiform/aws-metrics-scraper:latest"
}

variable "civiform_time_zone_id" {
  type        = string
  description = "Time zone for Civiform server to use when displaying dates."
  default     = "America/Los_Angeles"
}

variable "civic_entity_short_name" {
  type        = string
  description = "Short name for civic entity (example: Rochester, Seattle)."
  default     = "Dev Civiform"
}

variable "civic_entity_full_name" {
  type        = string
  description = "Full name for civic entity (example: City of Rochester, City of Seattle)."
  default     = "City of Dev Civiform"
}

variable "civic_entity_support_email_address" {
  type        = string
  description = "Email address where applicants can contact civic entity for support with Civiform."
  default     = "azizoval@google.com"
}

variable "civic_entity_logo_with_name_url" {
  type        = string
  description = "Logo with name used on the applicant-facing program index page"
  default     = "https://raw.githubusercontent.com/civiform/staging-azure-deploy/main/logos/civiform-staging-long.png"
}

variable "vpc_name" {
  type        = string
  description = "Name of the VPC"
  default     = "civiform-vpc"
}

variable "vpc_cidr" {
  type        = string
  description = "Cidr for VPC"
  default     = "10.0.0.0/16"
}

variable "private_subnets" {
  type        = list(string)
  description = "List of the private subnets for the VPC"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "database_subnets" {
  type        = list(string)
  description = "List of the database subnets for the VPC"
  default     = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
}

variable "public_subnets" {
  type        = list(string)
  description = "List of the public subnets for the VPC"
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "postgress_name" {
  type        = string
  description = "Name for Postress DB"
  default     = "civiform"
}

variable "postgres_instance_class" {
  type        = string
  description = "The instance class for postgres server"
  default     = "db.t3.micro"
}

variable "postgres_storage_gb" {
  type        = number
  description = "The gb of storage for postgres instance. If max_allocated_storage is configured, this argument represents the initial storage allocation and differences from the configuration will be ignored automatically when Storage Autoscaling occurs."
  default     = 5
}

variable "postgres_max_allocated_storage_gb" {
  type        = number
  description = "(Optional) When configured, the upper limit to which Amazon RDS can automatically scale the storage of postgres. Configuring this will automatically ignore differences to allocated_storage. Must be greater than or equal to allocated_storage or 0 to disable Storage Autoscaling."
  default     = null
}

variable "postgres_backup_retention_days" {
  type        = number
  description = "Number of days to retain postgres backup"
  default     = 7
}

variable "postgres_restore_snapshot_identifier" {
  type        = string
  description = "If not null, destroys the current database, replacing it with a new one restored from the provided snapshot"
  default     = null
}

variable "rds_performance_insights_enabled" {
  type        = bool
  description = "Whether or not to enable RDS performance insights for debugging purposes. Note: this may incur charges within AWS."
  default     = false
}

variable "rds_enhanced_monitoring_enabled" {
  type        = bool
  description = "Whether or not to enable RDS enhanced monitoring for debugging purposes. Note: this may incur charges within AWS."
  default     = false
}

variable "rds_enhanced_monitoring_interval" {
  type        = number
  description = "The monitoring interval to use for enhanced monitoring, if it is enabled."
  default     = 60
}

variable "rds_alarm_email" {
  type        = string
  description = "The address to notify when any enabled RDS alarm alerts. If unset, no emails will be sent."
  default     = ""
}

variable "rds_alarm_evaluation_period" {
  type        = string
  description = "The number of the most recent statistic periods, or data points, to evaluate when determining RDS alarm state."
  default     = "5"
}

variable "rds_alarm_statistic_period" {
  type        = string
  description = "The length of time to use to evaluate the metric or expression to create each individual data point for an RDS alarm. It is expressed in seconds."
  default     = "60"
}

variable "rds_create_high_cpu_alarm" {
  type        = bool
  description = "Whether or not to create a high CPU alarm for RDS."
  default     = true
}

variable "rds_max_cpu_utilization_threshold" {
  type        = string
  description = "The threshold for max CPU utilization for the database before the alarm gets triggered (if enabled)."
  default     = "90"
}

variable "rds_create_high_queue_depth_alarm" {
  type        = bool
  description = "Whether or not to create a high queue depth alarm for RDS."
  default     = true
}

variable "rds_disk_queue_depth_high_threshold" {
  type        = string
  description = "The threshold for the disk queue depth before the alarm gets triggered (if enabled)."
  default     = "64"
}

variable "rds_create_low_disk_space_alarm" {
  type        = bool
  description = "Whether or not to create a low disk space alarm for RDS."
  default     = true
}

variable "rds_disk_free_storage_low_threshold" {
  type        = string
  description = "The threshold for the free disk storage space (in bytes) before the alarm gets triggered (if enabled)."
  default     = "500000000" // ~500 MB
}

variable "rds_create_low_memory_alarm" {
  type        = bool
  description = "Whether or not to create a low memory free alarm for RDS."
  default     = true
}

variable "rds_low_memory_threshold" {
  type        = string
  description = "The threshold for the low freeable memory (in bytes) before the alarm gets triggered (if enabled)."
  default     = "150000000" // ~150 MB
}

variable "rds_create_low_cpu_credit_alarm" {
  type        = bool
  description = "Whether or not to create a low CPU credit alarm for RDS. This alarm type only applies for T-type database instances."
  default     = false
}

variable "rds_low_cpu_credit_balance_threshold" {
  type        = string
  description = "The threshold for the low CPU credit balance before the alarm gets triggered (if enabled)."
  default     = "100"
}

variable "rds_create_low_disk_burst_alarm" {
  type        = bool
  description = "Whether or not to create a low disk burst alarm for RDS."
  default     = false
}

variable "rds_disk_burst_balance_low_threshold" {
  type        = string
  description = "The threshold for the low disk burst balance before the alarm gets triggered (if enabled)."
  default     = "100"
}

variable "rds_create_swap_alarm" {
  type        = bool
  description = "Whether or not to create a high swap usage alarm for RDS."
  default     = false
}

variable "rds_high_swap_usage_threshold" {
  type        = string
  description = "The threshold for the max swap usage before the alarm gets triggered (if enabled)."
  default     = "256000000" // ~256 MB
}

variable "rds_create_anomaly_alarm" {
  type        = bool
  description = "Whether or not to create an anomaly alarm for RDS (fairly noisy)."
  default     = false
}

variable "rds_anomaly_bandwidth" {
  type        = string
  description = "The width of the anomaly band, default 2.  Higher numbers means less sensitive."
  default     = "2"
}

variable "rds_anomaly_period" {
  type        = string
  default     = "600"
  description = "The number of seconds that make each evaluation period for anomaly detection."
}

variable "rds_create_transaction_id_wraparound_alarm" {
  type        = bool
  description = "Whether or not to create a transaction ID wraparound alarm for postgres. More information can be found [here](https://aws.amazon.com/blogs/database/implement-an-early-warning-system-for-transaction-id-wraparound-in-amazon-rds-for-postgresql/)."
  default     = false
}

variable "rds_max_used_transaction_ids_high_threshold" {
  type        = string
  description = "The threshold for the maximum transaction IDS before the alarm gets triggered. This is to prevent [transaciton ID wraparound](https://aws.amazon.com/blogs/database/implement-an-early-warning-system-for-transaction-id-wraparound-in-amazon-rds-for-postgresql/)"
  default     = "1000000000" // 1 billion. Half of total.
}

variable "aws_db_storage_type" {
  type        = string
  description = "(Optional) One of 'standard' (magnetic), 'gp2' (general purpose SSD), 'gp3' (general purpose SSD that needs iops independently) or 'io1' (provisioned IOPS SSD). The default is 'io1' if iops is specified, 'gp2' if not."
  default     = null
}

variable "aws_db_storage_throughput" {
  type        = number
  description = "(Optional) The storage throughput value for the DB instance. Can only be set when storage_type is 'gp3'. Cannot be specified if the allocated_storage value is below a per-engine threshold. See the [RDS User Guide](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Storage.html#gp3-storage) for details."
  default     = null
}

variable "aws_db_iops" {
  type        = number
  description = "(Optional) The amount of provisioned IOPS. Setting this implies a storage_type of 'io1'. Can only be set when storage_type is 'io1' or 'gp3'. Cannot be specified for gp3 storage if the allocated_storage value is below a per-engine threshold. See the [RDS User Guide](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Storage.html#gp3-storage) for details."
  default     = null
}

variable "staging_program_admin_notification_mailing_list" {
  type        = string
  description = "Admin notification mailing list for staging"
  default     = null
}

variable "staging_ti_notification_mailing_list" {
  type        = string
  description = "intermediary notification mailing list for staging"
  default     = null
}

variable "sender_email_address" {
  type        = string
  description = "Email address that emails will be sent from"
  default     = null
}

variable "staging_applicant_notification_mailing_list" {
  type        = string
  description = "Applicant notification mailing list for staging"
  default     = null
}

variable "app_prefix" {
  type        = string
  description = "A prefix to add to values so we can have multiple deploys in the same aws account"
  default     = null
}

variable "applicant_oidc_provider_logout" {
  type        = bool
  description = "If the applicant OIDC logout should also perform a central logout from the auth provider"
  default     = true
}

variable "applicant_oidc_override_logout_url" {
  type        = string
  description = "The URL to use for the OIDC logout endpoint (when applicant_oidc_provider_logout is true).  If not set, uses the `end_session_endpoint` value from the discovery metadata."
  default     = null
}

variable "applicant_oidc_post_logout_redirect_param" {
  type        = string
  description = "What query parameter to use for sending the redirect uri to the central OIDC provider for logout (when applicant_oidc_provider_logout is true). Defaults to post_logout_redirect_uri"
  default     = "post_logout_redirect_uri"
}

variable "applicant_oidc_logout_client_param" {
  type        = string
  description = "What query parameter to use for sending the client id to the central OIDC provider for logout (when applicant_oidc_provider_logout is true).  If left blank, doesn't send the client id."
  default     = null
}

variable "ad_groups_attribute_name" {
  type        = string
  description = "Key of authentication id_token map that contains list of groups that user belongs to."
  default     = "group"
}

variable "custom_hostname" {
  type        = string
  description = "The custom hostname this app is deployed on"
  default     = "staging-aws.civiform.dev"
}

variable "staging_hostname" {
  type        = string
  description = "If provided will enable DEMO mode on this hostname"
  default     = "staging-aws.civiform.dev"
}

variable "base_url" {
  type        = string
  description = "Base url for the app, only need to set if you don't have a custom hostname setup"
  default     = ""
}

variable "port" {
  type        = string
  description = "Port the app is running on"
  default     = "9000"
}

variable "civiform_mode" {
  type        = string
  description = "The civiform environment mode (test/dev/staging/prod)"
}

variable "ssl_certificate_arn" {
  type        = string
  description = "ARN of the certificate that will be used to handle SSL traffic. Certificate should be validated."
}

variable "fargate_desired_task_count" {
  type        = number
  description = "Number of Civiform server tasks to run. Can be set to 0 to shutdown server."
}

variable "ecs_task_cpu" {
  type        = number
  description = "CPU of each ECS task. See [these docs](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html#fargate-tasks-size) for potential values. If you change this variable, you may need to change the `ecs_task_memory` as well."
  default     = 1024
}

variable "ecs_task_memory" {
  type        = number
  description = "Memory of each ECS task. See [these docs](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html#fargate-tasks-size) for potential values. If you change this variable, you may need to change the `ecs_task_cpu` as well."
  default     = 6144
}

variable "ecs_max_cpu_threshold" {
  type        = string
  description = "The threshold for max CPU usage in an ECS task. If the CPU increases above this threshold, there will be a cloudwatch alarm and another ECS task will be added."
  default     = "85"
}

variable "ecs_min_cpu_threshold" {
  type        = string
  description = "The threshold for min CPU usage in an ECS task. If the CPU decreases below this threshold, there will be a cloudwatch alarm and an ECS task will be removed."
  default     = "10"
}

variable "ecs_max_cpu_evaluation_period" {
  type        = string
  description = "The number of periods over which data is compared to the specified threshold for max cpu metric alarm."
  default     = "3"
}

variable "ecs_min_cpu_evaluation_period" {
  type        = string
  description = "The number of periods over which data is compared to the specified threshold for min cpu metric alarm."
  default     = "3"
}

variable "ecs_max_cpu_period" {
  type        = string
  description = "The period in seconds over which the specified statistic is applied for max cpu metric alarm."
  default     = "60"
}

variable "ecs_min_cpu_period" {
  type        = string
  description = "The period in seconds over which the specified statistic is applied for min cpu metric alarm."
  default     = "60"
}

variable "ecs_scale_target_max_capacity" {
  type        = number
  description = "The max capacity of the scalable target."
  default     = 5
}

variable "ecs_scale_target_min_capacity" {
  type        = number
  description = "The min capacity of the scalable target."
  default     = 1
}

variable "feature_flag_reporting_enabled" {
  type        = bool
  description = "Whether or not to enable the reporting feature"
  default     = false
}

variable "feature_flag_status_tracking_enabled" {
  type        = bool
  description = "When set to true enable Status Tracking."
  default     = false
}

variable "civiform_api_keys_ban_global_subnet" {
  type        = bool
  description = "Whether to allow 0.0.0.0/0 subnet for API key access."
  default     = true
}

variable "civiform_server_metrics_enabled" {
  type        = bool
  description = "Whether to enable exporting server metrics on the /metrics route."
  default     = false
}

variable "allow_civiform_admin_access_programs" {
  type        = bool
  description = "Whether CiviForm admins can view program applications, similar to Program Admins."
  default     = false
}

variable "feature_flag_overrides_enabled" {
  type        = bool
  description = "Whether feature flags can be override using /dev/feature/.../enable url."
  default     = false
}

variable "pgadmin" {
  type        = bool
  description = "Whether to depoy pgadmin or not."
  default     = false
}
variable "pgadmin_cidr_allowlist" {
  type        = list(string)
  description = "List of IPv4 cidr blocks that are allowed access to pgadmin"
  default     = []
}
variable "show_civiform_image_tag_on_landing_page" {
  type        = bool
  description = "Whether to show civiform version on landing page or not."
  default     = false
}
variable "staging_add_noindex_meta_tag" {
  type        = bool
  description = "Whether to add a robots=noindex meta tag, which causes search engines to not list the website. This defaults to false, meaning sites will appear on search."
  default     = false
}
variable "staging_disable_demo_mode_logins" {
  type        = bool
  description = "Whether to disable the demo mode login buttons."
  default     = false
}
variable "staging_disable_applicant_guest_login" {
  type        = bool
  description = "Whether to disable the guest login button."
  default     = false
}
variable "program_eligibility_conditions_enabled" {
  type        = bool
  description = "Whether to enable program eligibility conditions. This feature flag has been removed, so this will be enabled by default for all deployments after v1.26.0."
  default     = true
}
variable "intake_form_enabled" {
  type        = bool
  description = "Whether to enable the intake form feature."
  default     = false
}
variable "nongated_eligibility_enabled" {
  type        = bool
  description = "Whether to enable the non-gating eligibility feature."
  default     = false
}
variable "common_intake_more_resources_link_text" {
  type        = string
  description = "The text for a link on the Common Intake confirmation page that links to more resources. Shown when the applicant is not eligible for any programs in CiviForm."
  default     = "Access Arkansas"
}
variable "common_intake_more_resources_link_href" {
  type        = string
  description = "The HREF for a link on the Common Intake confirmation page that links to more resources. Shown when the applicant is not eligible for any programs in CiviForm."
  default     = "https://access.arkansas.gov/Learn/Home"
}

variable "bypass_login_language_screens" {
  type        = bool
  description = "Whether to enable the feature removing the login and language screen, landing on the index page."
  default     = false
}

variable "monitoring_stack_enabled" {
  type        = bool
  description = "If true, Prometheus and Grafana instances are created."
  default     = true
}

variable "esri_address_correction_enabled" {
  type        = bool
  description = "Enables the feature that allows address correction for address questions."
  default     = false
}

variable "esri_find_address_candidate_url" {
  type        = string
  description = "The URL CiviForm will use to call Esri’s findAddressCandidates service."
  default     = "https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer/findAddressCandidates"
}

variable "publish_single_program_enabled" {
  type        = bool
  description = "Whether to enable the feature that allows publishing a single program on its own."
  default     = false
}
