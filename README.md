# Aylauth

This gem allow any service to connect with userservice without having to write a single line of code.

## Installation

Add this line to your application's Gemfile:

    gem 'aylauth'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install aylauth

## Usage

The only thing that you need to get this gem working is to add a config file in {Rails.root}/config/ayla_auth.yml which should look like this:

    default: &defaults
      application_id: YOUR_APP_ID
      application_secret: YOUR_APP_SECRET
    
    development:
      <<: *defaults
      user_service_url: URL_TO_USER_SERVICE_IN_DEVELOPMENT
    
    test:
      <<: *defaults
      user_service_url: URL_TO_USER_SERVICE_IN_TEST
    
    staging:
      <<: *defaults
      user_service_url: URL_TO_USER_SERVICE_IN_STAGING
    
    production:
      <<: *defaults
      user_service_url: URL_TO_USER_SERVICE_IN_PRODUCTION


## Aylauth::Cache

You can cache using Aylauth::Cache using MemoryStore or ElastiCache. 
To use MemoryStore add in ayla_auth.yml:

  elasticache_endpoint: false

To use ElastiCache, include add an AWS ElastiCache uri:

  elasticache_endpoint: "staging.qmhfop.cfg.use1.cache.amazonaws.com:11211"

You can cache fragmets through fetch:

    oem = Aylauth::Cache.fetch(oem_str) do
      fetch_oem_from_aus(oem_str)
    end

To remove a manual cache, you need to delete the entry:
 
    Aylauth::Cache.delete(oem_str)


You can also cache a whole method:

    def fetch_auth_from_user_service(auth_token)
      #do something
    end
    cache :fetch_auth_from_user_service, expires_in: 1.day.to_i, expires_by: :auth_token

The argument in expires_by need to be the same as one of the arguments of the method. If you want to change the namespace, you can do:

    cache :fetch_auth_from_user_service, expires_in: 1.day.to_i, expires_by: {token: :auth_token}


This will cache method fetch_auth_from_user_service during a day. To manually expire (remove) this cache use:

    Aylauth::Cache.expire("auth_token", auth_token)

If you changed the namespace to token, then:

    Aylauth::Cache.expire("token", auth_token)



## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
