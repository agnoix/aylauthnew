module Aylauth
  module Actions
    require 'base64'

    include ExternalService
    include Aylauth::Cache
    include Aylauth::PiiRemoval
    extend self

    def find_oems_by_user_email(user_email)
      return nil if user_email.blank?
      response = call_external_service_with_service_token(Aylauth::Settings.user_service_base_url + "/api/v1/public/users/oems/find_by_email.json?email=#{user_email}")
      oems = []
      response.each { |oem| oems << Aylauth::Oem.new(oem) } unless response.blank? || (response.is_a?(Hash) && response["code"] != 200)
      return oems
    end

    def sign_in_user(username, password, oem_id = nil, app_name = nil)
      body = {:user => {:email => username, :password => password,
                        :application => {:app_id => Aylauth::Settings.application_id,
                                         :app_secret => Aylauth::Settings.application_secret,
                                         :oem_id => oem_id,
                                         :app_name => app_name }}}

      on_success = Proc.new { |code, body| [ body["access_token"], body["refresh_token"] ] }
      options = { :headers => {"Content-Type" => "application/json"},
                  :body => body.to_json,
                  method: :post,
                  return_err_value: nil,
                  on_success: on_success
                }
      response = call_external_service(Aylauth::Settings.user_service_user_url + "/sign_in.json?", options)
      if response["error"] == "Your account is locked."
        return response["error"]
      end
      return response.status
    end

    def sign_out_user(auth_token)
      body = {:user => {:access_token => auth_token } }
      options = { :headers => {"Content-Type" => "application/json"},
                  :body => body.to_json,
                  method: :post,
                  return_err_value: false }

      response = call_external_service(Aylauth::Settings.user_service_user_url + "/sign_out.json?", options)

      if response["logout"] == "true"
        destroy_access_token(auth_token)
        return true
      end
    end

    def get_user_from_header(auth_user)
      return nil unless !!auth_user

      begin
        decoded_auth_user = Base64.decode64(auth_user)
        authorization = JSON.parse decoded_auth_user
      rescue => exception
        Rails.logger.error "[Aylauth] Submitted auth user #{auth_user} is invalid"  # WARNING: valid auth_user contains PII
        return nil
      end

      return nil if authorization.nil? || authorization['error'] || authorization['expiry_time'].nil? || !(authorization['expiry_time'].is_a? String)
      #logger.debug "Authorization: #{authorization}"

      token_expiry_time = Time.parse(authorization['expiry_time']).utc
      logger.debug "[Aylauth] Token expiry time: #{token_expiry_time}"

      if token_expiry_time.nil? || token_expiry_time <= Time.now.utc
        return nil
      else
        user = ::Aylauth::User.new(authorization)
        logger.info "[Aylauth] Authorized User uuid: #{user.uuid}"
        user
      end
    end

    def get_user_data(auth_header)
      #logger.debug "Header: #{auth_header}"
      auth_token = extract_token(auth_header)
      authorization = fetch_auth_from_user_service(auth_token)

      return if authorization.nil? || authorization["error"]
      #logger.debug "Authorization: #{authorization}"

      token_expiry_time = authorization["expiry_time"]
      token_expiry_time = Time.parse(token_expiry_time).utc if token_expiry_time.is_a? String
      logger.debug "[Aylauth] Token expiry time: #{token_expiry_time}"

      if token_expiry_time.nil? || token_expiry_time <= Time.now.utc
        logger.debug "[Aylauth] Expired token: #{auth_token}"
        Aylauth::Cache.delete(auth_token)
        Aylauth::Cache.expire("auth_token", auth_token)
        logger.debug "[Aylauth] Expired token #{Aylauth::Cache.exist?(auth_token)}"
        false
      else
        logger.debug "[Aylauth] Authorization: #{PiiHashFilter.predefined.filter(authorization)}"
        user = ::Aylauth::User.new(authorization)
        logger.debug "[Aylauth] User #{user.uuid}"
        user.auth_token = auth_token
        logger.info "[Aylauth] Authorized User uuid: #{user.uuid}"
        user
      end
    end

    def get_user_data_by_auth_token(auth_token)
      call_external_service(Aylauth::Settings.user_service_user_url + "/get_user_data.json?",
                            {return_value: nil,
                            :body => wrap_with_json(auth_token)})
    end
    #cache :get_user_data_by_auth_token, expires_in: Aylauth::Settings.cache_ttl, expires_by: :auth_token

    def get_user_data_by_id(auth_token, id)
      call_external_service(Aylauth::Settings.user_service_user_url + "/#{id}.json?",
                            {return_value: nil,
                            :body => wrap_with_json(auth_token)})
    end
    #cache :get_user_data_by_id, expires_in: Aylauth::Settings.cache_ttl, expires_by: :auth_token

    def get_user_datum_by_auth_token(auth_token)
      body = { :auth_token => auth_token}
      options = { body: body.to_json,
                  method: :get,
                  return_err_value: nil}
      call_external_service(Aylauth::Settings.user_service_base_url + "/api/v1/users/data.json?", options)
    end
    #cache :get_user_datum_by_auth_token, expires_in: Aylauth::Settings.cache_ttl, expires_by: :auth_token

    def get_user_datum_by_id(auth_token, id)
      body = { :auth_token => auth_token}
      options = { body: body.to_json,
                  method: :get,
                  return_err_value: nil}
      call_external_service(Aylauth::Settings.user_service_base_url + "/api/v1/users/#{id}/data.json?", options)
    end

    def destroy_user_datum_by_key(auth_token, key)
        body = { :auth_token => auth_token}

        options = { body: body.to_json,
                    method: :delete,
                    return_err_value: nil}
        call_external_service(Aylauth::Settings.user_service_base_url + "/api/v1/users/data/#{key}", options)
    end

    def create_user(user_data)
      body = { :user  => ActiveSupport::JSON.decode(user_data.to_json).merge(:application => {:app_id => Aylauth::Settings.application_id, :app_secret => Aylauth::Settings.application_secret }) }
      on_success = Proc.new { |code, body| { created: true } }
      on_error   = Proc.new do |code, body|
        logger.info "======= ON ERROR: #{body}"
          body
      end
      options = { body: body.to_json,
                  method: :post,
                  return_err_value: nil,
                  on_success: on_success,
                  on_error: on_error }
      response = call_external_service(Aylauth::Settings.user_service_user_url + ".json?", options)

      logger.debug "[Aylauth] [Create User Data] Response from User Service: #{response.status}"
      response.status
    end

    def admin_create_user(auth_token, user_data, oem_user = false)
      body = { auth_token: auth_token,
               :user  => ActiveSupport::JSON.decode(user_data.to_json).merge(:application => {:app_id => Aylauth::Settings.application_id, :app_secret => Aylauth::Settings.application_secret}) }
      on_success = Proc.new { |code, body| { created: true } }
      on_error   = Proc.new do |code, body|
        logger.info "======= ON ERROR: #{body}"
          body
      end
      options = { body: body.to_json,
                  headers: {"Content-Type" => "application/json"},
                  method: :post,
                  return_err_value: nil,
                  on_success: on_success,
                  on_error: on_error }
      url = oem_user ? Aylauth::Settings.user_service_oem_url + "/create_oem_user" : Aylauth::Settings.user_service_admin_user_url
      response = call_external_service(url + ".json", options)

      logger.debug "[Aylauth] [Create User Data] Response from User Service: #{response.status}"
      response = ActiveSupport::JSON.decode(response.to_json)
      return response
    end

    def admin_create_end_user(auth_token, user_data)
      app_id = user_data.app_id rescue Aylauth::Settings.application_id
      app_secret = user_data.app_secret rescue Aylauth::Settings.application_secret
      body = { auth_token: auth_token,
               :user  => ActiveSupport::JSON.decode(user_data.to_json).merge(:application => {:app_id => app_id, :app_secret => app_secret}) }
      on_success = Proc.new { |code, body| { created: true } }
      on_error   = Proc.new do |code, body|
        logger.info "======= ON ERROR: #{body}"
          body
      end
      options = { body: body.to_json,
                  headers: {"Content-Type" => "application/json"},
                  method: :post,
                  return_err_value: nil,
                  on_success: on_success,
                  on_error: on_error }
      response = call_external_service(Aylauth::Settings.user_service_admin_user_url + "/create_end_user.json", options)

      logger.debug "[Aylauth] [Create End User Data] Response from User Service: #{response.status}"
      response = ActiveSupport::JSON.decode(response.to_json)
      return response
    end

    def send_reset_password(user_data, origin_oem_id=nil, include_application=true, oem_id=nil, app_name=nil)
      if include_application then
        body = { :user => { :email => user_data.email, :origin_oem_id => origin_oem_id,
                            :application => { :app_id => Aylauth::Settings.application_id,
                                              :app_secret => Aylauth::Settings.application_secret,
                                              :oem_id => oem_id,
                                              :app_name => app_name } } }
      else
        body = { :user => { :email => user_data.email } }
      end

      on_success = Proc.new { |code, body| { reset_password: true } }
      on_error   = Proc.new { |code, body| body }
      options = { body: body.to_json,
                  method: :post,
                  return_err_value: nil,
                  on_success: on_success,
                  on_error: on_error }
      response = call_external_service(Aylauth::Settings.user_service_user_url + "/password.json?", options)
      logger.debug "[Aylauth] [Send Reset Password] Response from User Service: #{response}"

      response.status
    end

    def reset_password(user_data)
      body = {:user => {:reset_password_token => user_data.reset_password_token,
                        :password => user_data.password,
                        :password_confirmation => user_data.password_confirmation}}
      on_success = Proc.new { |code, body| { reset_password: true } }
      on_error   = Proc.new { |code, body| body }
      options = { body: body.to_json,
                  method: :put,
                  return_err_value: nil,
                  on_success: on_success,
                  on_error: on_error }

      response = call_external_service(Aylauth::Settings.user_service_user_url + "/password.json?", options)
      logger.debug "[Aylauth] [Reset Password] Response from User Service: #{response}"
      response.status
    end

    def resend_confirmation(user_data, origin_oem_id=nil, include_application=true)
      if include_application then
        body = { :user => { :email => user_data.email, :origin_oem_id => origin_oem_id,
                            :application => { :app_id => Aylauth::Settings.application_id,
                                              :app_secret => Aylauth::Settings.application_secret } } }
      else
        body = { :user => { :email => user_data.email } }
      end

      on_success = Proc.new { |code, body| { confirmation_sent: true } }
      on_error   = Proc.new { |code, body| body }
      options = { body: body.to_json,
                  method: :post,
                  return_err_value: nil,
                  on_success: on_success,
                  on_error: on_error }
      response = call_external_service(Aylauth::Settings.user_service_user_url + "/confirmation.json?", options)
      logger.debug "[Aylauth] [Resend confirmation] Response from User Service: #{response}"
      response.status
    end

    def update_user_data(auth_token, user_data)
      #TODO: We need to change the auth_token in user for the auth_token in access_grant. better way?
      body = {:auth_token => auth_token, :user => user_data}
      on_success = Proc.new { |code, body| body }
      on_error   = Proc.new { |code, body| body }
      options = { body: body.to_json,
                  method: :put,
                  return_err_value: nil }
      response = call_external_service(Aylauth::Settings.user_service_user_url + ".json?", options)
      logger.debug "[Aylauth] [Update User Data] Response from User Service: #{response}"
      response
    end

    def admin_update_user_data(auth_token, user_data, user_id)
      body = { :auth_token => auth_token, :user  => ActiveSupport::JSON.decode(user_data.to_json).merge(:application => {:app_id => Aylauth::Settings.application_id, :app_secret => Aylauth::Settings.application_secret}) }
      on_success = Proc.new { |code, body| { created: true } }
      on_error   = Proc.new do |code, body|
        logger.info "======= ON ERROR: #{body}"
        body
      end
      options = { body: body.to_json,
                  headers: {"Content-Type" => "application/json"},
                  method: :put,
                  return_err_value: nil,
                  on_success: on_success,
                  on_error: on_error }
      response = call_external_service(Aylauth::Settings.user_service_admin_user_url + "/#{user_id}.json", options)

      logger.debug "[Aylauth] [Update User Data] Response from User Service: #{response}"
      response = ActiveSupport::JSON.decode(response.to_json)
      return response
    end

    def destroy_user(auth_token, user_data)
      #TODO: We need to change the auth_token in user for the auth_token in access_Grant. better way?
      body = {:auth_token => auth_token, :id => user_data.id, :user => user_data}
      options = { body: body.to_json,
                  method: :delete,
                  return_err_value: nil }
      response = call_external_service(Aylauth::Settings.user_service_user_url + ".json?", options)
      logger.debug "[Aylauth] [Destroy User] Response from User Service: #{response}"
      if response.blank?
        sign_out_user(auth_token)
        Aylauth::Cache.delete(auth_token)
        Aylauth::Cache.expire("auth_token", auth_token)
        return {:deleted => true}
      end
      return response
    end

    def admin_destroy_user(auth_token, user_id)
      body = { :auth_token => auth_token, :application => {:app_id => Aylauth::Settings.application_id, :app_secret => Aylauth::Settings.application_secret} }
      on_success = Proc.new { |code, body| { deleted: true } }
      on_error   = Proc.new do |code, body|
        logger.info "======= ON ERROR: #{body}"
        body
      end
      options = { body: body.to_json,
                  headers: {"Content-Type" => "application/json"},
                  method: :delete,
                  return_err_value: nil,
                  on_success: on_success,
                  on_error: on_error }
      response = call_external_service(Aylauth::Settings.user_service_admin_user_url + "/#{user_id}.json", options)

      logger.debug "[Aylauth] [Destroy User] Response from User Service: #{response.status}"
      return response.status
    end

    def admin_approve_user(auth_token, user_id, value)
      body = { :value => value, :auth_token => auth_token,
               :application => {:app_id => Aylauth::Settings.application_id, :app_secret => Aylauth::Settings.application_secret} }
      on_success = Proc.new { |code, body| { approved: true } }
      on_error   = Proc.new do |code, body|
        logger.info "======= ON ERROR: #{body}"
        body
      end
      options = { body: body.to_json,
                  headers: {"Content-Type" => "application/json"},
                  method: :post,
                  return_err_value: nil,
                  on_success: on_success,
                  on_error: on_error }
      response = call_external_service(Aylauth::Settings.user_service_admin_user_url + "/#{user_id}/approve.json", options)

      logger.debug "[Aylauth] [Approve User] Response from User Service: #{response.status}"
      return response.status
    end

    def admin_confirm_user(auth_token, user_id, value)
      body = { auth_token: auth_token, :value => value, :application => {:app_id => Aylauth::Settings.application_id, :app_secret => Aylauth::Settings.application_secret} }
      on_success = Proc.new { |code, body| { confirmed: true } }
      on_error   = Proc.new do |code, body|
        logger.info "======= ON ERROR: #{body}"
        body
      end
      options = { body: body.to_json,
                  headers: {"Content-Type" => "application/json"},
                  method: :post,
                  return_err_value: nil,
                  on_success: on_success,
                  on_error: on_error }
      response = call_external_service(Aylauth::Settings.user_service_admin_user_url + "/#{user_id}/confirm.json", options)

      logger.debug "[Aylauth] [Confirm User] Response from User Service: #{response.status}"
      return response.status
    end

    def admin_adminify_user(auth_token, user_id, value)
      body = { :value => value,  :auth_token => auth_token,
               :application => {:app_id => Aylauth::Settings.application_id, :app_secret => Aylauth::Settings.application_secret} }
      on_success = Proc.new { |code, body| { adminified: true } }
      on_error   = Proc.new do |code, body|
        logger.info "======= ON ERROR: #{body}"
        body
      end
      options = { body: body.to_json,
                  headers: {"Content-Type" => "application/json" },
                  method: :post,
                  return_err_value: nil,
                  on_success: on_success,
                  on_error: on_error }
      response = call_external_service(Aylauth::Settings.user_service_admin_user_url + "/#{user_id}/adminify.json", options)

      logger.debug "[Aylauth] [Adminify User] Response from User Service: #{response.status}"
      return response.status
    end

    def admin_approve_oem_user(auth_token, user_id, value)
      body = { :value => value,  :auth_token => auth_token,
               :application => {:app_id => Aylauth::Settings.application_id, :app_secret => Aylauth::Settings.application_secret} }
      on_success = Proc.new { |code, body| { oem_approved: true } }
      on_error   = Proc.new do |code, body|
        logger.info "======= ON ERROR: #{body}"
        body
      end
      options = { body: body.to_json,
                  headers: {"Content-Type" => "application/json"},
                  method: :post,
                  return_err_value: nil,
                  on_success: on_success,
                  on_error: on_error }
      response = call_external_service(Aylauth::Settings.user_service_admin_user_url + "/#{user_id}/approve_oem.json", options)

      logger.debug "[Aylauth] [Approve Oem User] Response from User Service: #{response.status}"
      return response.status
    end

    def oem_adminify_user(auth_token, user_id, value)
      body = { :user_id => user_id, :value => value, :auth_token => auth_token,
               :application => {:app_id => Aylauth::Settings.application_id, :app_secret => Aylauth::Settings.application_secret} }
      on_success = Proc.new { |code, body| { approved: true } }
      on_error   = Proc.new do |code, body|
        logger.info "======= ON ERROR: #{body}"
        body
      end
      options = { body: body.to_json,
                  headers: {"Content-Type" => "application/json"},
                  method: :post,
                  return_err_value: nil,
                  on_success: on_success,
                  on_error: on_error }
      response = call_external_service(Aylauth::Settings.user_service_base_url + "/oems/oem_admin.json", options)

      logger.debug "[Aylauth] [Adminify Oem User] Response from User Service: #{response.status}"
      return response.status
    end

    def associate_oem(auth_token)
      body = { :auth_token => auth_token }
      on_success = Proc.new { |code, body| body["association"] }
      options = { body: body.to_json,
                  method: :get,
                  return_err_value: nil,
                  on_success: on_success }
      response = call_external_service(Aylauth::Settings.user_service_base_url + "/oems/new.json?", options)
      logger.debug "[Aylauth] [Associate Oem] Response from User Service: #{response}"
      refresh_cache_for_user(auth_token)

      return response.status
    end

    def deassociate_oem(auth_token)
      body = { :auth_token => auth_token }
      options = { body: body.to_json,
                  method: :post,
                  return_err_value: nil }
      response = call_external_service(Aylauth::Settings.user_service_base_url + "/oems/deassociate.json?", options)
      logger.debug "[Aylauth] [Deassociate OEM] Response from User Service (should be empty): #{response}"
      refresh_cache_for_user(auth_token)
    end

    def create_oem(auth_token, oem_data)
      body = { :auth_token => auth_token, :oem => oem_data }
      on_success = Proc.new { |code, body| {} }
      on_error   = Proc.new { |code, body| body }
      options = { body: body.to_json,
                  method: :post,
                  return_err_value: nil,
                  on_success: on_success,
                  on_error: on_error }
      response = call_external_service(Aylauth::Settings.user_service_base_url + "/oems.json?", options)
      logger.debug "[Aylauth] [Create OEM] Response from User Service: #{response}"
      refresh_cache_for_user(auth_token)

      response.status
    end

    def find_device_by_id(auth_token, device_id)
      authorization_header = "auth_token #{auth_token}"
      options = { body: {}.to_json,
                  headers: {"Content-Type" => "application/json",
                            "AUTHORIZATION" => authorization_header },
                            method: :get,
                            return_err_value: nil }
      response = call_external_service(Aylauth::Settings.device_service_base_url + "/apiv1/devices/#{device_id}.json", options)
      logger.debug "[Aylauth] [Find device by id] Response from Device Service: #{response}"
      device_json = ActiveSupport::JSON.decode(response.to_json)
      user = find_user_by_id(auth_token, device_json["device"]["user_id"])
      device = ::Aylauth::Device.new({id: device_json["device"]["id"],
                                      product_name: device_json["device"]["product_name"],
                                      user_id: device_json["device"]["user_id"],
                                      model: device_json["device"]["model"],
                                      product_class: device_json["device"]["product_class"],
                                      location: device_json["device"]["location"],
                                      connected_at: device_json["device"]["connected_at"],
                                      oem_model: device_json["device"]["oem_model"],
                                      template_id: device_json["device"]["template_id"],
                                      mac: device_json["device"]["mac"],
                                      lan_ip: device_json["device"]["lan_ip"],
                                      ip: device_json["device"]["ip"],
                                        has_properties: device_json["device"]["has_properties"],
                                        dsn: device_json["device"]["dsn"]})
        device.user_email = user.email unless user.nil?
        return device
    end

    def find_devices_by_oem(auth_token, oem_id, page=nil, results_per_page=nil)
      body = { :auth_token => auth_token }
      options = { body: body.to_json,
                  method: :get,
                  return_err_value: nil }
      oem = call_external_service(Aylauth::Settings.user_service_base_url + "/oems/#{oem_id}.json",options)

      options = {  headers: { "Content-Type" => "application/json",
                             "AUTHORIZATION" => "auth_token #{auth_token}"},
                  method: :get,
                  return_err_value: nil }
      paginated_devices = call_external_service(Aylauth::Settings.device_service_base_url + "/apiv1/devices/find_by_oem_id.json?oem_id=#{oem.fetch('oem_id')}&page_number=#{page}&per_page=#{results_per_page}&paginated=true", options)
      logger.info "[Aylauth#find_devices_by_oem] #{paginated_devices}"

      ret_devices = []
      devices = JSON.parse(paginated_devices.fetch("result"))
      devices.each do |device|
        user = find_user_by_id(auth_token, device["device"]["user_id"])
        d = ::Aylauth::Device.new({:id => device["device"]["key"],
                                   :product_name => device["device"]["product_name"],
                                   :user_id => device["device"]["user_id"],
                                   :model => device["device"]["model"],
                                   :product_class => device["device"]["product_class"],
                                   :location => device["device"]["location"],
                                   :registered => device["device"]["registered"],
                                   :connected_at => device["device"]["connected_at"],
                                   :oem_model => device["device"]["oem_model"],
                                   :template_id => device["device"]["template_id"],
                                   :mac => device["device"]["mac"],
                                   :lan_ip => device["device"]["lan_ip"],
                                   :has_properties => device["device"]["has_properties"],
                                   :dsn => device["device"]["dsn"]})
        d.user_email = user.email unless user.nil?
        ret_devices << d
      end

      return {devices: ret_devices, next_page: paginated_devices.fetch("next_page"), previous_page: paginated_devices.fetch("previous_page"), total_count: paginated_devices.fetch("total_count")}
    end

    def find_users_by_oem(auth_token, oem_id)
      process_service_call do
        resp = find_devices_by_oem(auth_token, oem_id)
        ret_users = []
        resp[:devices].each do |device|
          if device.user_id.present?
            user = find_user_by_id(auth_token, device.user_id)
            ret_users << user
          end
        end
        return ret_users.uniq{|user| user.email}
      end
    end

    def find_oem_users_by_oem(auth_token, oem_id)
      body = { :auth_token => auth_token }
      options = { body: body.to_json,
                  method: :get,
                  return_err_value: nil }
      users = call_external_service(Aylauth::Settings.user_service_base_url + "/oems/#{oem_id}/users.json", options)
      return [] if users.blank?
      ret_users = []
      users.each do |user|
        user_data = UserData.new(user)
        ret_users << user_data
      end
      ret_users
    end

    def find_user_by_id(auth_token, user_id)
      return nil if user_id.blank?
      body = { :auth_token => auth_token }
      options = { body: body.to_json,
                  method: :get,
                  return_err_value: nil }
      user = call_external_service(Aylauth::Settings.user_service_user_url + "/#{user_id}.json", options)
      return nil if user.blank?
      return UserData.new(user)
    end

     # TODO: Service to service call - needs service level auth
    def find_user_by_email(auth_token, user_email, origin_oem_str)
      return nil if user_email.blank?
      body = { :auth_token => auth_token }
      options = { body: body.to_json,
                  method: :get,
                  return_err_value: nil,
                  query: {email: user_email,
                           origin_oem_str: origin_oem_str}
                }
      user = call_external_service_with_service_token(Aylauth::Settings.user_service_base_url + "/api/v1/public/users/show_by_email.json", options)
      return if user.blank?
      return UserData.new(user)
    end

    def find_admins_by_oem(auth_token, oem_id)
      body = { :auth_token => auth_token }
      options = { body: body.to_json,
                  method: :get,
                  return_err_value: nil }
      response = call_external_service(Aylauth::Settings.user_service_base_url + "/oems/#{oem_id}/admins.json", options)
      return [] if response.blank?
      logger.debug "[Aylauth] [Find admins by OEM] Response from User Service: #{response}"
      admins = ActiveSupport::JSON.decode(response)
      ret_admins = []
      admins.each do |admin|
        a = UserData.new(admin)
        ret_admins << a
      end

      return ret_admins
    end

    def find_oem_by_id(auth_token, oem_id)
      body = { :auth_token => auth_token }
      on_error = Proc.new { |code, body| {} }
      on_success   = Proc.new { |code, body| body }
      options = { body: body.to_json,
                  method: :get,
                  return_err_value: nil,
                  on_error: on_error,
                  on_success: on_success }
      response = call_external_service(Aylauth::Settings.user_service_base_url + "/oems/#{oem_id}.json", options)
      logger.debug "[Aylauth] [Find OEM] Response from User Service: #{response}"

      response.status
    end

    def update_oem(auth_token, id, oem)
        #TODO: We need to change the auth_token in user for the auth_token in access_grant. better way?
        body = {:auth_token => auth_token, :id => id, :oem => oem}
        on_success = Proc.new { |code, body| { updated: true } }
        on_error = Proc.new { |code, body| body }
        options = { body: body.to_json,
                    method: :put,
                    return_err_value: nil,
                    on_success: on_success,
                    on_error: on_error }
        response = call_external_service(Aylauth::Settings.user_service_base_url + "/oems/#{id}.json?", options)
        logger.debug "[Aylauth] [Update User Data] Response from User Service: #{response}"
        refresh_cache_for_user(auth_token)

        response.status
    end

    def destroy_access_token(authtoken)
      Aylauth::Cache.delete(authtoken)
      Aylauth::Cache.expire("auth_token", authtoken)
    end

    def refresh_cache_for_user(auth_token)
      destroy_access_token(auth_token)
      fetch_auth_from_user_service(auth_token )
    end

    def tos_changed? auth_token
      response = call_external_service(Aylauth::Settings.user_service_user_url + "/tos_changed.json",
                                       {:method => :post,
                                        :body => { :auth_token => auth_token }.to_json})
      (response["code"] != 200)
    end

    def terms_token auth_token
      user_data = get_user_data_by_auth_token(auth_token)
      return user_data["terms_token"]
    end

    def terms_accepted? auth_token
      user_data = get_user_data_by_auth_token(auth_token)
      return user_data["terms_accepted"]
    end

    def send_terms_acceptance_email auth_token
      user_data = get_user_data_by_auth_token(auth_token)
      body = { :auth_token => auth_token }
      on_success = Proc.new { |code, body| { email_sent: true } }
      on_error   = Proc.new { |code, body| body }
      options = { body: body.to_json,
                  method: :put,
                  return_err_value: nil,
                  on_success: on_success,
                  on_error: on_error }
      response = call_external_service(Aylauth::Settings.user_service_user_url + "/terms_email.json?", options)
      logger.debug "[Aylauth] [Sent Terms Acceptance Email] Response from User Service: #{response}"

      response.status
    end

    def user_accept_terms(terms_token)
      response = call_external_service(Aylauth::Settings.user_service_user_url + "/terms_confirmation.json?terms_token=#{terms_token}",
                                       {:method => :get})
      !!(response["id"])
    end

    def fetch_auth_from_user_service(auth_token)
      response = call_external_service_with_service_token(Aylauth::Settings.user_service_user_url + "/is_valid.json?",
                            {return_value: nil,
                             on_success: on_success = Proc.new { |code, body| body },
                             body: wrap_with_json(auth_token) })
      response.status
    end
    cache :fetch_auth_from_user_service, expires_in: 1.day.to_i, expires_by: :auth_token

    # TODO: Service to service call - needs service level auth
    def fetch_oem_from_aus(oem)
      response = call_external_service(Aylauth::Settings.user_service_base_url + "/api/v1/oems/#{oem}.json",
                            {return_value: nil})
      (response.is_a?(Hash) && response["code"].present?) ? nil : response rescue nil
    end

    def fetch_oem_config_from_aus(id)
      response = call_external_service(Aylauth::Settings.user_service_base_url + "/api/v1/oems/#{id}/configurations.json",
                            {return_value: nil})
      (response.is_a?(Hash) && response["error"]) ? nil : response.first rescue nil
    end

    def fetch_oem_configuration(oem_str)
      oem = Aylauth::Cache.fetch(oem_str) do
        fetch_oem_from_aus(oem_str)
      end
      if oem.blank? || oem["id"].blank?
        Aylauth::Cache.delete(oem_str)
        return nil
      end

      oem_config = Aylauth::Cache.fetch(oem["id"], expires_in: Aylauth::Settings.validity) do
        fetch_oem_config_from_aus(oem["id"])
      end
      Aylauth::Cache.delete(oem["id"]) if oem_config.blank?

      oem_config
    end

    def refresh_auth_token(refresh_token)
      tokens = call_external_service(Aylauth::Settings.user_service_user_url + "/refresh_token.json?",
                            {return_value: nil,
                             :body => wrap_refresh_token_with_json(refresh_token)})
      [tokens['access_token'], tokens['refresh_token'], tokens['redirect_to']]
    end



    def find_roles_for(auth_token)
      roles = call_external_service(Aylauth::Settings.user_service_url + "/api/v1/users/roles.json?",
                            {return_value: [],
                             query: {app_id: Aylauth::Settings.application_id},
                             body: wrap_access_token(auth_token)})
    end

    def update_role_for(auth_token, role)
      response = call_external_service(Aylauth::Settings.user_service_url + "/api/v1/users/role.json?",
                            {return_value: [],
                             method: :put,
                             query: {target_role: role, app_id: Aylauth::Settings.application_id},
                             body:  wrap_access_token(auth_token)})
    end

    def find_applications_by_oem(id)
      return nil if id.blank?
      response = call_external_service(Aylauth::Settings.user_service_base_url + "/api/v1/public/oems/#{id}/applications.json")
      applications = []
      response.each do |application|
        applications << OpenStruct.new(application)
      end
      applications
    end

    def desk_dot_com_sso_redirect_url(current_user)
      return nil if current_user.blank?
      DeskDotComService.multipass_sso_url(current_user)
    end

    def wrap_access_token(auth_token)
      {:auth_token => auth_token}.to_json
    end

    def wrap_with_json(authtoken)
      {:user => {:access_token => authtoken}}.to_json
    end

    def wrap_refresh_token_with_json(refresh_token)
      {:user => {:refresh_token => refresh_token}}.to_json
    end

    def extract_token(authorization_header)
      authorization_header.split(" ").last
    end
  end
end
