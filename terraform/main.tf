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

# Dedicated cluster w/ PrivateLink relies on confluent_network to exist
resource "confluent_network" "aws_private_link" {
  display_name     = "AWS Private Link Network"
  cloud            = "AWS"
  region           = "us-east-2"
  connection_types = ["PRIVATELINK"]
  zones            = ["use2-az1", "use2-az2", "use2-az3"]
  environment {
    id = confluent_environment.privatelink_prototype.id
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

  network {
    id = confluent_network.aws_private_link.id
  }
}


/*
The steps for setting up AWS PrivateLink connection to Confluent Cloud are:
1. Create confluent_network resource with PRIVATELINK configuration (above)
2. Add confluent_private_link_access resource
3. Provision PrivateLink endpoints in AWS
4. Set up DNS records in AWS
5. Test PrivateLink connectivity to Confluent Cloud
*/

