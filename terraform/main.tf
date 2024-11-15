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
  availability = "MULTI_ZONE"
  cloud        = "AWS"
  region       = "us-east-2"
  dedicated {
    cku = 2
  }

  environment {
    id = confluent_environment.privatelink_prototype.id
  }
}


/*
The steps for setting up AWS PrivateLink connection to Confluent Cloud are:
1. Create confluent_network resource
2. Add confluent_private_link_access resource
3. Provision PrivateLink endpoints in AWS
4. Set up DNS records in AWS
5. Test PrivateLink connectivity to Confluent Cloud
*/