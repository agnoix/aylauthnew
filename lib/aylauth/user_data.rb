require 'ostruct'
require 'active_model'

module Aylauth
  class UserData
    include ActiveModel::Validations

    attr_accessor :approved, :ayla_dev_kit_num, :city, :company, :country, :email, :firstname, :id, :uuid, :lastname, :oem_id, :phone_country_code, :phone, :state, :street, :zip, :logged_in_at
    attr_accessor :secanswer1, :secanswer2, :secanswer3, :secquestion1, :secquestion2, :secquestion3, :security_key, :updated_at, :zip2, :current_password, :password
    attr_accessor :password_confirmation, :admin, :access_id, :created_at, :auth_token, :reset_password_token, :oem, :oem_approved, :is_oem_admin, :origin_oem_str, :user_id
    attr_accessor :terms_accepted, :terms_accepted_at, :terms_email_sent_at, :terms_token, :to_key, :role, :staff, :origin_oem_id

    validates_presence_of :email, :firstname, :lastname

    def initialize(attributes = {})
      attributes.each do |field,value|
        field = field.downcase
        value = OpenStruct.new(value) if value.is_a?Hash
        self.instance_variable_set("@#{field}", value)
        self.class.send(:define_method, field, proc{self.instance_variable_get("@#{field}")})
        self.class.send(:define_method, "#{field}=", proc{|v| self.instance_variable_set("@#{field}", v)})
      end
    end

    #TODO :This is a duplication of ActiveRecord
    def update_attributes(options = {})
      options.each do |key, value|
        method_object = self.method((key + "=").to_sym)
        if ( value.is_a?(Hash) )
          method_object.call(OpenStruct.new(value))
        else
          method_object.call(value)
        end
      end
    end

    def new_record?
      new_record
    end

    def persisted?
      false
    end

    def confirmed?
      confirmed
    end

    def awaiting_oem_authorization?
      awaiting_oem_authorization
    end

    #TODO: Fix this duplication!
    def admin_allowed
      return true if admin == "true"
    end

    def oem_approved?
      oem_approved
    end

    def is_oem_admin?
      is_oem_admin
    end

    def to_json(options={})
      opts = options || {:except => [:access_id, :admin, :created_at, :auth_token]}
      hash = {}
      self.instance_variables.each do |attribute|
        hash[attribute.to_s.delete("@")]=self.instance_variable_get(attribute)
      end
      hash.to_json(opts)
    end

    def save
      Aylauth::Actions.update_user_data(self.auth_token, self)
    end

    def self.find_by_id(id, auth_token)
      user_data = new Aylauth::Actions.get_user_data_by_id(auth_token, id)
      user_data.auth_token = auth_token
      user_data
    end

    def self.find_by_auth_token(auth_token)
      user_data = new Aylauth::Actions.get_user_data_by_auth_token(auth_token)
      user_data.auth_token = auth_token
      user_data
    end

    def self.create(user_data)
      new(Aylauth::Actions.create_user(user_data) )
    end

  end
end
