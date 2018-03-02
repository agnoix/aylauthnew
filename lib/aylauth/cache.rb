require 'base64'
require 'dalli'
require 'dalli-elasticache'
require 'active_support/cache'
require 'active_support/cache/memory_store'
require 'active_support/cache/dalli_store'

module Aylauth
  module Cache

    def self.included(klass)
      #Define macros-method to cache methods
      klass.send :define_singleton_method, :cache do |method_to_cache, options={}|
        expires_in = options.delete(:expires_in)
        event = options.delete(:expires_by)
        if event
          if event.is_a?(Symbol) || event.is_a?(String)
            namespace = event
            arg_name = event.to_sym
          elsif event.is_a?(Hash)
            namespace = event.keys.first.to_s
            arg_name = event.values.first.to_sym
          end
          _parameters = method(method_to_cache).parameters
          arg_position = _parameters.each_with_index {|arg, index| break index if arg.last == arg_name }
          raise NoMethodError.new("Argument: #{arg_name} no present in #{method_to_cache}") unless arg_position.is_a?Fixnum
        end

        # If method_to_cache is an instance method
        if self.instance_methods(false).include?(method_to_cache)
          # alias original method
          alias_method "uncached_#{method_to_cache}", method_to_cache

          # Using fetch to read or cache/return result from original method
          define_method method_to_cache do |*args|
            key = "#{klass.to_s.downcase}.#{method_to_cache}:#{args.to_s}"
            Cache.fetch(key, expires_in: expires_in) do
              Cache::Event.add_listener(namespace, args.at(arg_position), key) if event && arg_position
              send("uncached_#{method_to_cache}", *args)
            end
          end

        # If method_to_cache is a class method
        else
          # alias original class method

          self.singleton_class.send :alias_method, "uncached_#{method_to_cache}", method_to_cache

          # Using fetch to read or cache/return result from original method
          define_singleton_method method_to_cache do |*args|
            key = "#{klass.to_s.downcase}.#{method_to_cache}:#{args.to_s}"
            Cache.fetch(key, expires_in: expires_in) do
              Cache::Event.add_listener(namespace, args.at(arg_position), key) if event && arg_position
              send("uncached_#{method_to_cache}", *args)
            end
          end
        end
      end
    end

    class << self
      attr_accessor :logger, :silence, :verbose, :running

      def store
        Store.instance
      end

      def expire(event, key)
        Event.notify(event, key)
      end

      def clear
        store.clear
      end

      def exist?(key)
        store.exist?(key)
      end

      def read(key)
        value = store.read(key)
        return value.to_bool if value && %w(true false).include?(value)
        value
      end

      def write(key, value, options=nil)
        value = value.to_s if %w(true false).include?(value)
        value = value.dup if not value.singleton_methods.empty?
        store.write(key, value, options)
      end

      def delete(key)
        return false if key.blank?
        store.delete(key)
      end

      def fetch(key, options=nil)
        logger.debug "[Aylauth::Cache] Fetch #{key}"
        value = read(key)
        if value.nil? && block_given?
          _start = Time.now
          value = yield
          _end = Time.now
          logger.debug "[Aylauth::Cache] Fetch #{key} takes #{(_end - _start) * 1000} ms"

          write(key, value, options)
        end
        value
      end

      def alive?
        store.respond_to?(:alive!) ? store.alive! : true

        rescue Dalli::RingError => dalli_exception
          logger.error "[CacheService] #{dalli_exception.message} "
          false
      end

      private

      def running_env
        if defined?Rails
          Rails.env
        elsif defined?Padrino
          Padrino.env
        end
      end

      def logger
        @logger||= if store.logger
                     store.logger
                   else
                     if  running_env == "development"
                       Logger.new(STDOUT)
                     else
                       if defined?Rails
                         Rails.logger
                       elsif defined?Padrino
                         Padrino.logger
                       end
                     end
                   end
      end
    end #Class methods

    class Store
      include Singleton
      attr_accessor :store

      class << self
        alias_method :build_instance, :instance
        def instance
          build_instance.store
        end
      end

      def initialize
        if elasticache_endpoint = Aylauth::Settings.elasticache_endpoint
          elasticache = Dalli::ElastiCache.new(elasticache_endpoint)
          @store = ActiveSupport::Cache::DalliStore.new(elasticache.servers)
        else
          @store = ActiveSupport::Cache::MemoryStore.new
        end
      end
    end #Store

    module Event

      def self.add_listener(namespace, event, listener)
        key_event = "event:#{namespace}:#{event}"
        mutex(key_event) {
          listeners = Aylauth::Cache.read(key_event)
          listeners = Array.new(listeners || [])
          listeners.push(listener)
          Aylauth::Cache.write(key_event, listeners, expires_in: 2.days)
        }
      end

      def self.notify(namespace, event)
        key_event = "event:#{namespace}:#{event}"
        mutex(key_event) {
          listeners = Aylauth::Cache.read(key_event)
          listeners.each do |listener|
            Aylauth::Cache.delete(listener)
          end if listeners
          Aylauth::Cache.delete(key_event)
        }
      end

      def self.mutex(key_event)
        lock_key = "updating:#{key_event}"
        counter = 0
        while Aylauth::Cache.exist?(lock_key) && counter < 5
          sleep 0.3
          counter+=1 #prevent loop wait more than 1.5 seconds
        end
        Aylauth::Cache.delete(lock_key) if counter == 3 #remove key in case

        Aylauth::Cache.write(lock_key, true, expires_in: 1.seconds)
        yield
        Aylauth::Cache.delete(lock_key)
      end
    end

  end
end
