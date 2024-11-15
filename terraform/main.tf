terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.9.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "confluent" {
}
provider "aws" {
  region = "us-east-2"
}


resource "confluent_environment" "privatelink_prototype" {
  display_name = "privatelink-prototype"

  stream_governance {
    package = "ESSENTIALS"
  }
}


/*
At a high level, the steps for setting up AWS PrivateLink connection to Confluent Cloud are:
1. Create confluent_network resource with PRIVATELINK configuration
2. Create a Dedicated kafka cluster with that network
3. Create a VPC in AWS
4. Add confluent_private_link_access resource
5. Provision PrivateLink endpoints in AWS
6. Set up DNS records in AWS
7. Test PrivateLink connectivity to Confluent Cloud
*/


# STEP 1 Create confluent_network resource with PRIVATELINK configuration
# Dedicated cluster w/ PrivateLink relies on confluent_network to exist
# Note: AZ use1-az3 is not supported
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

# STEP 2: Create a Dedicated kafka cluster with that network
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

# STEP 3: Create a VPC in AWS 
resource "aws_vpc" "pl_prototype_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name       = "pl-prototype-vpc"
    created_by = "terraform"
  }
}


# STEP 4: Add confluent_private_link_access resource
resource "confluent_private_link_access" "aws" {
  display_name = "AWS Private Link Access"
  aws {
    account = "<ADD AWS ACCOUNT ID>"
  }
  environment {
    id = confluent_environment.privatelink_prototype.id
  }
  network {
    id = confluent_network.aws_private_link.id
  }

}