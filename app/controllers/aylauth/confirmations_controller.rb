module Aylauth
  class ConfirmationsController < ::ApplicationController
    def new
      @user_data = ::Aylauth::UserData.new
    end

    def create
      @user_data = ::Aylauth::UserData.new(params[:aylauth_user_data])
      origin_oem_id = params[:origin_oem_id]
      resp = Aylauth::Actions.resend_confirmation(@user_data, origin_oem_id, !origin_oem_id.blank?)
      respond_to do |format|
        if resp['errors'].blank?
          format.html { redirect_to root_path, :notice => "You will receive an email with the confirmation token" }
          format.json  { head :ok }
        else
          flash[:error] = "There was a problem processing your request: #{resp['errors']}"
          format.html { render :new }
          format.json  { head :unprocessable_entity, :message => "#{resp['errors']}" }
        end
      end
    end
  end
end
