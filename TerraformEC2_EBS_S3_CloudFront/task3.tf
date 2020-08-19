provider "aws"{
    region = "ap-south-1a"
    profile = "Dev"
}

variable "Enter_ur_key_name" {default="os"}


#CREATE A KEY PAIR


resource "tls_private_key" "keydev" {
  algorithm   = "ECDSA"
  rsa_bits = 2048
}

resource "local_file" "keypairos2" {
    content     = tls_private_key.keydev.private_key_pem
    filename = "${var.Enter_ur_key_name}.pem" 
    file_permission = 0400	
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.Enter_ur_key_name
  public_key = tls_private_key.keydev.public_key_openssh
}

# Setting VPC 

resource "aws_vpc" "main_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_support = "true"

  tags = {
    Name = "VPC_Main"
  }
}

 resource "aws_subnet" "subnet_public1"{
     vpc_id = aws_vpc.main_vpc.id
     cidr_block = "10.0.1.0/24"
     public_subnets = ["10.0.101.0/24"]
     map_public_ip_on_launch = "true"
     availability_zone = "ap-south-1a"


     tags = {
         Name = "Public_VPC_Subnet"
     }
 }
  resource  "aws_internet_gateway" "subnetpublicigw"{
        vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "Internet_gateway_public"
  }
}

resource "aws_route_table" "routetable" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/24"
    gateway_id = aws_internet_gateway.subnetpublicigw.id
  }

  tags = {
    Name = "Route_Table"
  }
}
resource "aws_route_table_association" "route_table_public_subnet"{
    subnet_id = "${aws_subnet.subnet_public1.id}"
    route_table_id = "${aws_route_table.routetable.id}"
}


# Creating a Security Group
resource "aws_security_group" "security" {
  vpc_id = aws_default_vpc.main_vpc.id
  name        = "websecurity"
ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
    Name = "websecuritygroup"
  }
}




# CREATING INSTANCE EC2
resource "aws_instance" "myoperatingsys" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = aws_key_pair.generated_key.key_name
  vpc_security_group_ids = ["${aws_security_group.security.id}"]
  
   connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.keypairos.private_key_pem
    host     = aws_instance.myoperatingsys.public_ip
  }

  
   provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y ",
      "sudo systemctl restart httpd",
       "sudo systemctl enable httpd",
        
    ]
  }

 tags = {
       Name = "MyOS1"
      }

}