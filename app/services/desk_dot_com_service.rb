module DeskDotComService
  require 'openssl'
  require 'digest/sha1'
  require 'base64'
  require 'cgi'
  require 'time'
  require 'json'

  SUBDOMAIN = "#{Rails.application.config.desk_dot_com[:subdomain]}" rescue ""
  MULTIPASS_KEY = "#{Rails.application.config.desk_dot_com[:multipass_key]}" rescue ""
  EXPIRATION = Rails.application.config.desk_dot_com[:sso_expiration] rescue 86400
  SUCCESS_REDIRECT_URL = "#{Rails.application.config.desk_dot_com[:success_redirect_url]}" rescue nil

  class << self

    def multipass_sso_url(user)
      # Create the encryption key using a 16 byte SHA1 digest of your api key and subdomain
      key = Digest::SHA1.digest(MULTIPASS_KEY + SUBDOMAIN)[0...16]

      # Generate a random 16 byte IV
      iv = OpenSSL::Random.random_bytes(16)

      # Generate customer custom keys
      customer_custom_oem_role = "#{user.oem.name}_#{user.role}" rescue ""
      customer_custom_brand = user.oem.name rescue ""
      success_redirect_url = SUCCESS_REDIRECT_URL || "http://help.aylasupport.com"

      # Build the JSON string
      auth_hash = {
        uid: user.id,
        expires: (Time.now + EXPIRATION).iso8601,
        customer_name: user.fullname,
        to: success_redirect_url,
        customer_email: user.email,
        customer_custom_oem_role: customer_custom_oem_role,
        customer_custom_brand: customer_custom_brand
      }
      json = JSON.generate(auth_hash)

      Aylauth.logger.info "[DeskDotComService] SSO JSON: #{JSON.generate(Aylauth::PiiRemoval::PiiHashFilter.predefined.filter(auth_hash))} for uuid=#{user.uuid}"

      # Encrypt JSON string using AES128-CBC
      cipher = OpenSSL::Cipher::Cipher.new("aes-128-cbc")
      cipher.encrypt # specifies the cipher's mode (encryption vs decryption)
      cipher.key = key
      cipher.iv = iv
      encrypted = cipher.update(json) + cipher.final

      # Prepend encrypted data with the IV
      prepended = iv + encrypted

      # Base64 encode the prepended encrypted data
      multipass = Base64.encode64(prepended)

      # Build an HMAC-SHA1 signature using the encoded multipass and your api key
      signature = Base64.encode64(OpenSSL::HMAC.digest('sha1', MULTIPASS_KEY, multipass))

      # URL escape the final multipass and signature parameters
      encoded_multipass = CGI.escape(multipass)
      encoded_signature = CGI.escape(signature)

      Aylauth.logger.info "[DeskDotComService] SSO encoded_multipass: #{encoded_multipass}"
      Aylauth.logger.info "[DeskDotComService] SSO encoded_signature: #{encoded_signature}"

      "http://#{SUBDOMAIN}.desk.com/customer/authentication/multipass/callback?multipass=#{encoded_multipass}&signature=#{encoded_signature}"
    end

    
  end
end
