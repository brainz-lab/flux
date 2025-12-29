# frozen_string_literal: true

# Flux - Custom Metrics & Events Platform
# Sends telemetry to other Brainz Lab services for cross-service monitoring
# Uses direct database inserts for its own metrics/events (avoids HTTP loops)
#
# Set BRAINZLAB_SDK_ENABLED=false to disable SDK initialization
# Useful for running migrations before SDK is ready

# Skip during asset precompilation or when explicitly disabled
return if ENV["BRAINZLAB_SDK_ENABLED"] == "false"
return if ENV["SECRET_KEY_BASE_DUMMY"].present?

BrainzLab.configure do |config|
  # App name for auto-provisioning projects
  config.app_name = "flux"

  # Enable Recall logging (send logs to Recall)
  config.recall_enabled = ENV.fetch("RECALL_ENABLED", "true") == "true"
  config.recall_url = ENV.fetch("RECALL_URL", "http://recall:3000")
  config.recall_master_key = ENV["RECALL_MASTER_KEY"]
  config.recall_min_level = Rails.env.production? ? :info : :debug

  # Enable Reflex error tracking (send errors to Reflex)
  config.reflex_enabled = ENV.fetch("REFLEX_ENABLED", "true") == "true"
  config.reflex_url = ENV.fetch("REFLEX_URL", "http://reflex:3000")
  config.reflex_master_key = ENV["REFLEX_MASTER_KEY"]

  # Enable Pulse APM (send traces with spans to Pulse)
  config.pulse_enabled = ENV.fetch("PULSE_ENABLED", "true") == "true"
  config.pulse_url = ENV.fetch("PULSE_URL", "http://pulse:3000")
  config.pulse_master_key = ENV["PULSE_MASTER_KEY"]
  config.pulse_buffer_size = 10 if Rails.env.development?  # Batch traces to reduce HTTP calls

  # Disable Flux SDK (we use direct DB inserts for self-tracking metrics/events)
  config.flux_enabled = false

  # Buffer settings for development
  config.recall_buffer_size = 1 if Rails.env.development?  # Send logs immediately in dev

  # Exclude common Rails exceptions
  config.reflex_excluded_exceptions = [
    "ActionController::RoutingError",
    "ActionController::InvalidAuthenticityToken",
    "ActionController::UnknownFormat"
  ]

  # Service identification
  config.service = "flux"
  config.environment = Rails.env

  # Ignore internal BrainzLab hosts to prevent infinite recursion
  config.http_ignore_hosts = %w[localhost 127.0.0.1 recall reflex pulse signal flux]
end

Rails.application.config.after_initialize do
  # Skip if running migrations or if tables don't exist yet
  next unless ActiveRecord::Base.connection.table_exists?(:projects) rescue false

  # Provision projects in other services (auto-creates project in each service)
  BrainzLab::Recall.ensure_provisioned! if BrainzLab.configuration.recall_enabled
  BrainzLab::Reflex.ensure_provisioned! if BrainzLab.configuration.reflex_enabled
  BrainzLab::Pulse.ensure_provisioned! if BrainzLab.configuration.pulse_enabled

  Rails.logger.info "[Flux] SDK initialized"
  Rails.logger.info "[Flux] Recall logging: #{BrainzLab.configuration.recall_enabled ? 'enabled' : 'disabled'}"
  Rails.logger.info "[Flux] Reflex error tracking: #{BrainzLab.configuration.reflex_enabled ? 'enabled' : 'disabled'}"
  Rails.logger.info "[Flux] Pulse APM: #{BrainzLab.configuration.pulse_enabled ? 'enabled' : 'disabled'}"
end
