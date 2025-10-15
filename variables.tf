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

variable "parameter_group_description" {
    description = "Optional description for the parameter group. If omitted will use 'Managed by Terraform'"
    type        = string
    default     = ""
}

variable "security_group_ids" {
    description = "A list of security group IDs as strings"
    type        = list(string)
    default = [""]
}

variable "subnets" {
    description = "A list of subnets IDs as strings"
    type        = list(string)
}

variable "subnet_group_name" {
    description = "Required name of the subnet group."
    type        = string
}

variable "cluster_datacenter" {
    description = "or1-test/or1-internal/oh1-demo/oh1-beta/oh1-prod/etc."
    type        = string
}

variable "node_type" {
    description = "Size of cluster nodes. Defaults to cache.c7gn.xlarge"
    type = string
    default = "cache.c7gn.xlarge"
}

variable "cluster_port" {
    description = "Port that the cluster listens on. Defaults to 6379"
    type = string
    default = "6379"
}

variable "num_node_groups" {
    description = "Number of node groups in the cluster. Defaults to 2"
    type = number
    default = 2
}
