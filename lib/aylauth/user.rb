module Aylauth
  class User
    attr_accessor :id, :uuid, :role, :oem_approved, :oem, :app_id, :auth_token, :fullname
    attr_accessor :email, :admin, :oem_admin, :role_tags, :origin_oem_id, :origin_oem_str
    attr_accessor :oauth, :scopes, :super_app, :linked_users

    def initialize(authorization={})
      @id = authorization["id"]
      @uuid = authorization["uuid"]
      @role = authorization["role"]
      @role_tags = authorization["role_tags"]
      @oauth = authorization["oauth"]
      @scopes = authorization["scopes"]
      @oem_approved = authorization["oem_approved"]
      @oem = OpenStruct.new(authorization["oem"]) if authorization["oem"].present?
      @app_id = authorization["application"]["uid"] if authorization["application"]
      @application_data = authorization["application"]
      @origin_oem_id = authorization["origin_oem_id"]
      @origin_oem_str = authorization["origin_oem_str"]
      @super_app = authorization["super_app"]
      @linked_users = authorization["linked_users"]
      
      if authorization["user"].present?
        @fullname = authorization["user"]["fullname"]
        @email = authorization["user"]["email"]
        @admin = authorization["user"]["admin"]
        @oem_admin = authorization["user"]["oem_admin"]
      end
    end

    def refresh!
      Aylauth.cache.delete(self.auth_token)
      Aylauth::Actions.get_user_data(self.auth_token)
    end

    def role_tag_list
      @role_tags || []
    end
    alias_method :role_tags, :role_tag_list

    def role_symbols
      @role
    end

    def has_oem?
      @oem.present?
    end

    def oem_approved?
      if @oem.present? && @oem.admin_user.present?
        @oem.admin_user.oem_approved
      end

      return false
    end

    def ayla_admin?
      @role == "Ayla::Admin"
    end

    def ayla_staff?
      @role == "Ayla::Staff"
    end

    def ayla_user?
      !!(@role =~ /^Ayla::/)
    end

    def oem_admin?
      self.oem_user? && @role == "OEM::Admin"
    end

    def ayla_oem_admin?
      self.oem_admin? && @oem && @oem.oem_id == Aylauth::Settings.ayla_oem_id_str
    end

    def oem_staff?
      self.oem_user? && @role == "OEM::Staff"
    end

    def oem_user?
      return true if self.ayla_admin?
      self.oem && self.oem_approved && @role.start_with?("OEM::")
    end

    #Mandatory method for Permit
    def fetch!
      {oem_id: @oem.id, id: @id, role: @role}
    end

    def self.find_by_auth_token(auth_token)
      Aylauth::Actions.get_user_data(auth_token)
    end

    def self.get_from_header(auth_user)
      Aylauth::Actions.get_user_from_header(auth_user)
    end

  end
end
