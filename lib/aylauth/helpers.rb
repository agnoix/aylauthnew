module Aylauth
  module Helpers

    def userservice_admin_path
      admin_url = Aylauth::Settings.user_service_base_url + "/admin/users"
      admin_url << "?auth_token=#{session['access_token']}"
      admin_url
    end

    def extract_authorization_header
      if defined?(Rails)
        auth_header = request.headers["HTTP_AUTHORIZATION"] || request.headers["AUTHORIZATION"]
      else
        auth_header = rack_request.params["HTTP_AUTHORIZATION"] || rack_request.params["AUTHORIZATION"] || rack_request.env["HTTP_AUTHORIZATION"]
      end
      auth_header
    end

    def terms_accepted? auth_token
      user_data = Aylauth::Actions.get_user_data_by_auth_token(auth_token)
      return user_data["terms_accepted"]
    end

  end
end
