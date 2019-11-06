# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader' if development?
require 'json'

require_relative 'lib/slack_api_client'
require_relative 'lib/docbase_client'

DOCBASE_TEAM_NAME = ENV['DOCBASE_TEAM_NAME']

post '/' do
  puts '[START]'
  params = JSON.parse(request.body.read)

  case params['type']
  when 'url_verification'
    challenge = params['challenge']
    return { challenge: challenge }.to_json
  when 'event_callback'
    channel = params.dig('event', 'channel')
    ts      = params.dig('event', 'message_ts')
    links   = params.dig('event', 'links')

    unfurls = {}

    links.each do |link|
      url = link['url']

      unless url.match(%r{\Ahttps://#{DOCBASE_TEAM_NAME}.docbase.io/posts/(\d+).*\z})
        next
      end

      post_number = Regexp.last_match(1)
      docbase = DocBaseClient.new
      attachment = docbase.get_post(post_number)
      unfurls[url] = attachment
    end

    payload = {
      channel: channel,
      ts: ts,
      unfurls: unfurls
    }.to_json

    slack_api_client = SlackApiClient.new
    slack_api_client.request(payload)
  end

  return {}.to_json
end
