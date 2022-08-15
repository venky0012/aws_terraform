variable "region" {
  default = "us-west-2"

}

variable "instance" {
  default = "t3.micro"

}



variable "vpc_cidr" {
  default = "10.0.0.0/16"

}

variable "key_name" {
  default = "NGX"
}

variable "subnet_cidr" {
  type    = list(any)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}


variable "subnet_count" {
  default = 2

}

#variable "workstation_ip" {
# type = string
#}

variable "amis" {
  type = map(any)
  default = {
    "us-west-2a" : "ami-0ddf424f81ddb0720"
    "data.aws_availability_zones.zones.names[1]" : "ami-0af6e2b3ada249943"
  }
}