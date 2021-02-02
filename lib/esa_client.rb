require 'esa'
require 'redis'
require 'json'
require 'time'

class EsaClient
  ESA_ACCESS_TOKEN = ENV['ESA_ACCESS_TOKEN']
  ESA_TEAM_NAME = ENV['ESA_TEAM_NAME']
  ESA_OUTPUT_FORMAT = ENV.fetch('ESA_OUTPUT_FORMAT', 'full')
  REDIS_URL = ENV['REDISTOGO_URL']

  def initialize
    @esa_client = Esa::Client.new(
      access_token: ESA_ACCESS_TOKEN,
      current_team: ESA_TEAM_NAME
    )
    @redis = Redis.new(:url => REDIS_URL)
  end

  def get_post(post_number)
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

    info = {
      title: title,
      title_link: post['url'],
      author_name: post['created_by']['screen_name'],
      author_icon: post['created_by']['icon'],
      text: post_text(post),
      color: '#3E8E89',
      footer: footer,
      ts: Time.parse(post['updated_at']).to_i
    }

    set_redis(post_number, info)
    return info
  end

  def get_comment(comment_number)
    # 古いキャッシュを消す
    keys = @redis.keys("comment-*")
    now = Time.now
    keys.each do |key|
      json = @redis.get(key)
      cache = JSON.parse(json)
      created_at = Time.parse(cache['created_at'])
      diff = now - created_at

      # 1時間以上前のログを消す
      @redis.del(key) if diff > (60 * 60)
    end

    cache_json = @redis.get("comment-#{comment_number}")
    unless cache_json.nil?
      puts '[LOG] cache hit'
      cache = JSON.parse(cache_json)
      return cache['info']
    end

    comment = @esa_client.comment(comment_number).body
    return {} if comment.nil?

    title = comment['full_name']
    title.insert(0, '[WIP] ') if comment['wip']
    footer = generate_footer(comment)
    info = {
      title: 'コメント',
      title_link: comment['url'],
      author_name: comment['created_by']['screen_name'],
      author_icon: comment['created_by']['icon'],
      text: comment_text(comment),
      color: '#3E8E89',
      footer: footer,
      ts: Time.parse(comment['updated_at']).to_i
    }

    set_redis("comment-#{comment_number}", info)
    return info
  end

  private
  def post_text(post)
    return '' if ESA_OUTPUT_FORMAT == 'title'
    # 素のままだと省略されても長いので10行までにする
    post['body_md'].lines[0, 10].map{ |item| item.chomp }.join("\n")
  end

  def comment_text(comment)
    return '' if ESA_OUTPUT_FORMAT == 'title'
    comment['body_md'].lines.map{ |item| item.chomp }.join("\n")
  end

  def set_redis(key, info)
    json = {
      created_at: Time.now,
      info: info
    }.to_json

    @redis.set(key, json)
  end

  def generate_footer(post)
    updated_user_name = post.dig('updated_by', 'screen_name')
    unless updated_user_name.nil?
      return "Updated by #{updated_user_name}"
    end

    created_user_name = post.dig('created_by', 'screen_name') || 'unknown'
    return "Created by #{created_user_name}"
  end
end
