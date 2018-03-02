module Aylauth
  class PasswordsController < ::ApplicationController
    def new
      @user_data = ::Aylauth::UserData.new
    end

    def create
      respond_to do |format|
        @user_data = ::Aylauth::UserData.new(params[:aylauth_user_data])
        username = @user_data.email
        oem_id = params["oem_id"]
        app_name = params["app_name"]
        at_developer_site = Aylauth::Settings.application_id == "devwebserver_id"
        oems = Aylauth::Actions.find_oems_by_user_email(username) if at_developer_site && oem_id.blank?

        if oems && oems.size > 1
          format.json { render :json => { oems: oems }, :status => :unprocessable_entity }
        else
          resp = Aylauth::Actions.send_reset_password(@user_data, nil, !oem_id.blank?, oem_id, app_name)

          if resp['errors'].blank?
            format.html { redirect_to root_path, :notice => "You will receive an email to reset your password" }
            format.json  { head :ok }
          else
            flash[:alert] = "#{resp['errors']['base'][0]}"
            format.html { render :new }
            format.json  { head :unprocessable_entity }
          end
        end
      end
    end

    def edit
      @user_data = ::Aylauth::UserData.new
      @user_data.reset_password_token = params[:reset_password_token]
    end

    def update
      @user_data = ::Aylauth::UserData.new(params[:aylauth_user_data])
      resp = Aylauth::Actions.reset_password(@user_data)
      respond_to do |format|
        if resp['errors'].blank?
          session["access_token"] = nil
          session["refresh_token"] = nil
          format.html { redirect_to root_path, :notice => "Your password has been changed." }
          format.json  { head :ok }
        else
          flash[:error] = "There was a problem trying to reset your password: #{resp['errors']}"
          format.html { render :edit }
          format.json  { head :unprocessable_entity }
        end
      end
    end
  end
end
