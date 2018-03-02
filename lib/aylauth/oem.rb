module Aylauth
  class Oem
    attr_accessor :id, :oem_id, :name
    
    def initialize(data)
      data.each do |key, value|
        method_object = self.method((key.to_s + "=").to_sym)
        method_object.call(value)
      end
    end
  end
end
