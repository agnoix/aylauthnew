require 'aylauth/helpers'
require 'active_support'
require_relative 'user'
require_relative 'user_data'
require_relative 'device'
require_relative 'oem'

module Aylauth
  module Support
    include Aylauth::Helpers

    def current_user
      return @current_user if @current_user

      auth_header = extract_auth_header
      auth_user = extract_auth_user

      # either auth header or auth user, or both is mandatory
      unless (auth_header || auth_user)
        @current_user = nil # Invalidate previous set user.
        return nil
      end

      # first, try to extract user object from header
      @current_user = User.get_from_header(auth_user)

      if (@current_user && auth_header && auth_header.split(' ').last)
        # if extraction of user from header succeeds, populate token in user
        @current_user.auth_token = auth_header.split(' ').last
      else
        # extraction of user from header failed, proceed with authentication by auth token

        unless auth_header
          # auth header is mandatory
          @current_user = nil # invalidate previously set user
          return nil
        end

        @current_user = User.find_by_auth_token(auth_header)
        unless @current_user
          #auth_token has expired, build it from session
          auth_header = build_auth_header
          @current_user = User.find_by_auth_token(auth_header)
        end
        logger.debug "[Aylauth] Role: #{@current_user.role}" if @current_user
        logger.debug '[Aylauth] Nil User' if @current_user.nil?
      end

      @current_user
    end

    def extract_auth_user
      begin
        auth_user = request.headers['X-Current-User']
      rescue NoMethodError
        auth_user = nil
      end
      auth_user
    end

    def extract_auth_header
      auth_header = extract_authorization_header
      auth_header ||= "auth_token #{session['access_token']}" unless session['access_token'].blank?
      auth_header
    end

    def build_auth_header
      token, refresh, redirect_to = Aylauth::Actions.refresh_auth_token(session['refresh_token']) if session['refresh_token']
      session['access_token'] = token
      session['refresh_token'] = refresh
      session['redirect_to'] = redirect_to
      auth_header = "auth_token #{session['access_token']}"
    end

    def user_signed_in?
      !!current_user
    end

    def authenticate_user!
      unless user_signed_in?
        logger.debug "HTTP_ACCEPT: #{env['HTTP_ACCEPT']}, request_accept: #{request_accept}" if defined?(Rails)
        request_accept.each do |type|
          case type
            when 'text/html'
              unless session['redirect_to']
                redirect_to new_session_path and return
              else
                redirect_uri = session['redirect_to']
                session['redirect_to'] = nil
                redirect_uri += "&redirect_uri=#{post_process_provider_auth_sessions_url}"
                redirect_to redirect_uri and return
              end
            else
              if defined? Rails
                head :unauthorized and false
              else
                halt 401
              end
          end
        end
      end
    end


    #Example of use:
    #class ExampleController < ApplicationController
    #
    # before_filter ->{ authorize_oauth_scopes!([:device, :user]) }
    #end
    def authorize_oauth_scopes!(scopes)
      if current_user && current_user.oauth
        required_scopes = [scopes].flatten.map(&:to_s)
        logger.info "[Oauth Scopes] required: #{required_scopes}"
        unless (required_scopes - current_user.scopes).empty?
          head :forbidden and return false
        end
      end
    end

    def sign_in_user(username, password, oem_id = nil, app_name = nil)
      Aylauth::Actions.sign_in_user(username, password, oem_id, app_name)
    end

    def sign_out_user(auth_token)
      @current_user = nil
      Aylauth::Actions.sign_out_user(auth_token)
    end

    def change_role(auth_token, role)
      Aylauth::Actions.update_role_for(auth_token, role)
    end

    def invalidate_token(auth_token)
      logger.debug "[Aylauth] Invalidate: #{auth_token}"
      Aylauth::Actions.destroy_access_token(auth_token)
      session['access_token'] = nil
      session['refresh_token'] = nil
    end

    def rack_request
      rack_request = Rack::Request.new(env)
    end

    def request_accept
      env['HTTP_ACCEPT'] ? (env['HTTP_ACCEPT'].to_s.split(',').map { |a| a.strip } rescue ['text/html']) : [request.params[:format]]
    end

  end
end
