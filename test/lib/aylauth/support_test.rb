require_relative '../../test_helper'
require 'aylauth/support'
require 'aylauth/user'

class Rack
  class Request; end
end

describe Aylauth::Support do
  include Aylauth::Support
  before do
    Rack::Request.stubs(:new).returns(stub(params:{}))
    stubs(:env).returns({})
    stubs(:session).returns({"access_token" => "123"})
    stubs(:logger).returns(stub(debug: ""))
  end

  it 'returns a valid user with valid token' do
    Aylauth::User.expects(:find_by_auth_token).returns(stub(role: stub))

    current_user.wont_equal nil
  end

  it 'returns a vlid user with an invalid token' do
    Aylauth::User.stubs(:find_by_auth_token).returns(nil, stub(role: stub))
    Aylauth::Actions.expects(:refresh_auth_token).returns({"access_token" => "1",
                                                           "refresh_token" => "2",
                                                           "redirect_to" => "someplace"})

    current_user.wont_equal nil
  end

  it 'returns nil user if no token refresh' do
    Aylauth::User.stubs(:find_by_auth_token).returns(nil, nil)
    Aylauth::Actions.expects(:refresh_auth_token).returns({"error" => "The refresh token is invalid."})
    current_user == nil
  end
end
