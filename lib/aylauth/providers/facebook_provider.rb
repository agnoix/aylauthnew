module Aylauth
  module Provider
    module FacebookProvider
      extend self

      def get_auth_url
        body = { user: {application: {app_id: Aylauth::Settings.application_id,
                                      app_secret: Aylauth::Settings.application_secret },
                                      auth_method: "facebook_provider" } }
        options = { body: ActiveSupport::JSON.encode(body),
                    method: :post,
                    process_json: false}

        Aylauth::ExternalService.call_external_service(Aylauth::Settings.user_service_user_url + "/sign_in.json", options)
      end

      def sign_in_user_with_auth(url, code, redirect_url)
        body = { code: code,
                 app_id: Aylauth::Settings.application_id,
                 redirect_url: redirect_url,
                 provider: "facebook_provider" }

        options = { body: ActiveSupport::JSON.encode(body), method: :post }

        response = Aylauth::ExternalService.call_external_service(url, options)
        if response["error"].blank?
          return [ response["access_token"], response["refresh_token"] ]
        else
          return nil
        end
      end
    end
  end
end
