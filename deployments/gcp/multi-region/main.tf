/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

locals {
  prefix = var.prefix != "" ? "${var.prefix}-" : ""
  bucket_name = "${local.prefix}pcoip-scripts-${random_id.bucket-name.hex}"
}

resource "random_id" "bucket-name" {
  byte_length = 3
}

resource "google_storage_bucket" "scripts" {
  name          = local.bucket_name
  location      = var.gcp_region
  storage_class = "REGIONAL"
  force_destroy = true
}

module "dc" {
  source = "../../../modules/gcp/dc"

  prefix = var.prefix

  gcp_service_account      = var.gcp_service_account
  kms_cryptokey_id         = var.kms_cryptokey_id
  domain_name              = var.domain_name
  admin_password           = var.dc_admin_password
  safe_mode_admin_password = var.safe_mode_admin_password
  service_account_username = var.service_account_username
  service_account_password = var.service_account_password
  domain_users_list        = var.domain_users_list

  bucket_name = google_storage_bucket.scripts.name
  gcp_zone    = var.gcp_zone
  subnet      = google_compute_subnetwork.dc-subnet.self_link
  private_ip  = var.dc_private_ip

  machine_type       = var.dc_machine_type
  disk_size_gb       = var.dc_disk_size_gb
}

module "cac-igm-0" {
  source = "../../../modules/gcp/cac-igm"

  prefix = var.prefix

  gcp_service_account     = var.gcp_service_account
  kms_cryptokey_id        = var.kms_cryptokey_id
  cam_url                 = var.cam_url
  pcoip_registration_code = var.pcoip_registration_code
  cac_token               = var.cac_token

  domain_name              = var.domain_name
  domain_controller_ip     = module.dc.internal-ip
  service_account_username = var.service_account_username
  service_account_password = var.service_account_password

  #gcp_region = "${var.gcp_region}"
  bucket_name   = google_storage_bucket.scripts.name
  gcp_zone      = var.cac_zones[0]
  subnet        = google_compute_subnetwork.cac-subnets[0].self_link
  cac_instances = var.cac_instances[0]

  machine_type       = var.cac_machine_type
  disk_image_project = var.cac_disk_image_project
  disk_image_family  = var.cac_disk_image_family
  disk_size_gb       = var.cac_disk_size_gb

  cac_admin_user             = var.cac_admin_user
  cac_admin_ssh_pub_key_file = var.cac_admin_ssh_pub_key_file
}

module "cac-igm-1" {
  source = "../../../modules/gcp/cac-igm"

  prefix = var.prefix

  gcp_service_account     = var.gcp_service_account
  kms_cryptokey_id        = var.kms_cryptokey_id
  cam_url                 = var.cam_url
  pcoip_registration_code = var.pcoip_registration_code
  cac_token               = var.cac_token

  domain_name              = var.domain_name
  domain_controller_ip     = module.dc.internal-ip
  service_account_username = var.service_account_username
  service_account_password = var.service_account_password

  #gcp_region = "${var.gcp_region}"
  bucket_name   = google_storage_bucket.scripts.name
  gcp_zone      = var.cac_zones[1]
  subnet        = google_compute_subnetwork.cac-subnets[1].self_link
  cac_instances = var.cac_instances[1]

  machine_type       = var.cac_machine_type
  disk_image_project = var.cac_disk_image_project
  disk_image_family  = var.cac_disk_image_family
  disk_size_gb       = var.cac_disk_size_gb

  cac_admin_user             = var.cac_admin_user
  cac_admin_ssh_pub_key_file = var.cac_admin_ssh_pub_key_file
}

module "cac-igm-2" {
  source = "../../../modules/gcp/cac-igm"

  prefix = var.prefix

  gcp_service_account     = var.gcp_service_account
  kms_cryptokey_id        = var.kms_cryptokey_id
  cam_url                 = var.cam_url
  pcoip_registration_code = var.pcoip_registration_code
  cac_token               = var.cac_token

  domain_name              = var.domain_name
  domain_controller_ip     = module.dc.internal-ip
  service_account_username = var.service_account_username
  service_account_password = var.service_account_password

  #gcp_region = "${var.gcp_region}"
  bucket_name   = google_storage_bucket.scripts.name
  gcp_zone      = var.cac_zones[2]
  subnet        = google_compute_subnetwork.cac-subnets[2].self_link
  cac_instances = var.cac_instances[2]

  machine_type       = var.cac_machine_type
  disk_image_project = var.cac_disk_image_project
  disk_image_family  = var.cac_disk_image_family
  disk_size_gb       = var.cac_disk_size_gb

  cac_admin_user             = var.cac_admin_user
  cac_admin_ssh_pub_key_file = var.cac_admin_ssh_pub_key_file
}

resource "google_compute_https_health_check" "cac-hchk" {
  name               = "${local.prefix}hchk-cac"
  request_path       = var.cac_health_check["path"]
  port               = var.cac_health_check["port"]
  check_interval_sec = var.cac_health_check["interval_sec"]
  timeout_sec        = var.cac_health_check["timeout_sec"]
}

resource "google_compute_backend_service" "cac-bkend-service" {
  name                    = "${local.prefix}bkend-service-cac"
  port_name               = "https"
  protocol                = "HTTPS"
  session_affinity        = "GENERATED_COOKIE"
  affinity_cookie_ttl_sec = 3600

  backend {
    balancing_mode = "UTILIZATION"

    # Wants instanceGroup instead of instanceGroupManager
    group = replace(module.cac-igm-0.cac-igm, "Manager", "")
  }

  backend {
    balancing_mode = "UTILIZATION"

    # Wants instanceGroup instead of instanceGroupManager
    group = replace(module.cac-igm-1.cac-igm, "Manager", "")
  }

  backend {
    balancing_mode = "UTILIZATION"

    # Wants instanceGroup instead of instanceGroupManager
    group = replace(module.cac-igm-2.cac-igm, "Manager", "")
  }

  health_checks = [google_compute_https_health_check.cac-hchk.self_link]
}

resource "google_compute_url_map" "cac-urlmap" {
  name            = "${local.prefix}urlmap-cac"
  default_service = google_compute_backend_service.cac-bkend-service.self_link
}

resource "google_compute_ssl_certificate" "ssl-cert" {
  name        = "${local.prefix}ssl-cert"
  private_key = file(var.ssl_key)
  certificate = file(var.ssl_cert)
}

resource "google_compute_target_https_proxy" "cac-proxy" {
  name             = "${local.prefix}proxy-cac"
  url_map          = google_compute_url_map.cac-urlmap.self_link
  ssl_certificates = [google_compute_ssl_certificate.ssl-cert.self_link]
}

resource "google_compute_global_forwarding_rule" "cac-fwdrule" {
  name = "${local.prefix}fwdrule-cac"

  #ip_protocol = "TCP"
  port_range = "443"
  target     = google_compute_target_https_proxy.cac-proxy.self_link
}

module "win-gfx" {
  source = "../../../modules/gcp/win-gfx"

  prefix = var.prefix

  gcp_service_account = var.gcp_service_account
  kms_cryptokey_id = var.kms_cryptokey_id

  pcoip_registration_code = var.pcoip_registration_code

  domain_name              = var.domain_name
  admin_password           = var.dc_admin_password
  service_account_username = var.service_account_username
  service_account_password = var.service_account_password

  bucket_name      = google_storage_bucket.scripts.name
  gcp_zone         = var.gcp_zone
  subnet           = google_compute_subnetwork.ws-subnet.self_link
  enable_public_ip = var.enable_workstation_public_ip
  instance_count   = var.win_gfx_instance_count

  machine_type      = var.win_gfx_machine_type
  accelerator_type  = var.win_gfx_accelerator_type
  accelerator_count = var.win_gfx_accelerator_count
  disk_size_gb      = var.win_gfx_disk_size_gb

  depends_on_hack = [google_compute_router_nat.nat.id]
}

module "centos-gfx" {
  source = "../../../modules/gcp/centos-gfx"

  prefix = var.prefix

  gcp_service_account = var.gcp_service_account
  kms_cryptokey_id = var.kms_cryptokey_id

  pcoip_registration_code = var.pcoip_registration_code

  domain_name              = var.domain_name
  domain_controller_ip     = module.dc.internal-ip
  service_account_username = var.service_account_username
  service_account_password = var.service_account_password

  bucket_name      = google_storage_bucket.scripts.name
  gcp_zone         = var.gcp_zone
  subnet           = google_compute_subnetwork.ws-subnet.self_link
  enable_public_ip = var.enable_workstation_public_ip
  instance_count   = var.centos_gfx_instance_count

  machine_type      = var.centos_gfx_machine_type
  accelerator_type  = var.centos_gfx_accelerator_type
  accelerator_count = var.centos_gfx_accelerator_count
  disk_size_gb      = var.centos_gfx_disk_size_gb

  ws_admin_user              = var.centos_admin_user
  ws_admin_ssh_pub_key_file  = var.centos_admin_ssh_pub_key_file

  depends_on_hack = [google_compute_router_nat.nat.id]
}

module "centos-std" {
  source = "../../../modules/gcp/centos-std"

  prefix = var.prefix

  gcp_service_account = var.gcp_service_account
  kms_cryptokey_id = var.kms_cryptokey_id

  pcoip_registration_code = var.pcoip_registration_code

  domain_name              = var.domain_name
  domain_controller_ip     = module.dc.internal-ip
  service_account_username = var.service_account_username
  service_account_password = var.service_account_password

  bucket_name      = google_storage_bucket.scripts.name
  gcp_zone         = var.gcp_zone
  subnet           = google_compute_subnetwork.ws-subnet.self_link
  enable_public_ip = var.enable_workstation_public_ip
  instance_count   = var.centos_std_instance_count

  machine_type = var.centos_std_machine_type
  disk_size_gb = var.centos_std_disk_size_gb

  ws_admin_user              = var.centos_admin_user
  ws_admin_ssh_pub_key_file  = var.centos_admin_ssh_pub_key_file

  depends_on_hack = [google_compute_router_nat.nat.id]
}
