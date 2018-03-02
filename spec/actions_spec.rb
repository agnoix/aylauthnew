require 'spec_helper'
require 'aylauth/actions'
require 'base64'

describe Aylauth::Actions do
  include Aylauth::Actions

  let(:logger_mock) { double('Rails.logger').as_null_object }

  before(:each) do
    allow_message_expectations_on_nil
    allow(Rails.logger).to receive(:debug).and_return(logger_mock)
    allow(Rails.logger).to receive(:error).and_return(logger_mock)
    allow(Rails.logger).to receive(:info).and_return(logger_mock)
  end

  after(:each) do
    Rails.unstub(:logger)
  end

  describe '#get_user_from_header' do

    it 'returns nil if auth_user is nil' do
      expect(get_user_from_header(nil)).to be_nil
    end

    it 'returns nil if auth_user is not parseable' do
      auth_user = 1
      expect(get_user_from_header(auth_user)).to be_nil
    end

    it 'returns nil if expiry_time in auth_user is nil' do
      auth_user = Base64.encode64(File.read('spec/fixtures/auth_user_expiry_time_nil.json'))
      expect(get_user_from_header(auth_user)).to be_nil
    end

    it 'returns nil if expiry_time in auth_user is in past' do
      auth_user = Base64.encode64(File.read('spec/fixtures/auth_user_fully_parseable.json'))
      expect(get_user_from_header(auth_user)).to be_nil
    end
  end

  describe '#get_user_from_header1' do

    it 'returns authorization object if auth_user is fully parseable' do
      auth_user = Base64.encode64(File.read('spec/fixtures/auth_user_fully_parseable.json').sub! '2016-06-21T21:23:35Z', (DateTime.now + 1.days).to_s)

      user = get_user_from_header(auth_user)
      user.id.should equal 1
      user.oem_approved.should be true
      expect(user.fullname).to eq 'Jon Doe'
    end
  end

end
