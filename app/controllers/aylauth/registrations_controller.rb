module Aylauth
  class RegistrationsController < ::ApplicationController
    before_filter :authenticate_user!, :only => [:edit, :update, :show, :destroy]

    # GET /registrations/new
    def new
      @user_data = Aylauth::UserData.new
    end

    # POST /registrations
    def create
      @user_data = Aylauth::UserData.new(params[:aylauth_user_data])
      response = Aylauth::Actions.create_user(@user_data)
      respond_to do |format|
        if response["errors"].blank?
          format.html { redirect_to root_path, :notice => "You will receive an email to confirm your sign up" }
          format.json  { head :ok }
        else
          @errors = response["errors"]
          format.html { render :new }
          format.json  { render :json => @errors, :status => :unprocessable_entity }
        end
      end
    end

    # GET /registrations/:id/edit
    def edit
      auth_token = current_user.auth_token
      @roles = Aylauth::Actions.find_roles_for(auth_token)
      @user_data = Aylauth::UserData.find_by_auth_token(auth_token)
      respond_to do |format|
        format.html { render :edit }
        format.json  { render :json => @user_data } # @roles are not used for devwebserver
      end
    end

    # PUT /registrations/
    def update
      # id = Base64.strict_decode64(params[:id])
      # @user_data = Aylauth::UserData.find_by_auth_token(id) check if this is used by other service
      @user_data = Aylauth::UserData.find_by_auth_token(current_user.auth_token)
      @user_data.update_attributes(params[:aylauth_user_data])
      @response = @user_data.save

      respond_to do |format|
        if @response["errors"].blank?
          format.html { redirect_to root_path, :notice  => "Your data has been updated successfully" }
          format.json  { head :ok }
        else
          format.html { 
            @roles = Aylauth::Actions.find_roles_for(Base64.strict_decode64(params[:id]))
            render :edit 
          }
          format.json  { render :json => @response["errors"], :status => :unprocessable_entity }
        end
      end
    end

    # DELETE /registrations/:id
    def destroy
      @user_data = Aylauth::UserData.find_by_auth_token(current_user.auth_token)
      head :not_authorized and return unless @user_data.id.to_i == params[:id].to_i

      resp = Aylauth::Actions.destroy_user(current_user.auth_token, @user_data)
      respond_to do |format|
        
          if resp["error"].blank?
            sign_out_user(current_user.auth_token)
            session["access_token"] = nil
            session["refresh_token"] = nil
            format.html { redirect_to root_path, :notice => "Your user has been deleted successfully" }
            format.json  { head :ok }
          else
            flash[:error] = "There was a problem saving your data: #{resp['errors']}"
            format.html { render :edit }
            format.json  { render :json => resp["error"], :status => :unprocessable_entity }
          end
      end
    end

    # GET /registrations/:id
    def show
      @user_data = ::Aylauth::UserData.find_by_id(params[:id], current_user.auth_token)
    end
  end
end
