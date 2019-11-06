# frozen_string_literal: true

class EventParams
  def initialize(params)
    @params = params
  end

  def channel
    @params.dig('event', 'channel')
  end

  def ts
    @params.dig('event', 'message_ts')
  end

  def links
    @params..dig('event', 'links')
  end
end
