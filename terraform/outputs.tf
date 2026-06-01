output "bootstrap_server" {
  value       = confluent_kafka_cluster.bsnir_standard_cluster.bootstrap_endpoint
  description = "Kafka Cluster Bootstrap Server URL"
}

output "schema_registry_url" {
  value       = data.confluent_schema_registry_cluster.sr.rest_endpoint
  description = "Schema Registry Endpoint URL"
}

output "producer_api_key_slow" {
  value       = confluent_api_key.bsnir_producer_key_slow.id
  description = "API Key for Slow Producer"
}

output "producer_api_secret_slow" {
  value     = confluent_api_key.bsnir_producer_key_slow.secret
  sensitive = true
}

output "producer_api_key_fast" {
  value       = confluent_api_key.bsnir_producer_key_fast.id
  description = "API Key for Fast Producer"
}

output "producer_api_secret_fast" {
  value     = confluent_api_key.bsnir_producer_key_fast.secret
  sensitive = true
}

output "consumer_api_key_slow" {
  value       = confluent_api_key.bsnir_consumer_key_slow.id
  description = "API Key for Slow Consumer"
}

output "consumer_api_secret_slow" {
  value     = confluent_api_key.bsnir_consumer_key_slow.secret
  sensitive = true
}

output "consumer_api_key_fast" {
  value       = confluent_api_key.bsnir_consumer_key_fast.id
  description = "API Key for Fast Consumer"
}

output "consumer_api_secret_fast" {
  value     = confluent_api_key.bsnir_consumer_key_fast.secret
  sensitive = true
}

# =========================================================================
# SCHEMA REGISTRY API KEYS
# =========================================================================

output "producer_sr_api_key_slow" {
  value       = confluent_api_key.bsnir_producer_sr_key_slow.id
  description = "Schema Registry API Key for Slow Producer"
}

output "producer_sr_api_secret_slow" {
  value     = confluent_api_key.bsnir_producer_sr_key_slow.secret
  sensitive = true
}

output "producer_sr_api_key_fast" {
  value       = confluent_api_key.bsnir_producer_sr_key_fast.id
  description = "Schema Registry API Key for Fast Producer"
}

output "producer_sr_api_secret_fast" {
  value     = confluent_api_key.bsnir_producer_sr_key_fast.secret
  sensitive = true
}

output "consumer_sr_api_key_slow" {
  value       = confluent_api_key.bsnir_consumer_sr_key_slow.id
  description = "Schema Registry API Key for Slow Consumer"
}

output "consumer_sr_api_secret_slow" {
  value     = confluent_api_key.bsnir_consumer_sr_key_slow.secret
  sensitive = true
}

output "consumer_sr_api_key_fast" {
  value       = confluent_api_key.bsnir_consumer_sr_key_fast.id
  description = "Schema Registry API Key for Fast Consumer"
}

output "consumer_sr_api_secret_fast" {
  value     = confluent_api_key.bsnir_consumer_sr_key_fast.secret
  sensitive = true
}
