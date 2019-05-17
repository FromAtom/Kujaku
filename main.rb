require 'sinatra'
require 'sinatra/reloader' if development?
require 'json'

require_relative 'lib/esa_client'
require_relative 'lib/slack_api_client'

ESA_TEAM_NAME = ENV['ESA_TEAM_NAME']

post '/' do
  puts '[START]'
  params = JSON.parse(request.body.read)

  case params['type']
  when 'url_verification'
    # サーバの正当性検証
    challenge = params['challenge']
    return {
      challenge: challenge
    }.to_json
  when 'event_callback'
    channel = params.dig('event', 'channel')

    ts = params.dig('event', 'message_ts')
    links = params.dig('event', 'links')

    unfurls = {}
    links.each do |link|
      url = link['url']
      next unless url =~ /\Ahttps:\/\/#{ESA_TEAM_NAME}.esa.io\/posts\/(\d+).*\z/
      post_number = $1

      esa = EsaClient.new
      attachment = esa.get(post_number)

      unfurls[url] = attachment
    end

    payload = {
      channel: channel,
      ts: ts,
      unfurls: unfurls
    }.to_json

    slackApiClient = SlackApiClient.new
    slackApiClient.request(payload)
  end

  return {}.to_json
end
