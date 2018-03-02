if defined?(Rails)
  module Aylauth
    class Railtie < Rails::Railtie
      initializer "Aylauth.action_controller" do
        ActiveSupport.on_load(:action_controller) do
          puts "Extending #{self} with Aylauth::Support"
          include Aylauth::Support
          helper_method "current_user", "user_signed_in?", "userservice_admin_path"
        end
      end

      initializer "Aylauth.view_helpers" do
        ActionView::Base.send :include, ViewHelpers
      end

      initializer 'Rails logger' do
        Aylauth.logger = Rails.logger.dup
      end

      initializer "Load settings" do
        require 'settingslogic'
        require_relative 'settings'
      end
    end
  end
end
