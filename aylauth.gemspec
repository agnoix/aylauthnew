# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "aylauth"
  s.version = "0.4.13"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Ayla Networks", "Sergio Rafael Gianazza"]
  s.date = "2017-04-14"
  s.description = "This gem include every file necessary to use your application with userService"
  s.email = ["sergio@aylanetworks.com"]
  s.files = [".gitignore", ".rspec", "Gemfile", "LICENSE", "README.md", "Rakefile", "app/controllers/aylauth/confirmations_controller.rb", "app/controllers/aylauth/notifications_controller.rb", "app/controllers/aylauth/passwords_controller.rb", "app/controllers/aylauth/registrations_controller.rb", "app/controllers/aylauth/sessions_controller.rb", "app/services/desk_dot_com_service.rb", "app/services/newrelic_service.rb", "app/views/aylauth/confirmations/new.html.erb", "app/views/aylauth/passwords/edit.html.erb", "app/views/aylauth/passwords/new.html.erb", "app/views/aylauth/registrations/edit.html.erb", "app/views/aylauth/registrations/new.html.erb", "app/views/aylauth/registrations/show.html.erb", "app/views/aylauth/sessions/_links.html.erb", "app/views/aylauth/sessions/accept_terms.html.erb", "app/views/aylauth/sessions/new.html.erb", "aylauth.gemspec", "config/Settings.yml", "config/environment.rb", "config/routes.rb", "lib/aylauth.rb", "lib/aylauth/actions.rb", "lib/aylauth/cache.rb", "lib/aylauth/configurable.rb", "lib/aylauth/device.rb", "lib/aylauth/engine.rb", "lib/aylauth/external_service.rb", "lib/aylauth/helpers.rb", "lib/aylauth/oem.rb", "lib/aylauth/pii_removal.rb", "lib/aylauth/providers/facebook_provider.rb", "lib/aylauth/providers/google_provider.rb", "lib/aylauth/providers/helpers.rb", "lib/aylauth/providers/nil_provider.rb", "lib/aylauth/providers/provider_resolver.rb", "lib/aylauth/providers/providers.rb", "lib/aylauth/providers/wechat_provider.rb", "lib/aylauth/railtie.rb", "lib/aylauth/settings.rb", "lib/aylauth/support.rb", "lib/aylauth/user.rb", "lib/aylauth/user_data.rb", "lib/aylauth/version.rb", "lib/aylauth/view_helpers.rb", "spec/actions_spec.rb", "spec/cache_spec.rb", "spec/fixtures/auth_user_expiry_time_nil.json", "spec/fixtures/auth_user_expiry_time_not_string.json", "spec/fixtures/auth_user_fully_parseable.json", "spec/spec_helper.rb", "spec/support_spec.rb", "test/lib/aylauth/configurable_test.rb", "test/lib/aylauth/providers/provider_resolver_test.rb", "test/lib/aylauth/support_test.rb", "test/test_helper.rb"]
  s.homepage = "http://www.aylanetworks.com"
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.23"
  s.summary = "Ayla Networks Authentication Gem"
  s.test_files = ["spec/actions_spec.rb", "spec/cache_spec.rb", "spec/fixtures/auth_user_expiry_time_nil.json", "spec/fixtures/auth_user_expiry_time_not_string.json", "spec/fixtures/auth_user_fully_parseable.json", "spec/spec_helper.rb", "spec/support_spec.rb", "test/lib/aylauth/configurable_test.rb", "test/lib/aylauth/providers/provider_resolver_test.rb", "test/lib/aylauth/support_test.rb", "test/test_helper.rb"]

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<typhoeus>, ["~> 1.1.2"])
      s.add_runtime_dependency(%q<activemodel>, ["~> 3.2.11"])
      s.add_runtime_dependency(%q<activesupport>, ["~> 3.2.11"])
      s.add_runtime_dependency(%q<settingslogic>, ["~> 2.0.9"])
      s.add_runtime_dependency(%q<aws-sdk>, ["~> 1.63.0"])
      s.add_runtime_dependency(%q<json>, ["~> 1.8.6"])
      s.add_runtime_dependency(%q<dalli>, ["~> 2.7.6"])
      s.add_runtime_dependency(%q<dalli-elasticache>, ["~> 0.2.0"])
      s.add_development_dependency(%q<minitest>, ["~> 2.5.1"])
      s.add_development_dependency(%q<rake>, ["~> 10.0.3"])
      s.add_development_dependency(%q<padrino>, ["~> 0.10.7"])
      s.add_development_dependency(%q<mocha>, ["~> 0.14.0"])
      s.add_development_dependency(%q<rspec>, ["~> 3.1.0"])
    else
      s.add_dependency(%q<typhoeus>, ["~> 1.1.2"])
      s.add_dependency(%q<activemodel>, ["~> 3.2.11"])
      s.add_dependency(%q<activesupport>, ["~> 3.2.11"])
      s.add_dependency(%q<settingslogic>, ["~> 2.0.9"])
      s.add_dependency(%q<aws-sdk>, ["~> 1.63.0"])
      s.add_dependency(%q<json>, ["~> 1.8.6"])
      s.add_dependency(%q<dalli>, ["~> 2.7.6"])
      s.add_dependency(%q<dalli-elasticache>, ["~> 0.2.0"])
      s.add_dependency(%q<minitest>, ["~> 2.5.1"])
      s.add_dependency(%q<rake>, ["~> 10.0.3"])
      s.add_dependency(%q<padrino>, ["~> 0.10.7"])
      s.add_dependency(%q<mocha>, ["~> 0.14.0"])
      s.add_dependency(%q<rspec>, ["~> 3.1.0"])
    end
  else
    s.add_dependency(%q<typhoeus>, ["~> 1.1.2"])
    s.add_dependency(%q<activemodel>, ["~> 3.2.11"])
    s.add_dependency(%q<activesupport>, ["~> 3.2.11"])
    s.add_dependency(%q<settingslogic>, ["~> 2.0.9"])
    s.add_dependency(%q<aws-sdk>, ["~> 1.63.0"])
    s.add_dependency(%q<json>, ["~> 1.8.6"])
    s.add_dependency(%q<dalli>, ["~> 2.7.6"])
    s.add_dependency(%q<dalli-elasticache>, ["~> 0.2.0"])
    s.add_dependency(%q<minitest>, ["~> 2.5.1"])
    s.add_dependency(%q<rake>, ["~> 10.0.3"])
    s.add_dependency(%q<padrino>, ["~> 0.10.7"])
    s.add_dependency(%q<mocha>, ["~> 0.14.0"])
    s.add_dependency(%q<rspec>, ["~> 3.1.0"])
  end
end
