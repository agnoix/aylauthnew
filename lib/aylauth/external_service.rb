require 'typhoeus'
require 'json'

module Aylauth
  module ExternalService
    include Aylauth::PiiRemoval
    extend self

    # Public: Call an external service and return the JSON value in Hash.
    #
    # url - A String representing the url to call.
    # options - A hash with additional options:
    #     body - A Hash with the body to send.
    #     headers - A Hash with the header to send. The default header is "Content-Type" => "application/json".
    #     method - A Symbol representing the http method (:get or :post). Default is :get
    #     return_err_value - The value to return in case of error. Default nil.
    #     process_json - A Boolean indicating if the result should be returned as a processed json.
    #     on_error -   A Lambda that will be executed if there is an error with the request.
    #                  This lambda receives the error code and the response string.
    #     on_success - A Lambda that will be executed if the request is ok.
    #                  This lambda receives the status code and the response string.
    #                  Example: on_success: lambda{|code,body| do_something(body) if code == 20 }
    #
    # Examples
    #   Aylauth::ExternalService.call_external_service("http://localhost")
    #
    # Returns a Hash with the response
    def get_service_token
      cache_key = Settings.cache_key
      # Store service_token in Aylauth cache

      Aylauth::Cache.fetch("#{cache_key}/service_token", expires_in: eval(Settings.service_token_ttl)) do
        targetUrl = "#{Aylauth::Settings.user_service_base_url}/admin/users/service_token_by_email.json?email=#{Settings.aylaservice_email}&password=#{Settings.aylaservice_pwd}"
        response = Typhoeus.get(targetUrl)
        if response.code >= 200 && response.code <= 300
          JSON.parse response.body.to_s
        else
          logger.error "Failed to retrieve service token from Userservice"
          {}
        end
      end
    end
    
    def call_external_service(url, options = {})

      default_options = { headers: {"Content-Type" => "application/json",
                                   "Ayla-Client"  => Aylauth::Settings.application_id},
                                    method: :get,
                           process_json: true,
                           on_error: Proc.new { |code, body| logger.error "ERROR: code: #{code} - #{body}"; nil }
                         }
       opts = default_options.merge(options)
       process_external_service_call(url,opts)                
    end 
    
    def call_external_service_with_service_token(url, options = {})
      token = get_service_token
      token_val = token["service_token"] unless token.empty?

      default_options = { headers: {"Content-Type" => "application/json",
                                    "Ayla-Client"  => Aylauth::Settings.application_id, 
                                    "Authorization" => "auth_token #{token_val}" },
                          method: :get,
                          process_json: true,
                          on_error: Proc.new { |code, body| logger.error "ERROR: code: #{code} - #{body}"; nil }
                        }
      opts = default_options.merge(options)
      process_external_service_call(url,opts)
    end

    def process_external_service_call(url,options = {})
      
      request = nil
      process_service_call(options[:return_value]) do
        request = Typhoeus::Request.new(url,
                                        body: options[:body],
                                        method: options[:method],
                                        params: options[:query],
                                        headers: options[:headers])
        logger.debug "[Aylauth] Request for #{url}: #{request.options}"
        #Run with Hydra
        hydra = Typhoeus::Hydra.new
        hydra.queue(request)
        hydra.run
      end
      response = request.response
      logger.debug "[Aylauth] Response from #{options[:method].upcase} #{url}: #{PiiHashFilter.predefined.filter(JSON.parse(response.body)) rescue ""}(code: #{response.code})"

      if response.success?
        ret_response = response.body.length >= 2 ? JSON.parse(response.body) : {"code" => response.code}
        add_status_to_object(ret_response, options[:on_success], response.code) if options[:on_success]

      elsif response.code == 0 || response.code == "0"
        logger.error "[Aylauth] Error 0: #{response.return_message}"
        ret_response = nil
        add_status_to_object(ret_response, options[:on_error], response.code) if options[:on_error]

      else
        ret_response = options[:return_err_value]
        ret_response ||= response.body.length >= 2 ? JSON.parse(response.body) : {"code" => response.code}
        add_status_to_object(ret_response, options[:on_error], response.code) if options[:on_error]
      end

      ret_response
    end

    def process_service_call(options={})
      begin
        yield
      rescue => exception
        backtrace = exception.backtrace.join('\n') if exception.backtrace
        logger.error "[Aylauth] #{exception.class}: #{exception.message}\n#{backtrace}"

        if options.nil? || options[:return_value].nil?
          return { :errors => "#{exception.class}: #{exception.message}.\n#{backtrace}" }
        else
          return options[:return_value]
        end
      end
    end

    def logger
      Aylauth.logger
    end

    def add_status_to_object(object, method, *params)
      response = method.call(*params, object) if method.respond_to? :call
      object.instance_eval <<EOS
        class << self
          self.send :define_method, :status do
            return #{response}
          end
        end
EOS
    end

  end
end
