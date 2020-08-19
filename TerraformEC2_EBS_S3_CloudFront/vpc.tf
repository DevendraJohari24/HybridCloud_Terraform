variable "public_subnet_cidr" {
    description = "CIDR for the Public Subnet"
    default = "10.0.0.0/24"
}

variable "private_subnet_cidr" {
    description = "CIDR for the Private Subnet"
    default = "10.0.1.0/24"
}

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

resource "aws_vpc" "main_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_support = "true"

  tags = {
    Name = "VPC_Main"
  }
}

resource  "aws_internet_gateway" "igw"{
        vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "Internet_gateway_public"
  }
}

resource "aws_security_group" "securityos" {
  vpc_id = aws_vpc.main_vpc.id
  name        = "websecurity"
ingress {

    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.private_subnet_cidr}"]
  }

ingress{
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["${var.private_subnet_cidr}"]

}

ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress{
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
}
egress {

    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress{
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

}

ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

ingress{
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
}

  tags = {
    Name = "websecuritygroup"
  }
}

resource "aws_instance" "myoperatingsys" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = aws_key_pair.generated_key.key_name
  vpc_security_group_ids = ["${aws_security_group.securityos.id}"]
  associate_public_ip_address = true
  subnet_id = aws_subnet.subnet_public1.id
  
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

resource "aws_eip" "elastic_ip"{
    instance = aws_instance.myoperatingsys.id
    vpc = true
}

# PUBLIC SUBNET
 resource "aws_subnet" "subnet_public1"{
     vpc_id = aws_vpc.main_vpc.id
     cidr_block = "10.0.1.0/24"
     map_public_ip_on_launch = "true"
     availability_zone = "ap-south-1a"


     tags = {
         Name = "Public_VPC_Subnet"
     }
 }

 resource "aws_route_table" "routetable" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public_Subnet_Route_Table"
  }
}

resource "aws_route_table_association" "route_table_public_subnet"{
    subnet_id = aws_subnet.subnet_public1.id
    route_table_id = "${aws_route_table.routetable.id}"
}


# Private Subnet

 resource "aws_subnet" "subnet_private1"{
     vpc_id = aws_vpc.main_vpc.id
     cidr_block = "${var.private_subnet_cidr}"
     availability_zone = "ap-south-1a"


     tags = {
         Name = "Private_VPC_Subnet"
     }
 }

  resource "aws_route_table" "routetableprivate" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    instance_id = "${aws_instance.myoperatingsys.id}"
  }

  tags = {
    Name = "Private_Subnet_Route_Table"
  }
}

resource "aws_route_table_association" "route_table_private_subnet"{
    subnet_id = "${aws_subnet.subnet_private1.id}"
    route_table_id = "${aws_route_table.routetableprivate.id}"
}

