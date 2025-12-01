terraform {
    required_providers {
        aws = {
            source                = "hashicorp/aws"
            configuration_aliases = [ aws.location ]
        }
    }
}

locals {
    component = "internal"
    region_datacenter = "${data.aws_region.current.name}-${var.cluster_datacenter}"
    pgname = var.parameter_group_name == "" ? "${var.cluster_id}-${local.region_datacenter}" : var.parameter_group_name
    pgdescription = var.parameter_group_description == "" ? "Managed by Terraform" : var.parameter_group_description
}

data "aws_region" "current" {
    provider = aws.location
}

resource "aws_elasticache_replication_group" "cluster" {
    provider = aws.location
    replication_group_id       = "${var.cluster_id}-${local.region_datacenter}"
    engine_version             = var.engine_version
    cluster_mode               = var.cluster_mode
    description                = var.description
    node_type                  = var.node_type
    port                       = var.cluster_port
    parameter_group_name       = aws_elasticache_parameter_group.cluster_pg.name
    automatic_failover_enabled = true
    user_group_ids          = [aws_elasticache_user_group.runtime.user_group_id]
    num_node_groups         = var.num_node_groups
    replicas_per_node_group = var.replicas_per_node_group
    log_delivery_configuration {
        destination = aws_cloudwatch_log_group.engine-logs.name
        destination_type = "cloudwatch-logs"
        log_format = "json"
        log_type = "engine-log"
    }
    transit_encryption_enabled = true
    security_group_ids = var.security_group_ids
    subnet_group_name = aws_elasticache_subnet_group.subnet_group.name
}

resource "aws_elasticache_user" "default" {
    provider = aws.location
    user_id = "fb-default-user-${local.region_datacenter}"
    user_name = "default"
    access_string = "off -@all"
    engine = "redis"
    authentication_mode {
        type = "no-password-required"
    }
}

resource "aws_elasticache_user" "runtime" {
    provider = aws.location
    user_id = "fb-runtime-user-${local.region_datacenter}"
    user_name = "fb-runtime-user-${local.region_datacenter}"
    access_string = "on ~* &* +@all"
    engine = "redis"
    authentication_mode {
        type = "iam"
    }
}

resource "aws_elasticache_user_group" "runtime" {
    provider = aws.location
    user_group_id = "fb-runtime-ug-${local.region_datacenter}"
    engine  = "redis"
    user_ids = [
        aws_elasticache_user.default.user_id,
        aws_elasticache_user.runtime.user_id
    ]
}

resource "aws_elasticache_parameter_group" "cluster_pg" {
    provider = aws.location
    description = local.pgdescription

    name   = local.pgname
    family = "redis7"

    parameter {
        name  = "activedefrag"
        value = "yes"
    }

    parameter {
        name  = "cluster-enabled"
        value = "yes"
    }

    parameter {
        name  = "notify-keyspace-events"
        value = "Egx"
    }
}

resource "aws_elasticache_subnet_group" "subnet_group" {
    provider = aws.location
    name       = "${var.subnet_group_name}-${local.region_datacenter}"
    subnet_ids = var.subnets
}

resource "aws_cloudwatch_log_group" "engine-logs" {
    provider = aws.location
    name = "/aws/elasticache/fb-runtime-${local.region_datacenter}"
    log_group_class = "STANDARD"
    retention_in_days = "90"
}
