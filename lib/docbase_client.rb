# frozen_string_literal: true

require 'docbase'
require 'redis'
require 'json'
require 'time'

class DocBaseClient
  DOCBASE_ACCESS_TOKEN = ENV['DOCBASE_ACCESS_TOKEN']
  DOCBASE_TEAM_NAME    = ENV['DOCBASE_TEAM_NAME']
  REDIS_URL            = ENV['REDISTOGO_URL']

  def initialize
    @docbase_client = DocBase::Client.new(
      access_token: DOCBASE_ACCESS_TOKEN,
      team: DOCBASE_TEAM_NAME
    )
    @redis = Redis.new(url: REDIS_URL)
  end

  def get_post(post_number)
    keys = @redis.keys('*')
    now = Time.now

    keys.each do |key|
      json = @redis.get(key)
      cache = JSON.parse(json)
      created_at = Time.parse(cache['created_at'])
      diff = now - created_at

      @redis.del(key) if diff > (60 * 60)
    end

    cache_json = @redis.get(post_number)

    unless cache_json.nil?
      puts '[LOG] cache hit'
      cache = JSON.parse(cache_json)
      return cache['info']
    end

    post = @docbase_client.post(post_number).body
    return {} if post.nil?

    title  = post['title']
    footer = generate_footer(post)
    text   = post['body'].lines[0, 10].map(&:chomp).join("\n")

    info = {
      title: title,
      title_link: post['url'],
      author_name: post.dig('user', 'name') || 'unknown',
      author_icon: post.dig('user', 'profile_image_url'),
      text: text,
      color: '#3E8E89',
      footer: footer,
      ts: Time.parse(post['created_at']).to_i
    }

    set_redis(post_number, info)
    info
  end

  private

  def set_redis(key, info)
    json = {
      created_at: Time.now,
      info: info
    }.to_json

    @redis.set(key, json)
  end

  def generate_footer(post)
    created_user_name = post.dig('user', 'name') || 'unknown'
    "Created by #{created_user_name}"
  end
end
