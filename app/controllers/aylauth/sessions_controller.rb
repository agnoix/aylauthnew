module Aylauth
  class SessionsController < ::ApplicationController
    # GET /sessions/new
    def new
    end

    # POST /sessions
    def create
      respond_to do |format|
        @username = params[:email]
        password = params[:password]
        @from_desk_dot_com = params[:from_desk_dot_com] == "true"
        @oem_id = params[:oem_id]
        @app_name = params[:app_name]
        at_developer_site = Aylauth::Settings.application_id == "devwebserver_id"
        @selected_app = params[:selected_app]
        @oems = Aylauth::Actions.find_oems_by_user_email(@username) if at_developer_site && @oem_id.blank?

        if @oems && @oems.size > 1
          format.html { render "/home/select_oem" }
        else
          if @selected_app == 'default'
            auth_token, refresh_token = sign_in_user(@username, password, @oem_id)
          else
            auth_token, refresh_token = sign_in_user(@username, password, @oem_id, @app_name)
          end
        
          if auth_token.blank? || auth_token == "Your account is locked."
          if @app_name.blank? && auth_token == "Your account is locked."
            @error_msg = "Your have exceeded maximum login attempts. Your account is locked. Please try after 30 minutes"
          elsif @app_name.blank? && auth_token.blank?
            @error_msg = "Invalid username or password"
          else
            @error_msg = "Invalid application name or password"
          end
          flash[:alert] = @error_msg
          if at_developer_site
            unless @app_name
              format.html { render "/home/sign_in" }
            else
              format.html { render "/home/select_application" }
            end
           else
             format.html { render :new }
          end
          else
            unless Aylauth::Actions.tos_changed?(auth_token)
              session["access_token"] = auth_token
              session["refresh_token"] = refresh_token
              unless @from_desk_dot_com
                format.html { redirect_to root_path }
              else
                format.html { redirect_to DeskDotComService.multipass_sso_url(current_user) }
              end
            else
              session["terms_token"] = Aylauth::Actions.terms_token(auth_token)
              flash[:alert] = "You must accept the Terms to continue."
              @user_data = Aylauth::UserData.new
              if at_developer_site
                format.html { redirect_to "/terms_and_conditions" }
              else
                format.html { render :accept_terms }
              end
            end
          end
        end
      end
    end

    # DELETE /sessions/:id
    def destroy
      auth_token = params[:id]
      sign_out_user(auth_token)
      session["access_token"] = nil
      session["refresh_token"] = nil
      respond_to do |format|
        format.html { redirect_to root_path }
        format.json  { head :ok }
      end
    end

    # Public: Get the oauth provider url.
    #
    # provider - A String representing the provider to use: (google_provider, facebook_provider  or email_password).
    #            Default is email_password
    #
    # Examples
    #   GET /sessions/provider_auth
    #
    # Returns a String with the provider oauth url.
    def provider_auth
      provider_url = Aylauth::Provider::ProviderResolver.get_provider_auth_url(params[:provider])
      respond_to do |format|
        format.json {
          render json: provider_url
        }
      end
    end

    # Public: Post process the oauth token.
    #
    # code - A string representing the auth token.
    # state - A JSON String with additional parameters sent to the provider, encoded in Base64.
    #
    # Examples
    #   GET /sessions/post_process_provider_auth
    #
    # Returns Nothing. Redirect to the root path after authentication.
    def post_process_provider_auth
      logger.debug "[POST PROCESS PROVIDER AUTH - code  ] #{params[:code]}"
      logger.debug "[POST PROCESS PROVIDER AUTH - state ] #{params[:state]}"

      auth_token, refresh_token = Aylauth::Provider::ProviderResolver.sign_in_user_with_provider_auth(params[:state], params[:code], post_process_provider_auth_sessions_url)

      respond_to do |format|
        if auth_token.blank?
          flash[:alert] = "Invalid token from provider. Please try again."
          format.html { redirect_to root_path(:external_auth => true) }
        else
          unless Aylauth::Actions.tos_changed?(auth_token)
            session["access_token"] = auth_token
            session["refresh_token"] = refresh_token
            format.html { redirect_to root_path(:external_auth => true) }
          else
            session["terms_token"] = Aylauth::Actions.terms_token(auth_token)
            flash[:alert] = "You must accept the Terms to continue."
            @user_data = Aylauth::UserData.new
            format.html { redirect_to "/terms_and_conditions?external_auth=true" }
          end
        end
      end
    end

    # Public: Accept the terms and conditions
    #
    # Examples
    #   POST /sessions/accept_terms
    #
    # Returns Nothing. Redirect to root_path
    def accept_terms
      respond_to do |format|
        if Aylauth::Actions.user_accept_terms(session["terms_token"])
          session["terms_token"] = nil
          flash[:alert] = "Terms of service accepted. Please sign-in again to continue."
          format.html { redirect_to root_path }
          format.json { head :ok }
        else
          flash[:alert] = "You must accept the Terms to continue."
          @user_data = Aylauth::UserData.new
          format.html { render 'accept_terms' }
          format.json  { head :unprocessable_entity }
        end
      end
    end

    # Public: Update role for current service
    #
    # Examples
    #   PUT  /sessions/:id/role/
    #
    # Returns Nothing. Redirect to root_path
    def update_role
      auth_token = params[:id]
      change_role(auth_token, params[:role])
      current_user.refresh!
      redirect_to root_path
    end

  end
end
