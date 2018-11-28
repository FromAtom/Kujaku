require 'net/http'
require 'json'

class SlackApiClient
  SLACK_API_ENDPOINT = 'https://slack.com/api/chat.unfurl'.freeze
  SLACK_AUTH_KEY = ENV['SLACK_OAUTH_ACCESS_TOKEN']

  def initialize
    uri = URI.parse(SLACK_API_ENDPOINT)
    @req = Net::HTTP::Post.new(uri.request_uri)
    @req['Content-Type'] = 'application/json;  charset=utf-8'
    @req['Authorization'] = "Bearer #{SLACK_AUTH_KEY}"

    @https = Net::HTTP.new(uri.host, uri.port)
    @https.use_ssl = true
  end

  def request(json)
    @req.body = json

    res = @https.request(@req)
    puts "[LOG] slack response: #{res.body}"
  end
end
