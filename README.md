# Terraform AWS ElastiCache Replication Group Module

This Terraform module simplifies the process of creating an ElastiCache replication group with advanced configurations like parameter groups, user authentication, logging, and failover settings. It supports Redis clusters and integrates with AWS CloudWatch for logging.

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_aws.location"></a> [aws.location](#provider\_aws.location) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_resource_policy.elasticache_log_delivery_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_resource_policy) | resource |
| [aws_elasticache_parameter_group.cluster_pg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_parameter_group) | resource |
| [aws_elasticache_replication_group.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group) | resource |
| [aws_elasticache_subnet_group.subnet_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_subnet_group) | resource |
| [aws_elasticache_user.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_user) | resource |
| [aws_elasticache_user.runtime](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_user) | resource |
| [aws_elasticache_user_group.runtime](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_user_group) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.elasticache_log_delivery_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_datacenter"></a> [cluster\_datacenter](#input\_cluster\_datacenter) | or1-test/or1-internal/oh1-demo/oh1-beta/oh1-prod/etc. | `string` | n/a | yes |
| <a name="input_cluster_id"></a> [cluster\_id](#input\_cluster\_id) | Cluster-id group Identifier. Changing this rebuilds the cluster | `string` | n/a | yes |
| <a name="input_cluster_mode"></a> [cluster\_mode](#input\_cluster\_mode) | Specifies whether cluster mode is enabled or disabled. Defaults to enabled. | `string` | `"enabled"` | no |
| <a name="input_cluster_port"></a> [cluster\_port](#input\_cluster\_port) | Port that the cluster listens on. Defaults to 6379 | `string` | `"6379"` | no |
| <a name="input_description"></a> [description](#input\_description) | Cluster description | `string` | `"Managed by Terraform"` | no |
| <a name="input_elasticache_default_user_id"></a> [elasticache\_default\_user\_id](#input\_elasticache\_default\_user\_id) | REQUIRED: ID of default elasticache user | `string` | n/a | yes |
| <a name="input_elasticache_runtime_user_id"></a> [elasticache\_runtime\_user\_id](#input\_elasticache\_runtime\_user\_id) | REQUIRED: ID of runtime elasticache user | `string` | n/a | yes |
| <a name="input_elasticache_user_group_id"></a> [elasticache\_user\_group\_id](#input\_elasticache\_user\_group\_id) | REQUIRED: ID of elasticache user group | `string` | n/a | yes |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | Version number of the cache engine to be used for the cache clusters in this replication group. If the version is 7 or higher, the major and minor version should be set, e.g., 7.2 Defaults to 7.1 | `string` | `"7.1"` | no |
| <a name="input_log_delivery_configuration"></a> [log\_delivery\_configuration](#input\_log\_delivery\_configuration) | The log\_delivery\_configuration block allows the streaming of Redis SLOWLOG or Redis Engine Log to CloudWatch Logs or Kinesis Data Firehose. Max of 2 blocks. | `list(map(any))` | `[]` | no |
| <a name="input_node_type"></a> [node\_type](#input\_node\_type) | Size of cluster nodes. Defaults to cache.c7gn.xlarge | `string` | `"cache.c7gn.xlarge"` | no |
| <a name="input_num_node_groups"></a> [num\_node\_groups](#input\_num\_node\_groups) | Number of node groups in the cluster. Defaults to 2 | `number` | `2` | no |
| <a name="input_parameter"></a> [parameter](#input\_parameter) | Redis Parameter group values. Defaults should be sane. | <pre>list(object({<br/>        name  = string<br/>        value = string<br/>    }))</pre> | <pre>[<br/>  {<br/>    "name": "activedefrag",<br/>    "value": "yes"<br/>  },<br/>  {<br/>    "name": "cluster-enabled",<br/>    "value": "yes"<br/>  },<br/>  {<br/>    "name": "notify-keyspace-events",<br/>    "value": "Egx"<br/>  }<br/>]</pre> | no |
| <a name="input_parameter_group_description"></a> [parameter\_group\_description](#input\_parameter\_group\_description) | Optional description for the parameter group. If omitted will use 'Managed by Terraform' | `string` | `""` | no |
| <a name="input_parameter_group_name"></a> [parameter\_group\_name](#input\_parameter\_group\_name) | Optional name for the parameter group. If omitted name will match cluster | `string` | `""` | no |
| <a name="input_replicas_per_node_group"></a> [replicas\_per\_node\_group](#input\_replicas\_per\_node\_group) | Number of replica nodes in each node group. Changing this number will trigger a resizing operation before other settings modifications. Defaults to 0 | `number` | `0` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | A list of security group IDs as strings | `list(string)` | <pre>[<br/>  ""<br/>]</pre> | no |
| <a name="input_subnet_group_name"></a> [subnet\_group\_name](#input\_subnet\_group\_name) | Required name of the subnet group. | `string` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | A list of subnets IDs as strings | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_parameter_group_name"></a> [parameter\_group\_name](#output\_parameter\_group\_name) | The ElastiCache parameter group name |
| <a name="output_replication_group_configuration_endpoint_address"></a> [replication\_group\_configuration\_endpoint\_address](#output\_replication\_group\_configuration\_endpoint\_address) | Address of the replication group configuration endpoint. |
| <a name="output_replication_group_engine_version_actual"></a> [replication\_group\_engine\_version\_actual](#output\_replication\_group\_engine\_version\_actual) | The full version number of the cache engine running on the members of this replication group. |
| <a name="output_replication_group_region"></a> [replication\_group\_region](#output\_replication\_group\_region) | The region of the replication group. |
| <a name="output_runtime_user"></a> [runtime\_user](#output\_runtime\_user) | The user id for connecting to this replication group. |
| <a name="output_runtime_user_auth_mode"></a> [runtime\_user\_auth\_mode](#output\_runtime\_user\_auth\_mode) | The authentication mode configured for runtime user. |
<!-- END_TF_DOCS -->