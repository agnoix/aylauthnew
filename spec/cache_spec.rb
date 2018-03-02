require 'aylauth/cache'
require 'spec_helper'

describe Aylauth::Cache do

  describe '#mutex' do
    it 'expires lock_key when error raised' do
      Aylauth::Cache.stub :store, ActiveSupport::Cache::MemoryStore.new do
        begin
          Aylauth::Cache::Event.mutex 'key_event' do
            Aylauth::Cache.exist?('updating:key_event').must_be :==, true
            raise Exception.new
          end
        rescue Exception
          sleep 1
          Aylauth::Cache.exist?('updating:key_event').must_be :==, false
        end
      end
    end

    it 'expires lock_key when takes too much' do
      Aylauth::Cache.stub :store, ActiveSupport::Cache::MemoryStore.new do
        Aylauth::Cache::Event.mutex 'key_event' do
          Aylauth::Cache.exist?('updating:key_event').must_be :==, true
          sleep 3
          Aylauth::Cache.exist?('updating:key_event').must_be :==, false
        end
        Aylauth::Cache.exist?('updating:key_event').must_be :==, false
      end
    end

    it 'expires lock_key after 1.5 secs' do
      Aylauth::Cache.stub :store, ActiveSupport::Cache::MemoryStore.new do
        Aylauth::Cache.write('updating:key_event', true)
        Aylauth::Cache::Event.mutex 'key_event' do
          sleep 1
        end
        Aylauth::Cache.exist?('updating:key_event').must_be :==, false
      end
    end
  end

end
