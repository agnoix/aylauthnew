require_relative '../../../test_helper'
require 'aylauth/providers/provider_resolver'

describe Aylauth::Provider::ProviderResolver do
  it "returns nil if raw_state is nil" do
    result = Aylauth::Provider::ProviderResolver.sign_in_user_with_provider_auth(nil, "code", "http://some")
    result.must_equal nil
  end

  it "returns nil if code is nil" do
    result = Aylauth::Provider::ProviderResolver.sign_in_user_with_provider_auth("eyJwcm92aWRlciI6Imdvb2dsZV9hdXRoIiwicmVkaXJlY3RfdXJpIjoiaHR0cDovL3NvbWUuY29tIn0=", nil, "http://some")
    result.must_equal nil
  end

  it "returns nil if raw_state is empty" do
    result = Aylauth::Provider::ProviderResolver.sign_in_user_with_provider_auth(" ", "code", "http://some")
    result.must_equal nil
  end

  it "returns nil if raw_state is invalid base 64" do
    result = Aylauth::Provider::ProviderResolver.sign_in_user_with_provider_auth("macarroon", "code", "http://some")
    result.must_equal nil
  end

  it "returns nil if state doesn't include provider" do
    state = {something: "bad", redirect_uri: "http://some.com" }.to_json
    result = Aylauth::Provider::ProviderResolver.sign_in_user_with_provider_auth(Base64.strict_encode64(state), "code", "http://some")
    result.must_equal nil
  end

  it "returns nil if state doesn't include redirect_uri" do
    state = {provider: "google_auth", something: "bad" }.to_json
    result = Aylauth::Provider::ProviderResolver.sign_in_user_with_provider_auth(Base64.strict_encode64(state), "code", "http://some")
    result.must_equal nil
  end

  it "returns nil if the provider is incorrect" do
    state = {provider: "bad_provider", redirect_uri: "http://some.com" }.to_json
    result = Aylauth::Provider::ProviderResolver.sign_in_user_with_provider_auth(Base64.strict_encode64(state), "code", "http://some")
    result.must_equal nil
  end

end
