variable "cluster_id" {
  description = "Cluster-id group Identifier. Changing this rebuilds the cluster"
  type        = string
}

variable "description" {
  description = "Cluster description"
  type        = string
  default     = "Managed by Terraform"
}

variable "parameter_group_name" {
  description = "Optional name for the parameter group. If omitted name will match cluster"
  type        = string
  default     = ""
}

variable "elasticache_default_user_id" {
  description = "REQUIRED: ID of default elasticache user"
  type        = string
}

variable "elasticache_runtime_user_id" {
  description = "REQUIRED: ID of runtime elasticache user"
  type        = string
}

variable "elasticache_user_group_id" {
  description = "REQUIRED: ID of elasticache user group"
  type        = string
}


variable "parameter_group_description" {
  description = "Optional description for the parameter group. If omitted will use 'Managed by Terraform'"
  type        = string
  default     = ""
}

variable "security_group_ids" {
  description = "A list of security group IDs as strings"
  type        = list(string)
  default     = [""]
}

variable "subnets" {
  description = "A list of subnets IDs as strings"
  type        = list(string)
}

variable "cluster_datacenter" {
  description = "or1-test/or1-internal/oh1-demo/oh1-beta/oh1-prod/etc."
  type        = string

  validation {
    condition = contains(
      [
        "or1-test",
        "or1-internal",
        "oh1-demo",
        "oh1-beta"
    ], var.cluster_datacenter)
    error_message = "Valid values for var: cluster_datacenter are (or1-test, or1-internal, oh1-demo, oh1-beta)."
  }

}

variable "node_type" {
  description = "Size of cluster nodes. Defaults to cache.c7gn.xlarge"
  type        = string
  default     = "cache.c7gn.xlarge"
}

variable "cluster_port" {
  description = "Port that the cluster listens on. Defaults to 6379"
  type        = string
  default     = "6379"
}

variable "num_node_groups" {
  description = "Number of node groups in the cluster. Defaults to 2"
  type        = number
  default     = 2
}

variable "replicas_per_node_group" {
  description = "Number of replica nodes in each node group. Changing this number will trigger a resizing operation before other settings modifications. Defaults to 0"
  type        = number
  default     = 0
}

variable "engine_version" {
  description = "Version number of the cache engine to be used for the cache clusters in this replication group. If the version is 7 or higher, the major and minor version should be set, e.g., 7.2 Defaults to 7.1"
  type        = string
  default     = "7.1"
}

variable "cluster_mode" {
  description = "Specifies whether cluster mode is enabled or disabled. Defaults to enabled."
  type        = string
  default     = "enabled"
}

variable "log_delivery_configuration" {
  type        = list(map(any))
  default     = []
  description = "The log_delivery_configuration block allows the streaming of Redis SLOWLOG or Redis Engine Log to CloudWatch Logs or Kinesis Data Firehose. Max of 2 blocks."
}

# sample value

# locals {
#     log_delivery_configuration = [
#         {
#             "destination": "/aws/elasticache/fb-runtime-${local.region_datacenter}-engine-log"
#             "destination_type": "cloudwatch-logs"
#             "log_format": "json"
#             "log_type" : "engine-log"
#         },
#         {
#             "destination": "/aws/elasticache/fb-runtime-${local.region_datacenter}-slow-log"
#             "destination_type": "cloudwatch-logs"
#             "log_format": "json"
#             "log_type" : "slow-log"
#         }
#     ]
# }

variable "parameter" {
  description = "Redis Parameter group values. Defaults should be sane."
  type = list(object({
    name  = string
    value = string
  }))
  default = [
    {
      name  = "activedefrag"
      value = "yes"
    },
    {
      name  = "cluster-enabled"
      value = "yes"
    },
    {

      name  = "notify-keyspace-events"
      value = "Egx"
    }
  ]
}
