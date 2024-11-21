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
5. Create segurity group w/ rules
6. Create subnnets in your VPC
7. Provision PrivateLink endpoints in AWS
8. Setup an EC2 instance in your VPC to test connectivity
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
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name       = "pl-prototype-vpc"
    created_by = "terraform"
  }
}


# STEP 5: Create a security group w/ ingress/egress rules
resource "aws_security_group" "cc_pl_endpoint_sg" {
  name        = "cc-pl-endpoint-sg"
  vpc_id      = aws_vpc.pl_prototype_vpc.id

  ingress {
    from_port        = 9092
    to_port          = 9092
    protocol         = "tcp"
    cidr_blocks      = ["10.0.0.0/16"]
  }

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["10.0.0.0/16"]
  }

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["10.0.0.0/16"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}



# STEP 6: Create subnnets in your VPC
resource "aws_subnet" "pl_prototype_subnet_a" {
  vpc_id            = aws_vpc.pl_prototype_vpc.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name       = "pl_prototype_subnet_a"
  }
}
resource "aws_subnet" "pl_prototype_subnet_b" {
  vpc_id            = aws_vpc.pl_prototype_vpc.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "us-east-2b"

  tags = {
    Name       = "pl_prototype_subnet_b"
  }
}
resource "aws_subnet" "pl_prototype_subnet_c" {
  vpc_id            = aws_vpc.pl_prototype_vpc.id
  cidr_block        = "10.0.30.0/24"
  availability_zone = "us-east-2c"

  tags = {
    Name       = "pl_prototype_subnet_c"
  }
}


# STEP 7: Create VPC endpoint in AWS
resource "aws_vpc_endpoint" "cc_pl_endpoint" {
  vpc_id       = aws_vpc.pl_prototype_vpc.id
  service_name = confluent_network.aws_private_link.aws[0].private_link_endpoint_service
  vpc_endpoint_type = "Interface"
  security_group_ids = [aws_security_group.cc_pl_endpoint_sg.id]
  subnet_ids = [
    aws_subnet.pl_prototype_subnet_a.id,
    aws_subnet.pl_prototype_subnet_b.id,
    aws_subnet.pl_prototype_subnet_c.id,
  ]

  tags = {
    Name = "pl-prototype-endpoint"
  }
}




# IAM role that allows EC2 instance to communicate with AWS Systems Manager
resource "aws_iam_role" "producer_ssm_role" {
  name = "producer_ssm_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

}



# STEP : Create an EC2 to run your python producer in
resource "aws_instance" "python_producer_ec2" {
  ami           = "ami-0942ecd5d85baa812" # us-east-2
  instance_type = "t3.small"
  subnet_id = aws_subnet.pl_prototype_subnet_a.id

  tags = {
    Name = "PythonProducerInstance"
  }
}
