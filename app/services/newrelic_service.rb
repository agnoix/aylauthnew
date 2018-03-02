module NewrelicService

  API_KEY = Aylauth::Settings.newrelic_config[:api_key] rescue ""

  class << self

    def applications(name=nil)
      url = "https://api.newrelic.com/v2/applications.json"
      options = { headers: {"X-Api-Key" => API_KEY} }
      response = Aylauth::ExternalService.call_external_service(url, options)["applications"] rescue nil
      return nil if response.blank?
      applications = []
      response.each { |app| applications << OpenStruct.new(app) }
      return applications.select { |app| app.name == name }.first unless name.blank?
      applications
    end
    
  end
end
