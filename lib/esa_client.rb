require 'esa'
require 'redis'
require 'json'
require 'time'

class EsaClient
  ESA_ACCESS_TOKEN = ENV['ESA_ACCESS_TOKEN']
  ESA_TEAM_NAME = ENV['ESA_TEAM_NAME']
  REDIS_URL = ENV['REDISTOGO_URL']

  def initialize
    @esa_client = Esa::Client.new(
      access_token: ESA_ACCESS_TOKEN,
      current_team: ESA_TEAM_NAME
    )
    @redis = Redis.new(:url => REDIS_URL)
  end

  def get(post_number)
    # 古いキャッシュを消す
    keys = @redis.keys("*")
    now = Time.now
    keys.each do |key|
      json = @redis.get(key)
      cache = JSON.parse(json)
      created_at = Time.parse(cache['created_at'])
      diff = now - created_at

      # 1時間以上前のログを消す
      @redis.del(key) if diff > (60 * 60)
    end

    cache_json = @redis.get(post_number)
    unless cache_json.nil?
      puts '[LOG] cache hit'
      cache = JSON.parse(cache_json)
      return cache['info']
    end

    post = @esa_client.post(post_number).body
    return {} if post.nil?

    title = post['full_name']
    title.insert(0, '[WIP] ') if post['wip']
    footer = generate_footer(post)

    # 素のままだと省略されても長いので10行までにする
    text = post['body_md'].lines[0, 10].map{ |item| item.chomp }.join("\n")

    info = {
      title: title,
      title_link: post['url'],
      author_name: post['created_by']['screen_name'],
      author_icon: post['created_by']['icon'],
      text: text,
      color: '#3E8E89',
      footer: footer
    }

    set_redis(post_number, info)
    return info
  end

  private
  def set_redis(post_number, info)
    json = {
      created_at: Time.now,
      info: info
    }.to_json

    @redis.set(post_number, json)
  end

  def generate_footer(post)
    updated_user_name = post.dig('updated_by', 'screen_name') || 'unknown'
    created_at = Time.parse(post['updated_at'])
    created_at_str = created_at.strftime("%Y-%m-%d %H:%M:%S")

    footer = "Updated by #{updated_user_name} \@#{created_at_str}"
  end
end
