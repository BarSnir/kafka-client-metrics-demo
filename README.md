# kafka-client-metrics-demo

This repository provides a hands-on, metrics-driven demo showcasing how Kafka Producer and Consumer configurations directly impact network connections, throughput, and cloud infrastructure costs in Confluent Cloud.

---

## Terraform Infrastructure

The `terraform/` directory provisions the full Confluent Cloud environment for this demo.

### What it creates

| Resource | Description |
|---|---|
| `confluent_environment` | Isolated demo environment |
| `confluent_kafka_cluster` | Standard single-zone Kafka cluster (AWS `us-east-1`) |
| `confluent_schema_registry_cluster` | Schema Registry (data source, auto-provisioned) |
| `confluent_kafka_topic` | `user-events` topic with 3 partitions |
| `confluent_schema` | Avro schema for `user-events-value` |
| **env-manager** service account | Admin SA for managing topics, schemas, and ACLs |
| **producer-slow** service account | Dedicated SA + Kafka key + SR key for the slow producer |
| **producer-fast** service account | Dedicated SA + Kafka key + SR key for the fast producer |
| **consumer-slow** service account | Dedicated SA + Kafka key + SR key for the slow consumer |
| **consumer-fast** service account | Dedicated SA + Kafka key + SR key for the fast consumer |
| Kafka ACLs | WRITE (producers) and READ (consumers + consumer groups) |
| SR role bindings | `DeveloperRead` on Schema Registry for all 4 application SAs |

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.3
- A Confluent Cloud account with an active organization
- A Confluent Cloud API key/secret with **OrganizationAdmin** or **EnvironmentAdmin** scope

### Required environment variables

Export the following before running any Terraform command:

```bash
export CONFLUENT_CLOUD_API_KEY="<your-confluent-cloud-api-key>"
export CONFLUENT_CLOUD_API_SECRET="<your-confluent-cloud-api-secret>"
```

### Usage

```bash
cd terraform/

# Initialize providers
terraform init

# Preview the plan
terraform plan -out=client-metrics-demo

# Apply
terraform apply client-metrics-demo
```

### Outputs

After a successful `apply`, Terraform exposes the following values (secrets are marked sensitive):

| Output | Description |
|---|---|
| `bootstrap_server` | Kafka cluster bootstrap endpoint |
| `schema_registry_url` | Schema Registry REST endpoint |
| `producer_api_key_slow` / `producer_api_secret_slow` | Kafka credentials for slow producer |
| `producer_api_key_fast` / `producer_api_secret_fast` | Kafka credentials for fast producer |
| `consumer_api_key_slow` / `consumer_api_secret_slow` | Kafka credentials for slow consumer |
| `consumer_api_key_fast` / `consumer_api_secret_fast` | Kafka credentials for fast consumer |
| `producer_sr_api_key_slow` / `producer_sr_api_secret_slow` | SR credentials for slow producer |
| `producer_sr_api_key_fast` / `producer_sr_api_secret_fast` | SR credentials for fast producer |
| `consumer_sr_api_key_slow` / `consumer_sr_api_secret_slow` | SR credentials for slow consumer |
| `consumer_sr_api_key_fast` / `consumer_sr_api_secret_fast` | SR credentials for fast consumer |

To extract sensitive values:

```bash
terraform output -json | jq '.'
```

### Teardown

```bash
terraform destroy
```
