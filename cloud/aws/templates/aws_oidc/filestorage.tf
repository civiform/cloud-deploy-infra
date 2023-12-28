##### Applicant-uploaded files bucket #####
resource "aws_s3_bucket" "civiform_files_s3" {
  tags = {
    Name = "${var.app_prefix} Civiform Files"
    Type = "Civiform Files"
  }

  bucket        = "${var.app_prefix}-civiform-files-s3"
  force_destroy = local.force_destroy_s3
}

resource "aws_s3_bucket_public_access_block" "civiform_files_access" {
  bucket                  = aws_s3_bucket.civiform_files_s3.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "civiform_files_policy" {
  bucket = aws_s3_bucket.civiform_files_s3.id
  policy = data.aws_iam_policy_document.civiform_files_policy.json
}

resource "aws_kms_key" "file_storage_key" {
  description             = "This key is used to encrypt files uploaded by the user"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "civiform_files_encryption" {
  bucket = aws_s3_bucket.civiform_files_s3.bucket

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.file_storage_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

data "aws_iam_policy_document" "civiform_files_policy" {
  statement {
    actions = ["s3:*"]
    effect  = "Deny"
    resources = [
    "${aws_s3_bucket.civiform_files_s3.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "ArnNotEquals"
      variable = "aws:PrincipalArn"
      values   = [aws_iam_role.civiform_ecs_task_execution_role.arn]
    }
  }
  statement {
    actions = ["s3:*"]
    effect  = "Allow"
    resources = [aws_s3_bucket.civiform_files_s3.arn,
    "${aws_s3_bucket.civiform_files_s3.arn}/*"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.civiform_ecs_task_execution_role.arn]
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "civiform_files_ownership" {
  bucket = aws_s3_bucket.civiform_files_s3.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_logging" "civiform_files_logging" {
  bucket = aws_s3_bucket.civiform_files_s3.id

  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "file-access-log/"
}

##### Public files bucket (for program images etc.) #####
resource "aws_s3_bucket" "civiform_public_files_s3" {
  tags = {
    Name = "${var.app_prefix} Civiform Public Files"
    Type = "Civiform Public Files"
  }

  bucket        = "${var.app_prefix}-civiform-public-files-s3"
  force_destroy = local.force_destroy_s3
}

resource "aws_s3_bucket_public_access_block" "civiform_public_files_access" {
# TODO: Which should actually be false?
  bucket                  = aws_s3_bucket.civiform_public_files_s3.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "civiform_public_files_policy" {
  bucket = aws_s3_bucket.civiform_public_files_s3.id
  policy = data.aws_iam_policy_document.civiform_public_files_policy.json
}

# TODO: No idea if this is correct
data "aws_iam_policy_document" "civiform_public_files_policy" {
    # This statement prevents the public from performing any action except the "s3:GetObject" action
    statement {
      not_actions = ["s3:GetObject"]
      effect  = "Deny"
      resources = [
      "${aws_s3_bucket.civiform_public_files_s3.arn}/*"]
      principals {
        type        = "*"
        identifiers = ["*"]
      }
      condition {
        test     = "ArnNotEquals"
        variable = "aws:PrincipalArn"
        values   = [aws_iam_role.civiform_ecs_task_execution_role.arn]
      }
    }
    # This statement explicitly allows the public to perform the "s3:GetObject" action
    # only for files in /program-summary-image/program-* directories.
    # (Note that the "Deny" statement above doesn't *grant* the s3:GetObject action, it just doesn't deny it.
    # See https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_notaction.html.)
    statement {
      actions = ["s3:GetObject"]
      effect    = "Allow"
      # TODO: Add info here and in FileNameFormatter about changing the prefix
      resources = ["${aws_s3_bucket.civiform_public_files_s3.arn}/program-summary-image/program-*"]
      actions   = ["s3:GetObject"]
      principals {
        type        = "*"
        identifiers = ["*"]
      }
    }

  # TODO: Not sure what this statement does
  statement {
    actions = ["s3:*"]
    effect  = "Allow"
    resources = [aws_s3_bucket.civiform_public_files_s3.arn,
    "${aws_s3_bucket.civiform_public_files_s3.arn}/*"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.civiform_ecs_task_execution_role.arn]
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "civiform_public_files_ownership" {
  bucket = aws_s3_bucket.civiform_public_files_s3.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

##### Log bucket #####
resource "aws_s3_bucket" "log_bucket" {
  tags = {
    Name = "${var.app_prefix} Civiform Logs"
    Type = "Civiform Logs"
  }

  bucket        = "${var.app_prefix}-civiform-fileaccesslogs"
  force_destroy = local.force_destroy_s3
}

resource "aws_s3_bucket_acl" "log_bucket_acl" {
  bucket     = aws_s3_bucket.log_bucket.id
  depends_on = [aws_s3_bucket_ownership_controls.file_access_logs_bucket_ownership]
  acl        = "log-delivery-write"
}

resource "aws_s3_bucket_ownership_controls" "file_access_logs_bucket_ownership" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "logging_versioning" {
  bucket = aws_s3_bucket.log_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logging_encryption" {
  bucket = aws_s3_bucket.log_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.file_storage_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}
