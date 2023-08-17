resource "google_storage_bucket" "gdpr-verification" {
  name                        = "${var.GCP_PROJECT}-gdpr-verification"
  project                     = var.GCP_PROJECT
  location                    = "US"
  force_destroy               = true
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true

  cors {
    origin = ["https://tcfv2.sojern.com"]
    method = ["GET"]
    response_header = [
      "Content_Type: application/json",
      "Access-Control-Allow-Origin: *",
      "Access-Control-Allow-Credentials: false",
    ]
    max_age_seconds = 3600
  }

  lifecycle {
    prevent_destroy = false
  }

  versioning {
    enabled = true
  }
}

resource "google_storage_bucket_iam_member" "pod-dice" {
  bucket = google_storage_bucket.gdpr-verification.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}


resource "google_compute_backend_bucket" "gdpr_backend_bucket" {
  name        = "gdpr-backend-bucket"
  bucket_name = google_storage_bucket.gdpr-verification.name
  enable_cdn  = false
  custom_response_headers = [
    "Content_Type: application/json",
    "Access-Control-Allow-Origin: *",
    "Access-Control-Allow-Credentials: false",
  ]
}

resource "google_compute_global_address" "gdpr-compute-addr" {
  name    = "gdpr-compute-addr"
  project = var.GCP_PROJECT
}

resource "google_dns_record_set" "gdpr-set" {
  name         = "tcfv2.sojern.com."
  type         = "A"
  ttl          = 600
  managed_zone = "sojern-com"
  project      = "sojern-platform"
  rrdatas      = [google_compute_global_address.gdpr-compute-addr.address]
}

resource "google_compute_managed_ssl_certificate" "gdpr-ssl-cert" {
  name = "gdpr-ssl-cert"
  managed {
    domains = ["tcfv2.sojern.com."]
  }
}

resource "google_compute_url_map" "gdpr-url-map" {
  name            = "gdpr-url-map"
  default_service = google_compute_backend_bucket.gdpr_backend_bucket.id
}

resource "google_compute_target_https_proxy" "gdpr-proxy" {
  name             = "gdpr-proxy"
  url_map          = google_compute_url_map.gdpr-url-map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.gdpr-ssl-cert.id]
  ssl_policy       = google_compute_ssl_policy.pci-ssl-policy.name
}

resource "google_compute_global_forwarding_rule" "gdpr-verification" {
  name                  = "gdpr-verification-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_target_https_proxy.gdpr-proxy.id
  ip_address            = google_compute_global_address.gdpr-compute-addr.id
  port_range            = "443"
}
