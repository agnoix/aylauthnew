module Aylauth
  class Device
    attr_accessor :id, :product_name, :user_id, :model, :product_class, :user_email, :location, :registered, :connected_at, :oem_model, :template_id, :mac, :lan_ip, :ip, :has_properties, :dsn
    
    def initialize(data)
      data.each do |key, value|
        method_object = self.method((key.to_s + "=").to_sym)
        method_object.call(value)
      end
    end
  end
end
