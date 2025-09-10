terraform {
  required_providers {
    sbercloud = {
      source  = "sbercloud/sbercloud"
      version = "1.38.0"
    }
  }
}

provider "sbercloud" {
  region = "ru-moscow-1"
}

resource "sbercloud_vpc" "main" {
  name = "budget-vpc"
  cidr = "192.168.0.0/16"
}

resource "sbercloud_vpc_subnet" "main" {
  name       = "budget-subnet"
  cidr       = "192.168.1.0/24"
  vpc_id     = sbercloud_vpc.main.id
  gateway_ip = "192.168.1.1"
}

resource "sbercloud_compute_instance_v2" "main" {
  name            = "budget-vm"
  image_id        = var.ubuntu_version == "22.04" ? "f1d9c1d4-3e3f-4b2e-8c1a-7b3d8e2c4f1a" : "f1d9c1d4-3e3f-4b2e-8c1a-7b3d8e2c4f1a"
  flavor_id       = "1c2g"
  security_groups = ["default"]
  network {
    uuid = sbercloud_vpc_subnet.main.id
  }
}

resource "sbercloud_lb_loadbalancer_v2" "main" {
  name          = "budget-lb"
  vip_subnet_id = sbercloud_vpc_subnet.main.id
}

resource "sbercloud_lb_listener_v2" "main" {
  name            = "budget-listener"
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = sbercloud_lb_loadbalancer_v2.main.id
}

resource "sbercloud_lb_pool_v2" "main" {
  name       = "budget-pool"
  protocol   = "HTTP"
  lb_method  = "ROUND_ROBIN"
  listener_id = sbercloud_lb_listener_v2.main.id
}

resource "sbercloud_lb_member_v2" "main" {
  address       = sbercloud_compute_instance_v2.main.access_ip_v4
  port          = 80
  pool_id       = sbercloud_lb_pool_v2.main.id
}

resource "sbercloud_rds_instance" "main" {
  name              = "budget-db"
  datastore         = "PostgreSQL"
  datastore_version = "14"
  ha_mode           = "Ha"
  password          = "SecurePassword123!"
  vpc_id            = sbercloud_vpc.main.id
  security_group_id = "default"
  availability_zone = "ru-moscow-1a"
  flavor_ref        = "rds.pg.c1.1"
  volume {
    size        = 20
    volume_type = "SSD"
  }
}

resource "sbercloud_rds_instance" "redis" {
  name              = "budget-redis"
  datastore         = "Redis"
  datastore_version = "6.2"
  password          = "SecurePassword123!"
  vpc_id            = sbercloud_vpc.main.id
  security_group_id = "default"
  availability_zone = "ru-moscow-1a"
  flavor_ref        = "rds.redis.m1.1"
  volume {
    size        = 10
    volume_type = "SSD"
  }
}

resource "sbercloud_ces_alarmrule" "main" {
  name        = "budget-monitoring"
  metric_name = "cpu_util"
  period      = 300
  condition   = ">"
  value       = 80
  type        = "system"
  dim_0_name  = "instance_id"
  dim_0_value = sbercloud_compute_instance_v2.main.id
}

resource "sbercloud_obs_bucket" "main" {
  name        = "budget-backups"
  acl         = "private"
  versioning  = true
  force_destroy = true
}

resource "sbercloud_obs_bucket_policy" "main" {
  bucket = sbercloud_obs_bucket.main.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = "s3:*"
        Resource = "${sbercloud_obs_bucket.main.arn}/*"
      }
    ]
  })
}