# ─── Cloud Monitoring & Alerts ──────────────────────────
# All configured via Terraform — no manual console clicks
# Two notification channels: Google Chat (warning) + Email (critical)

# ── Notification Channels ───────────────────────────────

resource "google_monitoring_notification_channel" "email" {
  display_name = "Email Alert Channel"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }
}

resource "google_monitoring_notification_channel" "google_chat" {
  display_name = "Google Chat Warning Channel"
  type         = "webhook_tokenauth"

  labels = {
    url = var.google_chat_webhook
  }
}

# ── Log-Based Metric: CPU Utilization ───────────────────
# Cloud Run emits CPU metrics to Cloud Monitoring automatically
# We create alert policies on top of the built-in metrics

# Alert 1: CPU > 70% → Google Chat WARNING
resource "google_monitoring_alert_policy" "cpu_warning" {
  display_name = "Cloud Run CPU Warning (>70%)"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "CPU utilization above 70%"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloud_run_revision"
        AND resource.labels.service_name = "${google_cloud_run_v2_service.app.name}"
        AND metric.type = "run.googleapis.com/container/cpu/utilizations"
      EOT

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_99"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.service_name"]
      }

      comparison      = "COMPARISON_GT"
      threshold_value = 0.70
      duration        = "60s"   # must stay above 70% for 60s before alerting
    }
  }

  notification_channels = [google_monitoring_notification_channel.google_chat.id]

  alert_strategy {
    auto_close = "1800s"   # auto-close alert after 30 min if resolved
  }

  documentation {
    content   = "CPU utilization exceeded 70% on Cloud Run service ${google_cloud_run_v2_service.app.name}. This is a WARNING — monitor closely. If it exceeds 80%, an email alert will fire."
    mime_type = "text/markdown"
  }
}

# Alert 2: CPU > 80% sustained → Email CRITICAL
resource "google_monitoring_alert_policy" "cpu_critical" {
  display_name = "Cloud Run CPU Critical (>80%)"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "CPU utilization above 80% sustained"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloud_run_revision"
        AND resource.labels.service_name = "${google_cloud_run_v2_service.app.name}"
        AND metric.type = "run.googleapis.com/container/cpu/utilizations"
      EOT

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_99"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.service_name"]
      }

      comparison      = "COMPARISON_GT"
      threshold_value = 0.80
      duration        = "300s"  # sustained above 80% for 5 min = critical
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  alert_strategy {
    auto_close = "3600s"
  }

  documentation {
    content   = "CRITICAL: CPU utilization exceeded 80% for 5+ minutes on ${google_cloud_run_v2_service.app.name}. Immediate action required — consider scaling or investigating traffic spike."
    mime_type = "text/markdown"
  }
}

# Alert 3: Memory > 70% → Google Chat WARNING
resource "google_monitoring_alert_policy" "memory_warning" {
  display_name = "Cloud Run Memory Warning (>70%)"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Memory utilization above 70%"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloud_run_revision"
        AND resource.labels.service_name = "${google_cloud_run_v2_service.app.name}"
        AND metric.type = "run.googleapis.com/container/memory/utilizations"
      EOT

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_99"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.service_name"]
      }

      comparison      = "COMPARISON_GT"
      threshold_value = 0.70
      duration        = "60s"
    }
  }

  notification_channels = [google_monitoring_notification_channel.google_chat.id]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "Memory utilization exceeded 70% on ${google_cloud_run_v2_service.app.name}. WARNING — watch for memory leaks or traffic spikes."
    mime_type = "text/markdown"
  }
}

# Alert 4: Memory > 80% sustained → Email CRITICAL
resource "google_monitoring_alert_policy" "memory_critical" {
  display_name = "Cloud Run Memory Critical (>80%)"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Memory utilization above 80% sustained"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloud_run_revision"
        AND resource.labels.service_name = "${google_cloud_run_v2_service.app.name}"
        AND metric.type = "run.googleapis.com/container/memory/utilizations"
      EOT

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_99"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.service_name"]
      }

      comparison      = "COMPARISON_GT"
      threshold_value = 0.80
      duration        = "300s"
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  alert_strategy {
    auto_close = "3600s"
  }

  documentation {
    content   = "CRITICAL: Memory utilization exceeded 80% for 5+ minutes on ${google_cloud_run_v2_service.app.name}. Check for memory leaks — container may OOM soon."
    mime_type = "text/markdown"
  }
}

# ── Log-Based Metric: Application Errors ────────────────
# Counts ERROR level logs from your Node.js app
resource "google_logging_metric" "app_errors" {
  name   = "assessment-app-errors"
  filter = <<-EOT
    resource.type="cloud_run_revision"
    AND resource.labels.service_name="${google_cloud_run_v2_service.app.name}"
    AND severity>=ERROR
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
    display_name = "Application Error Count"
  }
}

# Alert on application errors
resource "google_monitoring_alert_policy" "app_errors" {
  display_name = "Application Error Rate Alert"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Error log count > 10 in 5 minutes"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloud_run_revision"
        AND metric.type = "logging.googleapis.com/user/${google_logging_metric.app_errors.name}"
      EOT

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = 10
      duration        = "0s"
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.email.id,
    google_monitoring_notification_channel.google_chat.id
  ]

  documentation {
    content   = "More than 10 application errors in 5 minutes on ${google_cloud_run_v2_service.app.name}. Check Cloud Logging for details."
    mime_type = "text/markdown"
  }
}
