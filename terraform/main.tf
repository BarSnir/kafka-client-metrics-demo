# =========================================================================
# INITIAL SETUP
# =========================================================================
terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.5.0"
    }
  }
}

# export CONFLUENT_CLOUD_API_KEY
# export CONFLUENT_CLOUD_API_SECRET
provider "confluent" {}

# =========================================================================
# 1. ENVIRONMENT & CLUSTER DEFINITION
# =========================================================================
resource "confluent_environment" "bsnir_demo_env" {
  display_name = "bsnir-kafka-metrics-demo-env"
}
resource "confluent_kafka_cluster" "bsnir_standard_cluster" {
  display_name = "bsnir-metrics-demo-cluster"
  availability = "SINGLE_ZONE"
  cloud        = "AWS"
  region       = "us-east-1"
  standard {}
  environment {
    id = confluent_environment.bsnir_demo_env.id
  }
}
data "confluent_schema_registry_cluster" "sr" {
  environment {
    id = confluent_environment.bsnir_demo_env.id
  }
  depends_on = [
    confluent_kafka_cluster.bsnir_standard_cluster
  ]
}
# =========================================================================
# ADMINISTRATIVE ACCESS
# =========================================================================
resource "confluent_service_account" "bsnir_env_manager" {
  display_name = "bsnir-demo-env-manager"
  description  = "Service Account to manage Kafka topics and schemas via Terraform"
}
resource "confluent_role_binding" "bsnir_env_manager_rb" {
  principal   = "User:${confluent_service_account.bsnir_env_manager.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.bsnir_demo_env.resource_name
}
resource "confluent_api_key" "bsnir_env_manager_kafka_key" {
  display_name = "bsnir-env-manager-kafka-key"
  owner {
    id          = confluent_service_account.bsnir_env_manager.id
    api_version = confluent_service_account.bsnir_env_manager.api_version
    kind        = confluent_service_account.bsnir_env_manager.kind
  }
  managed_resource {
    id          = confluent_kafka_cluster.bsnir_standard_cluster.id
    api_version = confluent_kafka_cluster.bsnir_standard_cluster.api_version
    kind        = confluent_kafka_cluster.bsnir_standard_cluster.kind
    environment {
      id = confluent_environment.bsnir_demo_env.id
    }
  }
  depends_on = [
    confluent_role_binding.bsnir_env_manager_rb
  ]
}
resource "confluent_api_key" "bsnir_env_manager_sr_key" {
  display_name = "bsnir-env-manager-sr-key"
  owner {
    id          = confluent_service_account.bsnir_env_manager.id
    api_version = confluent_service_account.bsnir_env_manager.api_version
    kind        = confluent_service_account.bsnir_env_manager.kind
  }
  managed_resource {
    id          = data.confluent_schema_registry_cluster.sr.id
    api_version = data.confluent_schema_registry_cluster.sr.api_version
    kind        = data.confluent_schema_registry_cluster.sr.kind
    environment {
      id = confluent_environment.bsnir_demo_env.id
    }
  }
  depends_on = [
    confluent_role_binding.bsnir_env_manager_rb
  ]
}
# =========================================================================
# TOPIC & SCHEMA DEFINITIONS
# =========================================================================
resource "confluent_kafka_topic" "bsnir_demo_topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.bsnir_standard_cluster.id
  }
  topic_name       = "user-events"
  partitions_count = 3
  rest_endpoint    = confluent_kafka_cluster.bsnir_standard_cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.bsnir_env_manager_kafka_key.id
    secret = confluent_api_key.bsnir_env_manager_kafka_key.secret
  }
}
resource "confluent_schema" "bsnir_user_event_schema" {
  schema_registry_cluster {
    id = data.confluent_schema_registry_cluster.sr.id
  }
  rest_endpoint = data.confluent_schema_registry_cluster.sr.rest_endpoint
  subject_name  = "user-events-value"
  format        = "AVRO"
  schema        = <<EOF
{
  "type": "record",
  "name": "UserEvent",
  "namespace": "com.demo",
  "fields": [
    {"name": "eventId", "type": "string"},
    {"name": "timestamp", "type": "long"},
    {"name": "payload", "type": "string"}
  ]
}
EOF

  credentials {
    key    = confluent_api_key.bsnir_env_manager_sr_key.id
    secret = confluent_api_key.bsnir_env_manager_sr_key.secret
  }
  depends_on = [
    confluent_kafka_topic.bsnir_demo_topic
  ]
}

# =========================================================================
# PRODUCER SERVICE ACCOUNT & ACLS
# =========================================================================
resource "confluent_service_account" "bsnir_producer_sa_slow" {
  display_name = "bsnir-metrics-demo-producer-slow"
  description  = "Service Account for Kafka Producers (Slow)"
}

resource "confluent_api_key" "bsnir_producer_key_slow" {
  display_name = "bsnir-producer-kafka-api-key-slow"
  owner {
    id          = confluent_service_account.bsnir_producer_sa_slow.id
    api_version = confluent_service_account.bsnir_producer_sa_slow.api_version
    kind        = confluent_service_account.bsnir_producer_sa_slow.kind
  }
  managed_resource {
    id          = confluent_kafka_cluster.bsnir_standard_cluster.id
    api_version = confluent_kafka_cluster.bsnir_standard_cluster.api_version
    kind        = confluent_kafka_cluster.bsnir_standard_cluster.kind
    environment {
      id = confluent_environment.bsnir_demo_env.id
    }
  }
}

resource "confluent_service_account" "bsnir_producer_sa_fast" {
  display_name = "bsnir-metrics-demo-producer-fast"
  description  = "Service Account for Kafka Producers (Fast)"
}

resource "confluent_api_key" "bsnir_producer_key_fast" {
  display_name = "bsnir-producer-kafka-api-key-fast"
  owner {
    id          = confluent_service_account.bsnir_producer_sa_fast.id
    api_version = confluent_service_account.bsnir_producer_sa_fast.api_version
    kind        = confluent_service_account.bsnir_producer_sa_fast.kind
  }
  managed_resource {
    id          = confluent_kafka_cluster.bsnir_standard_cluster.id
    api_version = confluent_kafka_cluster.bsnir_standard_cluster.api_version
    kind        = confluent_kafka_cluster.bsnir_standard_cluster.kind
    environment {
      id = confluent_environment.bsnir_demo_env.id
    }
  }
}

resource "confluent_kafka_acl" "bsnir_producer_write_topic_slow" {
  kafka_cluster {
    id = confluent_kafka_cluster.bsnir_standard_cluster.id
  }
  rest_endpoint = confluent_kafka_cluster.bsnir_standard_cluster.rest_endpoint
  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.bsnir_demo_topic.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.bsnir_producer_sa_slow.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"

  credentials {
    key    = confluent_api_key.bsnir_env_manager_kafka_key.id
    secret = confluent_api_key.bsnir_env_manager_kafka_key.secret
  }
}

resource "confluent_kafka_acl" "bsnir_producer_write_topic_fast" {
  kafka_cluster {
    id = confluent_kafka_cluster.bsnir_standard_cluster.id
  }
  rest_endpoint = confluent_kafka_cluster.bsnir_standard_cluster.rest_endpoint
  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.bsnir_demo_topic.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.bsnir_producer_sa_fast.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"

  credentials {
    key    = confluent_api_key.bsnir_env_manager_kafka_key.id
    secret = confluent_api_key.bsnir_env_manager_kafka_key.secret
  }
}

# =========================================================================
# CONSUMER SERVICE ACCOUNT & ACLS
# =========================================================================
resource "confluent_service_account" "bsnir_consumer_sa_slow" {
  display_name = "bsnir-metrics-demo-consumer-slow"
  description  = "Service Account for Kafka Consumers (Chatty & Buffered)"
}

resource "confluent_api_key" "bsnir_consumer_key_slow" {
  display_name = "bsnir-consumer-kafka-api-key-slow"
  owner {
    id          = confluent_service_account.bsnir_consumer_sa_slow.id
    api_version = confluent_service_account.bsnir_consumer_sa_slow.api_version
    kind        = confluent_service_account.bsnir_consumer_sa_slow.kind
  }
  managed_resource {
    id          = confluent_kafka_cluster.bsnir_standard_cluster.id
    api_version = confluent_kafka_cluster.bsnir_standard_cluster.api_version
    kind        = confluent_kafka_cluster.bsnir_standard_cluster.kind
    environment {
      id = confluent_environment.bsnir_demo_env.id
    }
  }
}

resource "confluent_kafka_acl" "bsnir_consumer_read_topic_slow" {
  kafka_cluster {
    id = confluent_kafka_cluster.bsnir_standard_cluster.id
  }
  rest_endpoint = confluent_kafka_cluster.bsnir_standard_cluster.rest_endpoint
  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.bsnir_demo_topic.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.bsnir_consumer_sa_slow.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"

  credentials {
    key    = confluent_api_key.bsnir_env_manager_kafka_key.id
    secret = confluent_api_key.bsnir_env_manager_kafka_key.secret
  }
}

resource "confluent_kafka_acl" "bsnir_consumer_read_group_slow" {
  kafka_cluster {
    id = confluent_kafka_cluster.bsnir_standard_cluster.id
  }
  rest_endpoint = confluent_kafka_cluster.bsnir_standard_cluster.rest_endpoint
  resource_type = "GROUP"
  resource_name = "slow-group"
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.bsnir_consumer_sa_slow.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"

  credentials {
    key    = confluent_api_key.bsnir_env_manager_kafka_key.id
    secret = confluent_api_key.bsnir_env_manager_kafka_key.secret
  }
}

resource "confluent_service_account" "bsnir_consumer_sa_fast" {
  display_name = "bsnir-metrics-demo-consumer-fast"
  description  = "Service Account for Kafka Consumers (Chatty & Buffered)"
}

resource "confluent_api_key" "bsnir_consumer_key_fast" {
  display_name = "bsnir-consumer-kafka-api-key-fast"
  owner {
    id          = confluent_service_account.bsnir_consumer_sa_fast.id
    api_version = confluent_service_account.bsnir_consumer_sa_fast.api_version
    kind        = confluent_service_account.bsnir_consumer_sa_fast.kind
  }
  managed_resource {
    id          = confluent_kafka_cluster.bsnir_standard_cluster.id
    api_version = confluent_kafka_cluster.bsnir_standard_cluster.api_version
    kind        = confluent_kafka_cluster.bsnir_standard_cluster.kind
    environment {
      id = confluent_environment.bsnir_demo_env.id
    }
  }
}

resource "confluent_kafka_acl" "bsnir_consumer_read_topic_fast" {
  kafka_cluster {
    id = confluent_kafka_cluster.bsnir_standard_cluster.id
  }
  rest_endpoint = confluent_kafka_cluster.bsnir_standard_cluster.rest_endpoint
  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.bsnir_demo_topic.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.bsnir_consumer_sa_fast.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"

  credentials {
    key    = confluent_api_key.bsnir_env_manager_kafka_key.id
    secret = confluent_api_key.bsnir_env_manager_kafka_key.secret
  }
}

resource "confluent_kafka_acl" "bsnir_consumer_read_group_fast" {
  kafka_cluster {
    id = confluent_kafka_cluster.bsnir_standard_cluster.id
  }
  rest_endpoint = confluent_kafka_cluster.bsnir_standard_cluster.rest_endpoint
  resource_type = "GROUP"
  resource_name = "fast-group"
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.bsnir_consumer_sa_fast.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"

  credentials {
    key    = confluent_api_key.bsnir_env_manager_kafka_key.id
    secret = confluent_api_key.bsnir_env_manager_kafka_key.secret
  }
}

# =========================================================================
# SCHEMA REGISTRY ACCESS (role bindings + API keys per application)
# =========================================================================

# --- Producer Slow ---
resource "confluent_role_binding" "bsnir_producer_slow_sr_rb" {
  principal   = "User:${confluent_service_account.bsnir_producer_sa_slow.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${data.confluent_schema_registry_cluster.sr.resource_name}/subject=*"
}

resource "confluent_api_key" "bsnir_producer_sr_key_slow" {
  display_name = "bsnir-producer-sr-api-key-slow"
  owner {
    id          = confluent_service_account.bsnir_producer_sa_slow.id
    api_version = confluent_service_account.bsnir_producer_sa_slow.api_version
    kind        = confluent_service_account.bsnir_producer_sa_slow.kind
  }
  managed_resource {
    id          = data.confluent_schema_registry_cluster.sr.id
    api_version = data.confluent_schema_registry_cluster.sr.api_version
    kind        = data.confluent_schema_registry_cluster.sr.kind
    environment {
      id = confluent_environment.bsnir_demo_env.id
    }
  }
  depends_on = [confluent_role_binding.bsnir_producer_slow_sr_rb]
}

# --- Producer Fast ---
resource "confluent_role_binding" "bsnir_producer_fast_sr_rb" {
  principal   = "User:${confluent_service_account.bsnir_producer_sa_fast.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${data.confluent_schema_registry_cluster.sr.resource_name}/subject=*"
}

resource "confluent_api_key" "bsnir_producer_sr_key_fast" {
  display_name = "bsnir-producer-sr-api-key-fast"
  owner {
    id          = confluent_service_account.bsnir_producer_sa_fast.id
    api_version = confluent_service_account.bsnir_producer_sa_fast.api_version
    kind        = confluent_service_account.bsnir_producer_sa_fast.kind
  }
  managed_resource {
    id          = data.confluent_schema_registry_cluster.sr.id
    api_version = data.confluent_schema_registry_cluster.sr.api_version
    kind        = data.confluent_schema_registry_cluster.sr.kind
    environment {
      id = confluent_environment.bsnir_demo_env.id
    }
  }
  depends_on = [confluent_role_binding.bsnir_producer_fast_sr_rb]
}

# --- Consumer Slow ---
resource "confluent_role_binding" "bsnir_consumer_slow_sr_rb" {
  principal   = "User:${confluent_service_account.bsnir_consumer_sa_slow.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${data.confluent_schema_registry_cluster.sr.resource_name}/subject=*"
}

resource "confluent_api_key" "bsnir_consumer_sr_key_slow" {
  display_name = "bsnir-consumer-sr-api-key-slow"
  owner {
    id          = confluent_service_account.bsnir_consumer_sa_slow.id
    api_version = confluent_service_account.bsnir_consumer_sa_slow.api_version
    kind        = confluent_service_account.bsnir_consumer_sa_slow.kind
  }
  managed_resource {
    id          = data.confluent_schema_registry_cluster.sr.id
    api_version = data.confluent_schema_registry_cluster.sr.api_version
    kind        = data.confluent_schema_registry_cluster.sr.kind
    environment {
      id = confluent_environment.bsnir_demo_env.id
    }
  }
  depends_on = [confluent_role_binding.bsnir_consumer_slow_sr_rb]
}

# --- Consumer Fast ---
resource "confluent_role_binding" "bsnir_consumer_fast_sr_rb" {
  principal   = "User:${confluent_service_account.bsnir_consumer_sa_fast.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${data.confluent_schema_registry_cluster.sr.resource_name}/subject=*"
}

resource "confluent_api_key" "bsnir_consumer_sr_key_fast" {
  display_name = "bsnir-consumer-sr-api-key-fast"
  owner {
    id          = confluent_service_account.bsnir_consumer_sa_fast.id
    api_version = confluent_service_account.bsnir_consumer_sa_fast.api_version
    kind        = confluent_service_account.bsnir_consumer_sa_fast.kind
  }
  managed_resource {
    id          = data.confluent_schema_registry_cluster.sr.id
    api_version = data.confluent_schema_registry_cluster.sr.api_version
    kind        = data.confluent_schema_registry_cluster.sr.kind
    environment {
      id = confluent_environment.bsnir_demo_env.id
    }
  }
  depends_on = [confluent_role_binding.bsnir_consumer_fast_sr_rb]
}
