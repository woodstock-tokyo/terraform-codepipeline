# terraform-codepipeline-ecs

Terraform module for Github and AWS CodePipeline + ECS integration

## Requirement

[Terraform >= 1.0.0](https://releases.hashicorp.com/terraform/)

## Example

### Terraform

```Terraform
module "ecs_release_pipeline_woodstock_api_stg" {
  name                        = "<<codepipeline name>>"
  namespace                   = "<<codepipeline namespace>>"
  stage                       = "<<codepipeline stage prefix>>"
  github_oauth_token          = "<<github oauth token>>"
  github_webhooks_token       = "<<github webhook token>>"
  github_webhook_events       = ["push", "release"]
  webhook_filter_json_path    = "$.action"
  webhook_filter_match_equals = "published"
  webhook_enabled             = true
  repo_owner                  = "<<github repo owner>>"
  repo_name                   = "<<github repo name>>"
  branch                      = "<<github repo branch>>"
  service_name                = "<<ecs service name>>"
  ecs_cluster_name            = "<<ecs cluster name>>"
  privileged_mode             = true
  aws_account_id              = "<<aws account id>>"
  aws_region                  = "<<aws region>>"
  image_repo_name             = "<<ecr image repo name>>"
  buildspec                   = "<<build spec yaml>> (see example below)"
  webhook_authentication      = "GITHUB_HMAC"
  build_timeout               = "20"
}
```

### Build Spec Yaml

```yaml
version: 0.2

env:
  secrets-manager:
    DOCKERHUB_USER: arn:aws:secretsmanager:xxxxx
    DOCKERHUB_PASS: arn:aws:secretsmanager:yyyyy
phases:
  install:
    runtime-versions:
      docker: 18
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - $(aws ecr get-login --no-include-email --region $AWS_DEFAULT_REGION)
      - echo Logging in to Docker Hub...
      - echo $DOCKERHUB_PASS | docker login -u $DOCKERHUB_USER --password-stdin
  build:
    commands:
      - echo Building the Docker image...
      - docker build -t $IMAGE_REPO_NAME:latest -f 'build/Dockerfile.api.stg' .
      - docker tag $IMAGE_REPO_NAME:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:latest
  post_build:
    commands:
      - echo Pushing to ECR...
      - docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:latest
      - printf '[{"name":"<<image repo name>>","imageUri":"%s"}]' $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:latest > imagedefinitions.json
artifacts:
  files: imagedefinitions.json
```
