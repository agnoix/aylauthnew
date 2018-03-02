require_relative '../../test_helper'
require 'aylauth/configurable'

describe Aylauth::Configurable do

  it "save configuration" do
    Aylauth.configure do |config|
      config.cache = "tute" 
    end

    Aylauth.cache.must_equal "tute"
  end

end
