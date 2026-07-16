provider "google" {
  project = var.project_id
}

locals {
  name = "order-${var.environment}-global"
  negs = merge([
    for region_name, region in var.regions : {
      for zone in region.zones : "${region_name}/${zone}" => {
        region          = region_name
        zone            = zone
        name            = region.neg_name
        capacity_scaler = region.capacity_scaler
      }
    }
  ]...)
}

data "google_compute_network_endpoint_group" "regional" {
  for_each = local.negs
  project  = var.project_id
  name     = each.value.name
  zone     = each.value.zone
}

resource "google_compute_health_check" "application" {
  project             = var.project_id
  name                = "${local.name}-health"
  check_interval_sec  = 5
  timeout_sec         = 3
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 8080
    request_path = "/readyz"
  }

  log_config {
    enable = true
  }
}

resource "google_compute_backend_service" "application" {
  project                         = var.project_id
  name                            = "${local.name}-backend"
  protocol                        = "HTTP"
  port_name                       = "http"
  load_balancing_scheme           = "EXTERNAL_MANAGED"
  timeout_sec                     = 30
  connection_draining_timeout_sec = 30
  health_checks                   = [google_compute_health_check.application.id]
  security_policy                 = google_compute_security_policy.application.id

  dynamic "backend" {
    for_each = data.google_compute_network_endpoint_group.regional
    content {
      group                 = backend.value.id
      balancing_mode        = "RATE"
      max_rate_per_endpoint = var.max_rate_per_endpoint
      capacity_scaler       = local.negs[backend.key].capacity_scaler
    }
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_security_policy" "application" {
  project     = var.project_id
  name        = "${local.name}-waf"
  description = "Cloud Armor WAF and per-client abuse protection for order-service"
  type        = "CLOUD_ARMOR"

  rule {
    action      = "rate_based_ban"
    priority    = 900
    description = "Rate-limit and temporarily ban abusive client IPs"
    preview     = var.waf_preview

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }

    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"

      rate_limit_threshold {
        count        = var.waf_rate_limit_requests_per_min
        interval_sec = 60
      }

      ban_duration_sec = 300
      ban_threshold {
        count        = var.waf_rate_limit_requests_per_min * 2
        interval_sec = 60
      }
    }
  }

  dynamic "rule" {
    for_each = {
      1000 = ["sqli-v33-stable", "SQL injection"]
      1010 = ["xss-v33-stable", "Cross-site scripting"]
      1020 = ["lfi-v33-stable", "Local file inclusion"]
      1030 = ["rfi-v33-stable", "Remote file inclusion"]
      1040 = ["rce-v33-stable", "Remote code execution"]
      1050 = ["scannerdetection-v33-stable", "Scanner detection"]
      1060 = ["protocolattack-v33-stable", "HTTP protocol attack"]
    }

    content {
      action      = "deny(403)"
      priority    = tonumber(rule.key)
      description = "OWASP ${rule.value[1]} protection"
      preview     = var.waf_preview

      match {
        expr {
          expression = "evaluatePreconfiguredWaf('${rule.value[0]}')"
        }
      }
    }
  }

  rule {
    action      = "allow"
    priority    = 2147483647
    description = "Default allow after WAF evaluation"

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}

resource "google_compute_url_map" "application" {
  project         = var.project_id
  name            = "${local.name}-routes"
  default_service = google_compute_backend_service.application.id
}

resource "google_compute_target_http_proxy" "application" {
  project = var.project_id
  name    = "${local.name}-http"
  url_map = google_compute_url_map.application.id
}

resource "google_compute_global_address" "application" {
  project      = var.project_id
  name         = "${local.name}-ip"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

resource "google_compute_global_forwarding_rule" "http" {
  project               = var.project_id
  name                  = "${local.name}-http"
  ip_address            = google_compute_global_address.application.id
  target                = google_compute_target_http_proxy.application.id
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  network_tier          = "PREMIUM"
}

resource "google_compute_managed_ssl_certificate" "application" {
  count   = length(var.domain_names) == 0 ? 0 : 1
  project = var.project_id
  name    = "${local.name}-tls"

  managed {
    domains = var.domain_names
  }
}

resource "google_compute_target_https_proxy" "application" {
  count            = length(var.domain_names) == 0 ? 0 : 1
  project          = var.project_id
  name             = "${local.name}-https"
  url_map          = google_compute_url_map.application.id
  ssl_certificates = [google_compute_managed_ssl_certificate.application[0].id]
}

resource "google_compute_global_forwarding_rule" "https" {
  count                 = length(var.domain_names) == 0 ? 0 : 1
  project               = var.project_id
  name                  = "${local.name}-https"
  ip_address            = google_compute_global_address.application.id
  target                = google_compute_target_https_proxy.application[0].id
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  network_tier          = "PREMIUM"
}
