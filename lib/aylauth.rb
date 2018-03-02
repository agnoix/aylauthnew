require "aylauth/version"
require "aylauth/pii_removal"
require "aylauth/external_service"
require "aylauth/configurable"
require "aylauth/settings"
require "aylauth/cache"
require "aylauth/support"
require "aylauth/actions"
require "aylauth/providers/providers"
require "aylauth/helpers"
require "aylauth/view_helpers"
require "active_support/dependencies"

require 'json'
require 'json/add/core'

module Aylauth

  mattr_accessor  :app_root

  class << self
    include Aylauth::Configurable

    def setup
      yield self
    end

  end
end

if defined?(Rails)
  require "aylauth/engine.rb"
  require "aylauth/railtie"
end

