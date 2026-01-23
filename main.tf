terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.location]
    }
  }
}


locals {
  component         = "internal"
  region_datacenter = "${data.aws_region.current.name}-${var.cluster_datacenter}"
  pgname            = var.parameter_group_name == "" ? "${var.cluster_id}-${local.region_datacenter}" : var.parameter_group_name
  pgdescription     = var.parameter_group_description == "" ? "Managed by Terraform" : var.parameter_group_description
  account_id        = data.aws_caller_identity.current.account_id
}


data "aws_caller_identity" "current" {
  provider = aws.location
}


data "aws_region" "current" {
  provider = aws.location
}


resource "aws_elasticache_replication_group" "cluster" {
  provider = aws.location

  # General settings
  replication_group_id       = "${var.cluster_id}-${local.region_datacenter}"
  engine_version             = var.engine_version
  cluster_mode               = var.cluster_mode
  description                = var.description
  node_type                  = var.node_type
  port                       = var.cluster_port
  parameter_group_name       = local.pgname
  subnet_group_name          = aws_elasticache_subnet_group.subnet_group.name
  automatic_failover_enabled = true

  # User group
  user_group_ids = [
    aws_elasticache_user_group.runtime.user_group_id
  ]

  # Cluster replication & node configuration
  num_node_groups         = var.num_node_groups
  replicas_per_node_group = var.replicas_per_node_group

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
  transit_encryption_enabled = true
  security_group_ids         = var.security_group_ids
}


resource "aws_elasticache_user" "default" {
  provider = aws.location

  user_id       = var.elasticache_default_user_id
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

  user_id       = var.elasticache_runtime_user_id
  user_name     = var.elasticache_runtime_user_id
  access_string = "on ~* &* +@all"
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


resource "aws_elasticache_user_group" "runtime" {
  provider      = aws.location
  user_group_id = var.elasticache_user_group_id
  engine        = "redis"
  user_ids = [
    aws_elasticache_user.default.user_id,
    aws_elasticache_user.runtime.user_id
  ]
}


resource "aws_elasticache_parameter_group" "cluster_pg" {
  provider = aws.location

  name        = local.pgname
  description = local.pgdescription
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
  name       = "${var.subnet_group_name}-${local.region_datacenter}-nstanley"
  subnet_ids = var.subnets
}


resource "aws_cloudwatch_log_group" "logs" {
  count             = length(var.log_delivery_configuration)
  provider          = aws.location
  name              = lookup(var.log_delivery_configuration[count.index], "destination")
  log_group_class   = "STANDARD"
  retention_in_days = "90"
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
