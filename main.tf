terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.location]
    }
  }
}


locals {
  parameter_group_name = "${data.aws_region.current.id}-${var.cluster_datacenter}"
  final_parameter_group_description = var.parameter_group_description == "" ? "Managed by Terraform" : "Managed by Terraform ${var.parameter_group_description}"
  account_id = data.aws_caller_identity.current.account_id // needed for logging
}


data "aws_caller_identity" "current" {
  provider = aws.location
}


data "aws_region" "current" {
  provider = aws.location
}


resource "aws_elasticache_replication_group" "cluster" {
  provider = aws.location // This will be set the region that the cluster will be created in.

  # General settings
  replication_group_id       = "${var.cluster_datacenter}-${var.cluster_id}-repgrp"
  engine_version             = var.engine_version
  cluster_mode               = var.cluster_mode
  description                = var.description
  node_type                  = var.node_type
  port                       = var.cluster_port
  parameter_group_name       = local.parameter_group_name
  subnet_group_name          = aws_elasticache_subnet_group.subnet_group.name
  automatic_failover_enabled = true



  # User group
  # user_group_ids = [
  #   aws_elasticache_user_group.runtime.user_group_id
  # ]

  # Cluster replication & node configuration
  num_node_groups         = var.num_node_groups
  replicas_per_node_group = var.replicas_per_node_group

  # WARNING: This will apply changes immediately, which may cause disruptions depending on the setting.
  apply_immediately = true

  # Logging configuration (dynamic block)
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


# NOTE: An AWS Redis ElastiCache cluster can only
# be associated with one parameter group at a time.
# But a Param group can be assoicated with many cluster
# however we are enfocing a 1-1 relationship since we 
# are using Terrafrom to manage and we want way to promote
# changes in envs.
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


resource "aws_elasticache_subnet_group" "subnet_group" {
  provider   = aws.location
  name       = "${var.cluster_datacenter}-${var.cluster_id}"
  subnet_ids = var.subnets
}


















# Ensure the AWS ElastiCache default user for Redis has no access
# privileges and no password authentication.
resource "aws_elasticache_user" "default" {
  provider = aws.location

  user_id       = "${var.cluster_id}-default-user"
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


resource "aws_elasticache_user" "runtime" {
  provider = aws.location

  # Loop through user configuration
  for_each = {
    for idx, user_config in var.user_configuration :
    user_config.user_id => user_config
  }

  user_id   = each.value.user_id
  user_name = each.value.user_id

  access_string = each.value.access_string
  engine        = "redis"

  # Authentication mode setup
  authentication_mode {
    type = "iam"
  }

  # Timeouts for create, update, and delete actions
  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }
}






# -----------------------------------------------------------------------------
# CloudWatch Log Group and Log Delivery Policy Setup for Elasticache
#
# - Configures CloudWatch log groups.
# - This is optional and should only be used in environments without Datadog configured.
# - Sets up log delivery policies, granting Elasticache permissions to log groups.
# - Generates an IAM policy allowing log stream and event creation actions.
# -----------------------------------------------------------------------------


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
