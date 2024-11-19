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
3. Add confluent_private_link_access resource
4. Create a VPC in AWS
5. Create subnnets in your VPC
5. Provision PrivateLink endpoints in AWS
6. Set up DNS records in AWS
7. Test PrivateLink connectivity to Confluent Cloud
*/


# STEP 1 Create confluent_network resource with PRIVATELINK configuration
# Dedicated cluster w/ PrivateLink relies on confluent_network to exist
# Note: AZ use1-az3 is not supported
# The output "aws_service_endpoint" in outputs.tf if from this network and is needed later
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




# STEP 3: Add confluent_private_link_access resource
# Remember: 1 private link access to CC is linked to 1 AWS account ID
# If you need to connect from multiple accounts, create multiple accesses on network
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


# STEP 4: Create a VPC in AWS 
resource "aws_vpc" "pl_prototype_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name       = "pl-prototype-vpc"
    created_by = "terraform"
  }
}


# STEP 5: Create subnnets in your VPC
resource "aws_subnet" "pl_prototype_subnet_az1" {
  vpc_id            = aws_vpc.pl_prototype_vpc.id
  cidr_block        = var.pl_prototype_subnet_1_cidr
  availability_zone = "us-east-2a"

  tags = {
    Name       = "pl_prototype_subnet_az1"
    created_by = "terraform"
  }
}

resource "aws_subnet" "pl_prototype_subnet_az1" {
  vpc_id            = aws_vpc.pl_prototype_vpc.id
  cidr_block        = var.pl_prototype_subnet_2_cidr
  availability_zone = "us-east-2b"

  tags = {
    Name       = "pl_prototype_subnet_az2"
    created_by = "terraform"
  }
}

resource "aws_subnet" "pl_prototype_subnet_az1" {
  vpc_id            = aws_vpc.pl_prototype_vpc.id
  cidr_block        = var.pl_prototype_subnet_3_cidr
  availability_zone = "us-east-2c"

  tags = {
    Name       = "pl_prototype_subnet_az3"
    created_by = "terraform"
  }
}


# STEP 5: Create VPC endpoint in AWS
resource "aws_vpc_endpoint" "cc_pl_endpoint" {
  vpc_id       = aws_vpc.pl_prototype_vpc.id
  # This service_name is the same as the output in outputs.tf
  # We reference it directly here, but provide it as output as well in case you are creating endpoint manually
  service_name = confluent_network.aws_private_link.aws[0].private_link_endpoint_service

  tags = {
    Name = "pl-prototype-endpoint"
  }
}
