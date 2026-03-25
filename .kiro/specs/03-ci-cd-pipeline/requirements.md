# Requirements Document

## Introduction

Implement a GitHub Actions CI/CD pipeline that builds the Backstage backend Docker image and deploys it to AWS ECS Fargate on every push to `main`. Authentication to AWS uses OpenID Connect (OIDC) so no long-lived AWS credentials are stored as GitHub secrets. The pipeline also provisions the required AWS IAM OIDC provider and assume-role IAM role via Terraform, extending the existing infrastructure from spec `02-aws-infrastructure`.

## Glossary

- **Pipeline**: The GitHub Actions workflow that runs on push to `main`
- **OIDC_Provider**: The AWS IAM OpenID Connect identity provider that trusts GitHub Actions tokens
- **GitHub_Actions_Role**: The AWS IAM role that the Pipeline assumes via OIDC to interact with AWS services
- **ECR**: Amazon Elastic Container Registry — stores the Docker images
- **ECS_Service**: The Amazon ECS Fargate service running the Backstage backend
- **Task_Definition**: An ECS task definition revision that references a specific Docker image tag
- **Image_Tag**: The Git SHA of the commit that triggered the Pipeline, used to uniquely identify a Docker image
- **Rolling_Update**: An ECS deployment strategy that replaces old tasks with new ones without downtime
- **GitHub_Secret**: A repository-level secret stored in GitHub, referenced by the Pipeline at runtime

---

## Requirements

### Requirement 1: OIDC Trust Between GitHub Actions and AWS

**User Story:** As a platform engineer, I want GitHub Actions to authenticate to AWS via OIDC, so that no long-lived AWS credentials are stored in GitHub.

#### Acceptance Criteria

1. THE Pipeline SHALL authenticate to AWS using the `aws-actions/configure-aws-credentials` action with `role-to-assume` and without `aws-access-key-id` or `aws-secret-access-key` inputs.
2. THE OIDC_Provider SHALL be created in AWS IAM with the issuer URL `https://token.actions.githubusercontent.com`.
3. THE OIDC_Provider SHALL use the thumbprint for `token.actions.githubusercontent.com` as required by AWS.
4. THE GitHub_Actions_Role SHALL have a trust policy that allows assumption only by the `sts:AssumeRoleWithWebIdentity` action from the OIDC_Provider.
5. THE GitHub_Actions_Role trust policy SHALL restrict the `sub` claim to tokens issued for the target GitHub repository and `ref:refs/heads/main` branch.
6. IF the OIDC token does not match the trust policy conditions, THEN AWS SHALL deny the `AssumeRoleWithWebIdentity` request.
7. THE OIDC_Provider and GitHub_Actions_Role SHALL be defined as Terraform resources in the `03-ci-cd-pipeline` spec's Terraform module.

---

### Requirement 2: GitHub Actions Role Permissions

**User Story:** As a platform engineer, I want the GitHub Actions IAM role to have least-privilege permissions, so that a compromised token cannot affect resources outside the deployment scope.

#### Acceptance Criteria

1. THE GitHub_Actions_Role SHALL have permission to call `ecr:GetAuthorizationToken` on all resources.
2. THE GitHub_Actions_Role SHALL have permissions to call `ecr:BatchCheckLayerAvailability`, `ecr:GetDownloadUrlForLayer`, `ecr:BatchGetImage`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`, and `ecr:PutImage` scoped to the ECR repository ARN.
3. THE GitHub_Actions_Role SHALL have permission to call `ecs:RegisterTaskDefinition` on all resources.
4. THE GitHub_Actions_Role SHALL have permission to call `ecs:DescribeServices`, `ecs:UpdateService`, and `ecs:DescribeTaskDefinition` scoped to the ECS_Service and its cluster ARN.
5. THE GitHub_Actions_Role SHALL have permission to call `iam:PassRole` scoped only to the ECS task execution role ARN, so ECS can pull images and read secrets.
6. THE GitHub_Actions_Role SHALL NOT have `AdministratorAccess` or any wildcard `*` action policies.

---

### Requirement 3: Pipeline Trigger and Environment Configuration

**User Story:** As a developer, I want the pipeline to run automatically on every push to `main`, so that every merged change is deployed to production without manual intervention.

#### Acceptance Criteria

1. THE Pipeline SHALL be triggered by a `push` event on the `main` branch only.
2. THE Pipeline SHALL read `AWS_ACCOUNT_ID`, `AWS_REGION`, `ECR_REPOSITORY`, `ECS_CLUSTER`, and `ECS_SERVICE` from GitHub repository secrets.
3. THE Pipeline SHALL derive the Image_Tag from the `github.sha` context value.
4. THE Pipeline SHALL construct the full ECR image URI as `<AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/<ECR_REPOSITORY>:<Image_Tag>`.
5. IF any required GitHub_Secret is absent, THEN the Pipeline SHALL fail at the step that references it with a descriptive error.

---

### Requirement 4: Docker Image Build

**User Story:** As a developer, I want the pipeline to build the Backstage backend Docker image from the existing Dockerfile, so that the image reflects the latest committed code.

#### Acceptance Criteria

1. WHEN the Pipeline runs, THE Pipeline SHALL execute `yarn install --immutable`, `yarn tsc`, and `yarn build:backend` inside the `backstage-portal/` directory before building the Docker image.
2. THE Pipeline SHALL build the Docker image using `backstage-portal/packages/backend/Dockerfile` with the `backstage-portal/` directory as the Docker build context.
3. THE Pipeline SHALL tag the built image with the Image_Tag.
4. THE Pipeline SHALL also tag the built image with `latest`.
5. IF the Docker build step exits with a non-zero code, THEN the Pipeline SHALL fail and SHALL NOT proceed to the push or deploy steps.

---

### Requirement 5: Docker Image Push to ECR

**User Story:** As a platform engineer, I want the built image pushed to ECR, so that ECS can pull it during deployment.

#### Acceptance Criteria

1. WHEN the Docker image is built successfully, THE Pipeline SHALL authenticate to ECR using `aws-actions/amazon-ecr-login`.
2. THE Pipeline SHALL push the image tagged with the Image_Tag to ECR.
3. THE Pipeline SHALL push the image tagged with `latest` to ECR.
4. IF the ECR push fails, THEN the Pipeline SHALL fail and SHALL NOT proceed to the deploy step.

---

### Requirement 6: ECS Deployment

**User Story:** As a platform engineer, I want the pipeline to deploy the new image to ECS Fargate using a rolling update, so that the production service is updated with zero downtime.

#### Acceptance Criteria

1. WHEN the image is pushed to ECR, THE Pipeline SHALL retrieve the current Task_Definition JSON using `aws ecs describe-task-definition`.
2. THE Pipeline SHALL produce a new Task_Definition revision by replacing the container image URI with the newly pushed ECR image URI (using the Image_Tag).
3. THE Pipeline SHALL register the new Task_Definition revision using `aws ecs register-task-definition`.
4. THE Pipeline SHALL update the ECS_Service to use the new Task_Definition revision using `aws ecs update-service`.
5. THE Pipeline SHALL wait for the ECS_Service to reach a stable state using `aws ecs wait services-stable` before reporting success.
6. IF the ECS_Service does not reach a stable state within the wait timeout, THEN the Pipeline SHALL fail and report the deployment as unsuccessful.
7. THE Pipeline SHALL perform a Rolling_Update, meaning the ECS_Service minimum healthy percent SHALL allow at least one task to remain running during the update.

---

### Requirement 7: Pipeline Security Hardening

**User Story:** As a security engineer, I want the pipeline to follow least-privilege and supply-chain security practices, so that the CI/CD system does not become an attack vector.

#### Acceptance Criteria

1. THE Pipeline SHALL pin all third-party GitHub Actions to a specific commit SHA rather than a mutable tag.
2. THE Pipeline SHALL set `permissions: id-token: write` and `permissions: contents: read` at the job level and no broader.
3. THE Pipeline SHALL NOT log or print the AWS account ID, ECR URI, or any secret values in plain text in workflow step output.
4. WHERE the pipeline runs on a self-hosted runner is not configured, THE Pipeline SHALL use `ubuntu-latest` GitHub-hosted runners.

---

### Requirement 8: Terraform OIDC Infrastructure

**User Story:** As a platform engineer, I want the OIDC provider and IAM role managed as Terraform code, so that the AWS trust configuration is version-controlled and reproducible.

#### Acceptance Criteria

1. THE Terraform configuration SHALL define an `aws_iam_openid_connect_provider` resource for GitHub Actions.
2. THE Terraform configuration SHALL define an `aws_iam_role` resource for the GitHub_Actions_Role with the OIDC trust policy.
3. THE Terraform configuration SHALL define an `aws_iam_role_policy` or `aws_iam_policy` resource attaching the least-privilege permissions from Requirement 2.
4. THE Terraform configuration SHALL accept the GitHub repository name (e.g. `org/repo`) as an input variable to scope the trust policy.
5. THE Terraform configuration SHALL output the GitHub_Actions_Role ARN so it can be stored as the `AWS_ROLE_ARN` GitHub secret.
6. WHEN `terraform plan` is run against the configuration, THE Terraform configuration SHALL produce no errors.
