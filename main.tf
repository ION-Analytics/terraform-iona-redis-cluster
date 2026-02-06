terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.location]
    }
  }
}

locals {
  parameter_group_name              = "${var.cluster_datacenter}-${var.cluster_id}-paramgrp"
  final_parameter_group_description = var.parameter_group_description == "" ? "Managed by Terraform" : "Managed by Terraform ${var.parameter_group_description}"
  account_id                        = data.aws_caller_identity.current.account_id // needed for logging
}


data "aws_caller_identity" "current" {
  provider = aws.location
}


data "aws_region" "current" {
  provider = aws.location
}


# ----------------------------------------------------------------------------------
# AWS ElastiCache Cluster Setup, Parameter Group, and Subnet Configuration
#
# - Creates an ElastiCache replication group based on the configuration in `var`.
# - Configures dynamic log delivery settings based on `var.log_delivery_configuration`.
# - Ensures the replication group has at-rest and transit encryption enabled for security.
# - Creates a dedicated ElastiCache parameter group for the Redis engine, enforcing a 
#   1-to-1 relationship between clusters and parameter groups to simplify management.
# - Sets up an ElastiCache subnet group using provided subnet IDs, associating it with 
#   the replication group.
# ----------------------------------------------------------------------------------

resource "aws_elasticache_replication_group" "cluster" {
  provider = aws.location

  replication_group_id = "${var.cluster_datacenter}-${var.cluster_id}-repgrp"
  description          = var.description
  parameter_group_name = local.parameter_group_name

  engine_version             = var.engine_version
  cluster_mode               = var.cluster_mode
  node_type                  = var.node_type
  port                       = var.cluster_port
  subnet_group_name          = aws_elasticache_subnet_group.cluster_subnet_group.name

  num_node_groups         = var.num_node_groups
  replicas_per_node_group = var.replicas_per_node_group

  apply_immediately = true # WARN: Apply changes immediately, which may cause disruptions.
  automatic_failover_enabled = true

  dynamic "log_delivery_configuration" {
    for_each = var.log_delivery_configuration

    content {
      destination      = lookup(log_delivery_configuration.value, "destination", null)
      destination_type = lookup(log_delivery_configuration.value, "destination_type", null)
      log_format       = lookup(log_delivery_configuration.value, "log_format", null)
      log_type         = lookup(log_delivery_configuration.value, "log_type", null)
    }
  }

  # Security settings
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  security_group_ids         = var.security_group_ids
}


# NOTE: An AWS Redis ElastiCache cluster can only be associated with one parameter group at a time. 
# While a parameter group can be associated with multiple clusters, HOWEVER we enforce a 1-to-1  
# relationship in Terraform to simplify environment segregation, promotion and management.
resource "aws_elasticache_parameter_group" "cluster_pg" {
  provider = aws.location

  name        = local.parameter_group_name
  description = local.final_parameter_group_description
  family      = "redis7"

  dynamic "parameter" {
    for_each = var.parameter

    content {
      name  = parameter.value.name
      value = tostring(parameter.value.value)
    }
  }

}

# Creates an ElastiCache subnet-group using the provided subnet IDs,
# with a name based on the cluster's ID.
resource "aws_elasticache_subnet_group" "cluster_subnet_group" {
  provider   = aws.location
  name       = "${var.cluster_datacenter}-${var.cluster_id}"
  subnet_ids = var.subnets
}


# ----------------------------------------------------------------------------------
# AWS ElastiCache Cluster IAM access, Policies Configuration
# ----------------------------------------------------------------------------------

resource "aws_iam_role" "cluster_iam_role" {
  provider = aws.location
  name     = "${var.cluster_datacenter}-${var.cluster_id}-cluster-role"
  description = "Managed by Terraform: Role to give resources access to the ${var.cluster_datacenter}-${var.cluster_id} ElastiCache Cluster"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.assume_connection_role_principals
           # aws_iam_user.redis_user_fb_runtime_or1_test.arn # TODO how to manage this 
        }
      }
    ]
  })
}

resource "aws_iam_policy" "cluster_connect_ami_policy" {
  provider    =  aws.location
  name        = "${var.cluster_datacenter}-${var.cluster_id}-cluster-connect-policy"
  description = "Managed by Terraform: Allow access to ${var.cluster_datacenter}-${var.cluster_id} ElastiCache Cluster"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "elasticache:Connect"
        ]
        Effect   = "Allow"
        Resource = aws_elasticache_replication_group.cluster.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_or1_test_fb_connect_policy_to_role" {
  provider   = aws.location
  role       = aws_iam_role.cluster_iam_role.name
  policy_arn = aws_iam_policy.cluster_connect_ami_policy.arn
}


# ----------------------------------------------------------------------------------
# AWS ElastiCache User Configuration and Default User Access Setup
#
# - Creates AWS ElastiCache users based on configurations in `var.user_configuration`.
# - Loops through the configuration to define user-specific settings.
# - Ensures IAM authentication is enabled for each user.
# - Sets up a default ElastiCache user for Redis with no access privileges and 
#   disables password authentication.
# - Ensures default user does not have access to any resources.
# ----------------------------------------------------------------------------------

resource "aws_elasticache_user" "runtime" {
  provider = aws.location

  for_each = {
    for idx, user_config in var.user_configuration :
    user_config.user_id => user_config
  }

  user_id   = each.value.user_id
  user_name = each.value.user_id

  access_string = each.value.access_string
  engine        = "redis"

  authentication_mode {
    type = "iam"
  }

  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }
}

resource "aws_elasticache_user" "default" {
  provider = aws.location

  user_id       = "${var.cluster_datacenter}-${var.cluster_id}-default"
  user_name     = "default"
  access_string = "off -@all"
  engine        = "redis"

  authentication_mode {
    type = "no-password-required"
  }

  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }

}

# ----------------------------------------------------------------------------------
# CloudWatch Log Group and Log Delivery Policy Setup for Elasticache
#
# - Configures CloudWatch log groups.
# - This is optional and should only be used in environments without Datadog configured.
# - Sets up log delivery policies, granting Elasticache permissions to log groups.
# - Generates an IAM policy allowing log stream and event creation actions.
# ----------------------------------------------------------------------------------


resource "aws_cloudwatch_log_group" "logs" {
  count             = length(var.log_delivery_configuration)
  provider          = aws.location
  name              = lookup(var.log_delivery_configuration[count.index], "destination")
  log_group_class   = "STANDARD"
  retention_in_days = 14
}


resource "aws_cloudwatch_log_resource_policy" "elasticache_log_delivery_policy" {
  count           = length(var.log_delivery_configuration)
  provider        = aws.location
  policy_document = data.aws_iam_policy_document.elasticache_log_delivery_policy.json
  policy_name     = lookup(var.log_delivery_configuration[count.index], "destination")
}


data "aws_iam_policy_document" "elasticache_log_delivery_policy" {
  statement {
    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogStream"
    ]

    resources = [
      for lg in aws_cloudwatch_log_group.logs :
      "arn:aws:logs:${data.aws_region.current.region}:${local.account_id}:log-group:${lg.name}:log-stream:*"
    ]

    principals {
      identifiers = ["delivery.logs.amazonaws.com"]
      type        = "Service"
    }
  }
}
