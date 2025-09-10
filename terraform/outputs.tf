output "vpc_id" {
  description = "ID VPC сети"
  value       = sbercloud_vpc.main.id
}

output "subnet_id" {
  description = "ID подсети"
  value       = sbercloud_vpc_subnet.main.id
}

output "vm_ip" {
  description = "IP адрес виртуальной машины"
  value       = sbercloud_compute_instance_v2.main.access_ip_v4
}

output "lb_ip" {
  description = "IP адрес балансировщика нагрузки"
  value       = sbercloud_lb_loadbalancer_v2.main.vip_address
}

output "db_endpoint" {
  description = "Endpoint базы данных PostgreSQL"
  value       = sbercloud_rds_instance.main.readonly_instances[0].ha_ip
}

output "redis_endpoint" {
  description = "Endpoint Redis"
  value       = sbercloud_rds_instance.redis.readonly_instances[0].ha_ip
}

output "bucket_name" {
  description = "Имя бакета для бэкапов"
  value       = sbercloud_obs_bucket.main.id
}

output "bucket_endpoint" {
  description = "Endpoint бакета для бэкапов"
  value       = sbercloud_obs_bucket.main.bucket_domain_name
}