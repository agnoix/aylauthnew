module Aylauth
  module Configurable
    attr_accessor :cache, :logger

    def configure
      yield self
      self
    end

    def cache
      @cache||=ActiveSupport::Cache::MemoryStore.new
    end

    def logger
      @logger||= if defined?Rails
        Rails.logger
      elsif defined?Padrino
        Padrino.logger
      else
        Logger.new(STDOUT)
      end
    end

  end
end
