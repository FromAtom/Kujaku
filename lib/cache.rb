require 'redis'
require 'json'
require 'google/cloud/firestore'

class Cache
    REDIS_TTL = 60 * 60 # 1時間

    def initialize
        if redis_enable?
            @redis = Redis.new(:url => ENV['REDIS_URL'])
        end

        if firestore_enable?
            @firestore = Google::Cloud::Firestore.new
        end
    end

    def get(key)
        return get_redis(key) if redis_enable?
    end

    def set(key, info)
        if redis_enable?
            set_redis(key, info)
        end
    end

    private
    def redis_enable?
        ENV['REDIS_URL'] && !ENV['REDIS_URL'].empty?
    end

    def firestore_enable?
        ENV['FIRESTORE_COLLECTION'] && !ENV['FIRESTORE_COLLECTION'].empty?
    end

    def get_redis(key)
        # ttl導入前のkeyが残り続けることを避ける
        @redis.keys.each do |key|
          if @redis.ttl(key) == -1
            @redis.expire(key, REDIS_TTL)
          end
        end

        @redis.get(key)
    end

    def set_redis(key, info)
        json = {
          info: info
        }.to_json

        @redis.set(key, json, ex: REDIS_TTL)
    end
end