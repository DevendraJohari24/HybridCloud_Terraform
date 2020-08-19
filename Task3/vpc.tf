provider "aws"{
    region = "ap-south-1"
    profile = "Dev"
}

#CREATE A KEY PAIR


resource "tls_private_key" "keypairos" {
  algorithm   = "RSA"
  rsa_bits = 2048
}

resource "local_file" "keypairos2" {
    content     = tls_private_key.keypairos.private_key_pem
    filename = "keypair2011.pem"
    file_permission = 0400
}


resource "aws_key_pair" "deployer" {
  key_name   = "keypairdev"
  public_key = tls_private_key.keypairos.public_key_openssh
}

resource "aws_vpc" "main_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_support = "true"
  enable_dns_hostnames = "true"

  tags = {
    Name = "VPC Main"
  }
}

resource  "aws_internet_gateway" "igw"{
        vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "Internet gateway public"
  }
}

# HTTP CONNECTION PUBLIC SECURITY GROUP

resource "aws_security_group" "securityos" {
    name = "vpc_web"
    description = "Allow incoming HTTP connections."

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = -1
        to_port = -1
        protocol = "icmp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress { # SQL Server
        from_port = 1433
        to_port = 1433
        protocol = "tcp"
        cidr_blocks = ["10.0.1.0/24"]
    }
    egress { # MySQL
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        cidr_blocks = ["10.0.1.0/24"]
    }

    vpc_id = aws_vpc.main_vpc.id

    tags= {
        Name = "Public Subnet WebServer"
    }
}


# PUBLIC SUBNET
 resource "aws_subnet" "subnet_public1"{
     vpc_id = aws_vpc.main_vpc.id
     map_public_ip_on_launch = "true"
     availability_zone = "ap-south-1a"
     cidr_block = "10.0.0.0/24"


     tags = {
         Name = "Public VPC Subnet"
     }
 }

 resource "aws_route_table" "routetable" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public Subnet Route Table"
  }
}

resource "aws_route_table_association" "route_table_public_subnet"{
    subnet_id = "${aws_subnet.subnet_public1.id}"
    route_table_id = "${aws_route_table.routetable.id}"
}




resource "aws_instance" "myoperatingsys" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = aws_key_pair.deployer.key_name
  vpc_security_group_ids = ["${aws_security_group.securityos.id}"]
  associate_public_ip_address = true
  subnet_id = aws_subnet.subnet_public1.id
 tags = {
       Name = "My WebServer Instance"
      }

}

# PRIVATE DATABASE SERVER SECURITY GROUP
resource "aws_security_group" "db" {
    name = "vpc_db"
    description = "Allow incoming database connections."

    ingress { # SQL Server
        from_port = 1433
        to_port = 1433
        protocol = "tcp"
        security_groups = ["${aws_security_group.securityos.id}"]
    }
    ingress { # MySQL
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        security_groups = ["${aws_security_group.securityos.id}"]
    }

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["10.0.0.0/16"]
    }
    ingress {
        from_port = -1
        to_port = -1
        protocol = "icmp"
        cidr_blocks = ["10.0.0.0/16"]
    }

    egress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    vpc_id = "${aws_vpc.main_vpc.id}"

    tags = {
        Name = "Database Servers"
    }
}

# Private Subnet

 resource "aws_subnet" "subnet_private1"{
     vpc_id = aws_vpc.main_vpc.id
     cidr_block = "10.0.1.0/24"
     availability_zone = "ap-south-1a"
     tags = {
         Name = "Private VPC Subnet"
     }
 }

  resource "aws_route_table" "routetableprivate" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    instance_id = "${aws_instance.myoperatingsys.id}"
  }

  tags = {
    Name = "Private Subnet Route Table"
  }
}

resource "aws_route_table_association" "route_table_private_subnet"{
    subnet_id = "${aws_subnet.subnet_private1.id}"
    route_table_id = "${aws_route_table.routetableprivate.id}"
}


resource "aws_instance" "myoperatingsysdb" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = aws_key_pair.deployer.key_name
  vpc_security_group_ids = ["${aws_security_group.db.id}"]
  subnet_id = aws_subnet.subnet_private1.id
  

 tags = {
       Name = "MySql Instance"
      }
}

#OUTPUT IP SHOWN IN COMMAND PROMPT
output "myos_ip" {
    value = aws_instance.myoperatingsys.public_ip
}

#SAVE IP TO LOCAL FILE 
resource "null_resource" "nulllocal1" {
     provisioner "local-exec" {
             command = "echo ${aws_instance.myoperatingsys.public_ip} >publicip.txt"
          }
}

#OPENING CHROME AND SEARCH IP

resource "null_resource" "nulllocal0608"  {

	provisioner "local-exec" {
	    command = "start chrome  ${aws_instance.myoperatingsys.public_ip}"
  	}
}
