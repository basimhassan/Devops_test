// modules/security/main.tf
provider "aws" {
  region = var.region
}

// SonarQube setup can be integrated as a part of the CodeBuild project

resource "aws_codebuild_project" "build_project_with_sonar" {
  name          = var.project_name
  description   = "Build project for ${var.project_name} with SonarQube"
  build_timeout = "30"
  service_role  = var.service_role

  artifacts {
    type = "S3"
    location = var.artifact_bucket
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = false
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.region
    }
  }

  source {
    type      = "GITHUB"
    location  = var.source_location
    git_clone_depth = 1
  }

  cache {
    type = "NO_CACHE"
  }

  buildspec = file("${path.module}/buildspec.yml")
}

// modules/security/variables.tf
variable "region" {}
variable "project_name" {}
variable "service_role" {}
variable "artifact_bucket" {}
variable "source_location" {}

// modules/security/outputs.tf
output "build_project_name" {
  value = aws_codebuild_project.build_project_with_sonar.name
}

// modules/security/buildspec.yml
version: 0.2

phases:
  install:
    runtime-versions:
      nodejs: 14
    commands:
      - echo Installing source NPM dependencies...
      - npm install
      - curl -o sonarqube-scanner.zip -L "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.6.2.2472-linux.zip"
      - unzip sonarqube-scanner.zip -d /usr/local
  build:
    commands:
      - echo Build started on `date`
      - echo Compiling the Node.js code
      - npm run build
      - /usr/local/sonar-scanner-4.6.2.2472-linux/bin/sonar-scanner \
          -Dsonar.projectKey=my-game \
          -Dsonar.sources=. \
          -Dsonar.host.url=http://localhost:9000 \
          -Dsonar.login=my-sonar-token
  post_build:
    commands:
      - echo Build completed on `date`
      - aws s3 sync . s3://my-game-ci-artifacts/build --exclude ".git/*" --exclude "node_modules/*"

artifacts:
  files:
    - '**/*'
  base-directory: build
