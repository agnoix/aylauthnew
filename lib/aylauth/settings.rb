require 'settingslogic'
require 'active_support/core_ext/numeric'

module Aylauth
  class Settings < Settingslogic
    if defined? Rails
      source "config/ayla_auth.yml" # We don't use Rails.root because it is not loaded at this point
      namespace Rails.env
      suppress_errors Rails.env.production?
    elsif defined? Padrino
      source "#{Padrino.root}/config/ayla_auth.yml"
      namespace Padrino.env.to_s
      suppress_errors Padrino.env == :production
    else

    end

    DEFAULT_CACHE_VALIDITY = 1.day
    DEFAULT_CACHE_TTL      = 10

    def user_service_base_url
      self.user_service_url
    end

    def user_service_user_url
      self.user_service_url + "/users"
    end

    def user_service_oem_url
      self.user_service_url + "/oems"
    end

    def user_service_admin_user_url
      self.user_service_url + "/admin/users"
    end

    def device_service_base_url
      self.device_service_url
    end

    def device_service_device_url
      self.device_service_url + "/devices/"
    end

    def validity
      self.cache_validity.to_i rescue DEFAULT_CACHE_VALIDITY
    end

    def ttl
      self.cache_ttl.to_i rescue DEFAULT_CACHE_TTL
    end

    def ayla_oem_id_str
      self.ayla_oem_id
    end

    def newrelic_config
      self.newrelic
    end
  end
end
