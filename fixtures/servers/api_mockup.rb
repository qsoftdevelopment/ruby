require 'bundler'
require 'grape'
require 'pry'
require 'json'

# Like memory
class Memory
  def initialize
    @memory = []
  end

  def add(channel, message, tt = nil)
    tt ||= current_timestamp
    puts "Adding #{message} to channel #{channel} at #{tt}"
    @memory << [channel, message, tt]
    puts "Current memory:\n#{@memory}"
  end

  def find(channel, tt)
    @memory.select do |cell|
      cell[0] == channel && cell[2] >= tt
    end
  end

  def clear
    @memory = []
  end

  private

  def current_timestamp
    t = Time.now.to_f.to_s.gsub('.', '')[0..16]
    while t.size < 17
      t += '0'
    end
    t
  end
end

$memory = Memory.new
$fail_until = Time.now

# Toplevel pubnub module
module Pubnub

  # Limited Pubnub Server's API mockup
  class APIMockup < Grape::API

    format :json

    helpers do
      def current_timestamp
        t = Time.now.to_f.to_s.gsub('.', '')[0..16]
        while t.size < 17
          t += '0'
        end
        t
      end

      def format_messages_for(channels, tt)
        if channels.size == 1
          messages = $memory.find(channels.first, tt)
          [messages.map { |m| m[1] }, current_timestamp]
        else
          messages = []
          channels.each do |channel|
            messages << $memory.find(channel, tt).map { |cell| [cell[1], cell[0]] }
          end

          msgs  = messages.flatten(1).map { |cell| cell[0] }
          chans = messages.flatten(1).map { |cell| cell[1] }.join(',')
          tt    = current_timestamp

          [msgs,tt,chans]
        end
      end
    end

    get 'publish/:publish_key/:subscribe_key/:auth_key/:channel/0/:message' do
      if Time.now < $fail_until
        puts "Server will rise errors for another #{$fail_until - Time.now}"
        error!('DEADBEEF', 500)
      end

      if (JSON.parse("[#{params[:message]}]") == ['denyme']) && (params[:channel] =~ /\Adenyme\d+\z/)
        time = params[:channel][/\d+/].to_i
        $fail_until = Time.now + time
        puts "Server will rise errors until #{$fail_until}"
      end

      params[:channel].split(',').each do |channel|
        $memory.add(
            channel,
            JSON.parse("[#{params[:message]}]").first,
            current_timestamp
        )
      end

      [1, 'Sent', current_timestamp]
    end

    get 'subscribe/:subscribe_key/:channels/0/:timetoken' do
      if Time.now < $fail_until
        puts "Server will rise errors for another #{$fail_until - Time.now}"
        error!('DEADBEEF', 500)
      end
      event_time = Time.now

      messages = [[], current_timestamp]

      while messages.first.size == 0 && Time.now < event_time + 300
        messages = format_messages_for(params[:channels].split(','), params[:timetoken])
        sleep 1
      end

      messages
    end

    get 'time/0' do
      if Time.now < $fail_until
        puts "Server will rise errors for another #{$fail_until - Time.now}"
        error!('DEADBEEF', 500)
      end

      [current_timestamp]
    end

    get 'v2/presence/sub-key/:subscribe_key/channel/:channel/leave' do
      if Time.now < $fail_until
        puts "Server will rise errors for another #{$fail_until - Time.now}"
        error!('DEADBEEF', 500)
      end
      { status: 200, action: :leave, message: :OK, service: :Presence }
    end

    get 'v2/presence/sub-key/:subscribe_key/channel/:channels/heartbeat' do
      if Time.now < $fail_until
        puts "Server will rise errors for another #{$fail_until - Time.now}"
        error!('DEADBEEF', 500)
      end
      { status: 200, message: :OK, service: :Presence }
    end

    get 'history' do
      if Time.now < $fail_until
        puts "Server will rise errors for another #{$fail_until - Time.now}"
        error!('DEADBEEF', 500)
      end
    end
  end
end