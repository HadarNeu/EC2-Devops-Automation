
//getting the key from local repository
resource "tls_private_key" "ec2_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096

  provisioner "local-exec" {
        command = "echo '${tls_private_key.ec2_private_key.private_key_pem}' > ~/TerraAnsiProject/${var.key_name}.pem"
    }
}

// Making the access of .pem key as a private
resource "null_resource" "key-perm" {
    depends_on = [
        tls_private_key.ec2_private_key,
    ]

    provisioner "local-exec" {
        command = "chmod 400 ~/TerraAnsiProject/${var.key_name}.pem"
    }
}

module "key_pair" {
  source = "terraform-aws-modules/key-pair/aws"

  key_name   = "Terraform_test1"
  public_key = tls_private_key.ec2_private_key.public_key_openssh
}

// Declaring a vpc
resource "aws_vpc" "project-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "project-vpc"
  }
}

// Internet Gateway
resource "aws_internet_gateway" "project-vpcIGW" {
  depends_on = [
      aws_vpc.project-vpc
  ]
  vpc_id = aws_vpc.project-vpc.id

  tags = {
    Name = "project-vpcIGW"
  }
}

// Route Table
resource "aws_route_table" "public" {
  depends_on = [
      aws_internet_gateway.project-vpcIGW
  ]
  vpc_id = aws_vpc.project-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.project-vpcIGW.id
  }


  tags = {
    Name = "public"
  }
}

// Subnet
resource "aws_subnet" "public-subnet" {
  vpc_id            = aws_vpc.project-vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "us-west-2a"


  tags = {
    Name = "public-subnet"
  }
}

// Associate subnet to route table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.public.id
}


// Creating aws security resource
resource "aws_security_group" "allow_tcp" {
  depends_on = [
    aws_vpc.project-vpc
  ]
  name        = "allow_tcp1"
  description = "Allow TCP inbound traffic"
  vpc_id      = aws_vpc.project-vpc.id

  ingress {
    description = "TCP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tcp1"
  }
}

// Launching new EC2 instance
resource "aws_instance" "WebHost" {
    ami = var.ami
    instance_type = var.instance_type
    key_name = var.key_name
    vpc_security_group_ids = ["${aws_security_group.allow_tcp.id}"]
    subnet_id = aws_subnet.public-subnet.id
    associate_public_ip_address = true
    tags = {
        Name = "WebHost"
    }
    provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ec2-user --private-key ~/TerraAnsiProject/${var.key_name}.pem -i '${aws_instance.WebHost.public_ip},' ansiblemain.yml"
  }

}

// Creating EBS volume
resource "aws_ebs_volume" "WebVol" {
  availability_zone = "${aws_instance.WebHost.availability_zone}"
  size              = 1

  tags = {
    Name = "TeraTaskVol"
  }
}

// Attaching above volume to the EC2 instance
#resource "aws_volume_attachment" "WebVolAttach" {
#  depends_on = [
#       aws_ebs_volume.WebVol,
#  ]

#  device_name = "/dev/sdc"
#  volume_id = "${aws_ebs_volume.WebVol.id}"
#  instance_id = "${aws_instance.WebHost.id}"
#  skip_destroy = true
#}

// Configuring the external volume
#resource "null_resource" "setupVol" {
#  depends_on = [
#    aws_volume_attachment.WebVolAttach,
#  ]

  //
#  provisioner "local-exec" {
#    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ec2-user --private-key ~/.ssh/${var.key_name}.pem -i '${aws_instance.WebHost.public_ip},' ansiblemain.yml"
#  }
#}


