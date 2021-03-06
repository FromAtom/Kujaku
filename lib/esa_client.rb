require 'esa'
require 'redis'
require 'json'
require 'time'

class EsaClient
  ESA_ACCESS_TOKEN = ENV['ESA_ACCESS_TOKEN']
  ESA_TEAM_NAME = ENV['ESA_TEAM_NAME']
  ESA_MAX_ARTICLE_LINES = ENV.fetch('ESA_MAX_ARTICLE_LINES', '10').to_i
  ESA_MAX_COMMENT_LINES = ENV.fetch('ESA_MAX_COMMENT_LINES', '10').to_i
  REDIS_URL = ENV['REDISTOGO_URL']

  def initialize
    @esa_client = Esa::Client.new(
      access_token: ESA_ACCESS_TOKEN,
      current_team: ESA_TEAM_NAME
    )
    @redis = Redis.new(:url => REDIS_URL)
  end

  def get_post(post_number)
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
      text: article_text(post),
      color: '#3E8E89',
      footer: footer,
      ts: Time.parse(post['updated_at']).to_i
    }

    set_redis(post_number, info)
    return info
  end

  def get_comment(comment_number)
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
  def article_text(post)
    post['body_md'].lines[0, ESA_MAX_ARTICLE_LINES].map{ |item| item.chomp }.join("\n")
  end

  def comment_text(comment)
    comment['body_md'].lines[0, ESA_MAX_COMMENT_LINES].map{ |item| item.chomp }.join("\n")
  end

  def set_redis(key, info)
    json = {
      info: info
    }.to_json

    @redis.set(key, json, ex: 60 * 60)
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
