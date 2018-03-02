module Aylauth
  module Provider
    module NilProvider
      extend self

      def get_auth_url
        nil
      end

      def sign_in_user_with_auth(url, code, redirect_url)
        nil
      end
    end
  end
end
