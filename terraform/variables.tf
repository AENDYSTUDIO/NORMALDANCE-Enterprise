variable "region" {
  description = "Регион Cloud.ru"
  default     = "ru-moscow-1"
}

variable "vpc_cidr" {
  description = "CIDR блок для VPC"
  default     = "192.168.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR блок для подсети"
  default     = "192.168.1.0/24"
}

variable "vm_image" {
  description = "ID образа для виртуальной машины"
  default     = "f1d9c1d4-3e3f-4b2e-8c1a-7b3d8e2c4f1a"
}

variable "vm_flavor" {
  description = "Тип виртуальной машины"
  default     = "1c2g"
}

variable "db_password" {
  description = "Пароль для базы данных"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Имя базы данных"
  default     = "budget-db"
}

variable "redis_password" {
  description = "Пароль для Redis"
  type        = string
  sensitive   = true
}

variable "bucket_name" {
  description = "Имя бакета для бэкапов"
  default     = "budget-backups"
}

variable "ubuntu_version" {
  description = "Версия Ubuntu для виртуальных машин"
  type        = string
  default     = "22.04"
  validation {
    condition     = contains(["22.04", "24.04"], var.ubuntu_version)
    error_message = "Допустимые значения: 22.04 или 24.04"
  }
}