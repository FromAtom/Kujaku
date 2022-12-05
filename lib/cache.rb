require 'redis'
require 'json'
require 'google/cloud/firestore'

class Cache
    REDIS_TTL = 60 * 60 # 1時間
    FIRE_STORE_TTL = 60 * 60 # 1時間

    def initialize
        if redis_enable?
            @redis = Redis.new(:url => ENV['REDIS_URL'])
        end

        if firestore_enable?
            @collection_id = ENV['FIRESTORE_COLLECTION']
            @firestore = Google::Cloud::Firestore.new
        end
    end

    def get(key)
        return get_redis(key) if redis_enable?
        return get_firestore(key) if firestore_enable?
    end

    def set(key, info)
        if redis_enable?
            set_redis(key, info)
        end

        if firestore_enable?
            set_firestore(key, info)
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

    def set_firestore(key, info)
        json = {
            info: info,
            expires_at: Time.now + FIRE_STORE_TTL
        }
        doc = @firestore.doc(firestore_key(key))
        doc.set(json)
    end

    def get_firestore(key)
        ref = @firestore.doc(firestore_key(key))
        return nil if ref.get.fields.nil?
        return ref.get.fields.to_json
    end

    def firestore_key(key)
        @collection_id + "/" + key
    end
end