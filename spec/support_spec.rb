require 'spec_helper'
require 'aylauth/support'
require 'aylauth/user'

describe Aylauth::Support do
  include Aylauth::Support

  let(:logger_mock) { double('Rails.logger').as_null_object }
  let(:auth_user) { ActiveSupport::JSON.decode File.read('spec/fixtures/auth_user_fully_parseable.json') }

  before(:each) do
    allow_message_expectations_on_nil
    allow(Rails.logger).to receive(:debug).and_return(logger_mock)
    allow(Rails.logger).to receive(:error).and_return(logger_mock)
    allow(Rails.logger).to receive(:info).and_return(logger_mock)
  end

  after(:each) do
    Rails.unstub(:logger)
  end

  it 'extracts current user from header and populates auth token in user' do
    auth_user[:expiry_time] = (Time.now + 2.hours).to_s
    allow_any_instance_of(Aylauth::Support).to receive(:extract_auth_header).and_return('access_token foo')
    allow_any_instance_of(Aylauth::Support).to receive(:extract_auth_user).and_return(Base64.encode64(auth_user.to_json))

    user = current_user
    expect(user.fullname).to eq 'Jon Doe'
    expect(user.auth_token).to eq 'foo'
  end

  it 'returns nil user if no auth header' do
    auth_user[:expiry_time] = (Time.now + 2.hours).to_s
    allow_any_instance_of(Aylauth::Support).to receive(:extract_auth_header).and_return(nil)
    allow_any_instance_of(Aylauth::Support).to receive(:extract_auth_user).and_return(Base64.encode64(auth_user.to_json))

    user = current_user
    expect(user).to be_nil
  end

  xit 'returns nil user if no refresh token' do
    # TODO
  end

  xit 'returns a valid user with valid token' do
    # TODO
  end

  xit 'returns nil user if invalid token' do
    # TODO
  end

end
