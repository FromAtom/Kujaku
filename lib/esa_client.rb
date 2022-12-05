require 'esa'
require 'json'
require 'time'

require_relative 'cache'

class EsaClient
  ESA_ACCESS_TOKEN = ENV['ESA_ACCESS_TOKEN']
  ESA_TEAM_NAME = ENV['ESA_TEAM_NAME']
  ESA_MAX_ARTICLE_LINES = ENV.fetch('ESA_MAX_ARTICLE_LINES', '10').to_i
  ESA_MAX_COMMENT_LINES = ENV.fetch('ESA_MAX_COMMENT_LINES', '10').to_i

  def initialize
    @esa_client = Esa::Client.new(
      access_token: ESA_ACCESS_TOKEN,
      current_team: ESA_TEAM_NAME
    )
    @cache = Cache.new
  end

  def get_post(post_number)
    cache_json = @cache.get(post_number)
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
      title: unescape(title),
      title_link: post['url'],
      author_name: post['created_by']['screen_name'],
      author_icon: post['created_by']['icon'],
      text: article_text(post),
      color: '#3E8E89',
      footer: footer,
      ts: Time.parse(post['updated_at']).to_i
    }

    @cache.set(post_number, info)
    return info
  end

  def get_comment(post_number, comment_number)
    cache_json = @cache.get("comment-#{comment_number}")
    unless cache_json.nil?
      puts '[LOG] cache hit'
      cache = JSON.parse(cache_json)
      return cache['info']
    end

    post = @esa_client.post(post_number, {include: "comments"}).body
    return {} if post.nil?

    comment = nil
    post['comments'].each do |c|
      if c['id'] == comment_number.to_i
        comment = c
        break
      end
    end

    if comment.nil?
      comment = @esa_client.comment(comment_number).body
    end
    return {} if comment.nil?

    post_name = post['full_name']
    post_name.insert(0, '[WIP] ') if post['wip']
    title = "#{post_name} へのコメント"
    footer = generate_footer(comment)
    info = {
      title: title,
      title_link: comment['url'],
      author_name: comment['created_by']['screen_name'],
      author_icon: comment['created_by']['icon'],
      text: comment_text(comment),
      color: '#3E8E89',
      footer: footer,
      ts: Time.parse(comment['updated_at']).to_i
    }

    @cache.set("comment-#{comment_number}", info)
    return info
  end

  private
  def article_text(post)
    unescape(post['body_md'].lines[0, ESA_MAX_ARTICLE_LINES].map{ |item| item.chomp }.join("\n"))
  end

  def comment_text(comment)
    unescape(comment['body_md'].lines[0, ESA_MAX_COMMENT_LINES].map{ |item| item.chomp }.join("\n"))
  end

  def unescape(str)
    str.gsub('&#35;', '#').gsub('&#47;', '/')
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
