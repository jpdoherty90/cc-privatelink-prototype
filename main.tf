terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.9.0"
    }
  }
}

provider "confluent" {
}

resource "confluent_environment" "privatelink_prototype" {
  display_name = "privatelink-prototype"

  stream_governance {
    package = "ESSENTIALS"
  }
}

resource "confluent_kafka_cluster" "pl_prototype_cluster" {
  display_name = "pl-prototype-cluster"
  availability = "HIGH"
  cloud        = "AWS"
  region       = "us-east-2"
  enterprise {}

  environment {
    id = confluent_environment.privatelink_prototype.id
  }
}
