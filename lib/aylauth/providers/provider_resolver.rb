module Aylauth
  module Provider
    module ProviderResolver
      extend self

      def get_provider_auth_url(provider)
        return get_provider_class(provider).get_auth_url
      end

      def sign_in_user_with_provider_auth(raw_state, code, redirect_uri)
        return nil unless code
        begin
          state = ActiveSupport::JSON.decode(Base64.strict_decode64(raw_state))
        rescue
          return nil
        end

        return nil unless state.has_key?("provider") and state.has_key?("redirect_uri")

        return get_provider_class(state["provider"]).sign_in_user_with_auth(state["redirect_uri"], code, redirect_uri)
      end

      private

      def get_provider_class(provider)
        case provider
        when "google_provider"
          return Aylauth::Provider::GoogleProvider
        when "facebook_provider"
          return Aylauth::Provider::FacebookProvider
        when "wechat_provider"
          return Aylauth::Provider::WechatProvider
        else
          return Aylauth::Provider::NilProvider
        end
      end
    end
  end
end
