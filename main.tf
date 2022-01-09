module "codepipeline_label" {
  source     = "./label"
  attributes = compact(concat(var.attributes,  tolist(["codepipeline"])))
  delimiter  = var.delimiter
  name       = var.name
  namespace  = var.namespace
  stage      = var.stage
  tags       = var.tags
}

resource "aws_s3_bucket" "default" {
  bucket        = module.codepipeline_label.id
  acl           = "private"
  force_destroy = var.s3_bucket_force_destroy
  tags          = module.codepipeline_label.tags
}

module "codepipeline_assume_label" {
  source     = "./label"
  attributes = compact(concat(var.attributes, tolist(["codepipeline", "assume"])))
  delimiter  = var.delimiter
  name       = var.name
  namespace  = var.namespace
  stage      = var.stage
  tags       = var.tags
}

resource "aws_iam_role" "default" {
  name               = module.codepipeline_assume_label.id
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

data "aws_iam_policy_document" "assume" {
  statement {
    sid = ""

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role_policy_attachment" "default" {
  role       = aws_iam_role.default.id
  policy_arn = aws_iam_policy.default.arn
}

resource "aws_iam_policy" "default" {
  name   = module.codepipeline_label.id
  policy = data.aws_iam_policy_document.default.json
}

data "aws_iam_policy_document" "default" {
  statement {
    sid = ""

    actions = [
      "ec2:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "cloudwatch:*",
      "s3:*",
      "sns:*",
      "cloudformation:*",
      "rds:*",
      "sqs:*",
      "ecs:*",
      "iam:PassRole",
    ]

    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_role_policy_attachment" "s3" {
  role       = aws_iam_role.default.id
  policy_arn = aws_iam_policy.s3.arn
}

module "codepipeline_s3_policy_label" {
  source     = "./label"
  attributes = compact(concat(var.attributes, tolist(["codepipeline", "s3"])))
  delimiter  = var.delimiter
  name       = var.name
  namespace  = var.namespace
  stage      = var.stage
  tags       = var.tags
}

resource "aws_iam_policy" "s3" {
  name   = module.codepipeline_s3_policy_label.id
  policy = data.aws_iam_policy_document.s3.json
}

data "aws_iam_policy_document" "s3" {
  statement {
    sid = ""

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObject",
    ]

    resources = [
      aws_s3_bucket.default.arn,
      "${aws_s3_bucket.default.arn}/*",
    ]

    effect = "Allow"
  }
}

resource "aws_iam_role_policy_attachment" "codebuild" {
  role       = aws_iam_role.default.id
  policy_arn = aws_iam_policy.codebuild.arn
}

module "codebuild_label" {
  source     = "./label"
  attributes = compact(concat(var.attributes, tolist(["codebuild"])))
  delimiter  = var.delimiter
  name       = var.name
  namespace  = var.namespace
  stage      = var.stage
  tags       = var.tags
}

resource "aws_iam_policy" "codebuild" {
  name   = module.codebuild_label.id
  policy = data.aws_iam_policy_document.codebuild.json
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    actions = [
      "codebuild:*",
    ]

    resources = [module.build.project_id]
    effect    = "Allow"
  }
}

data "aws_caller_identity" "default" {}

data "aws_region" "default" {}

module "build" {
  source                = "./codebuild"
  namespace             = var.namespace
  name                  = var.name
  stage                 = var.stage
  build_image           = var.build_image
  build_compute_type    = var.build_compute_type
  build_timeout         = var.build_timeout
  buildspec             = var.buildspec
  delimiter             = var.delimiter
  attributes            = concat(var.attributes, tolist(["build"]))
  tags                  = var.tags
  privileged_mode       = var.privileged_mode
  aws_region            = signum(length(var.aws_region)) == 1 ? var.aws_region : data.aws_region.default.name
  aws_account_id        = signum(length(var.aws_account_id)) == 1 ? var.aws_account_id : data.aws_caller_identity.default.account_id
  image_repo_name       = var.image_repo_name
  image_tag             = var.image_tag
  github_token          = var.github_oauth_token
  environment_variables = var.environment_variables
  badge_enabled         = var.badge_enabled
}

resource "aws_iam_role_policy_attachment" "codebuild_s3" {
  role       = module.build.role_id
  policy_arn = aws_iam_policy.s3.arn
}

resource "aws_codepipeline" "source_build_deploy" {
  name     = module.codepipeline_label.id
  role_arn = aws_iam_role.default.arn

  artifact_store {
    location = aws_s3_bucket.default.bucket
    type     = "S3"
  }

  depends_on = [
    aws_iam_role_policy_attachment.default,
    aws_iam_role_policy_attachment.s3,
    aws_iam_role_policy_attachment.codebuild,
    aws_iam_role_policy_attachment.codebuild_s3,
  ]

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["code"]

      configuration = {
        OAuthToken           = var.github_oauth_token
        Owner                = var.repo_owner
        Repo                 = var.repo_name
        Branch               = var.branch
        PollForSourceChanges = var.poll_source_changes
      }
    }
  }

  stage {
    name = "Build"

    action {
      name     = "Build"
      category = "Build"
      owner    = "AWS"
      provider = "CodeBuild"
      version  = "1"

      input_artifacts  = ["code"]
      output_artifacts = ["task"]

      configuration = {
        ProjectName = module.build.project_name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["task"]
      version         = "1"

      configuration = {
        ClusterName = var.ecs_cluster_name
        ServiceName = var.service_name
      }
    }
  }
}

resource "random_string" "webhook_secret" {
  count  = var.webhook_enabled ? 1 : 0
  length = 32

  # Special characters are not allowed in webhook secret (AWS silently ignores webhook callbacks)
  special = false
}

locals {
  webhook_secret = join("", random_string.webhook_secret.*.result)
  webhook_url    = join("", aws_codepipeline_webhook.webhook.*.url)
}

resource "aws_codepipeline_webhook" "webhook" {
  count           = var.webhook_enabled ? 1 : 0
  name            = module.codepipeline_label.id
  authentication  = var.webhook_authentication
  target_action   = var.webhook_target_action
  target_pipeline = join("", aws_codepipeline.source_build_deploy.*.name)

  authentication_configuration {
    secret_token = local.webhook_secret
  }

  filter {
    json_path    = var.webhook_filter_json_path
    match_equals = var.webhook_filter_match_equals
  }
}

module "github_webhooks" {
  source               = "./webhook"
  enabled              = var.webhook_enabled
  github_organization  = var.repo_owner
  github_repositories  = [var.repo_name]
  github_token         = var.github_webhooks_token
  webhook_url          = local.webhook_url
  webhook_secret       = local.webhook_secret
  webhook_content_type = "json"
  events               = var.github_webhook_events
}
