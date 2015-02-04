require 'pubnub'

# Sends to geoX.devbuild.pubnub.com message to simulate server down for certain amount of time
def take_down(server_number, time, client)
  client.publish(
      channel: "denyme#{time}geo#{server_number}",
      message: 'denyme',
      http_sync: true
  ) do |_|
    puts "            Callback: geo#{server_number} taken down for #{time} seconds."
    sleep 3
  end
end

# Subscribes to bot channel that publishes messages that are easy to read for tests
def subscribe_to_bot(client)
  client.subscribe(channel: :bot) do |envelope|
    puts "  Subscribe Callback: #{envelope.uri.host} #{envelope.message}"
  end
end

# Sleeps sleep_seconds * count
def countdown(count, sleep_seconds)
  print "           Countdown: #{count}\n                    : "
  count.times do |c|
    i = c + 1
    if i % 5 == 0 || i == 1
      print i
    else
      print '.'
    end
    sleep sleep_seconds
  end
  print "\n"
end

client = Pubnub.new(
    non_subscribe_timeout: 10,                   # It is used for non-subscribe events and origin manager ping timeout
    origin_heartbeat_interval: 10,               # How frequently current origin server is pinged by origin manager
    origin_heartbeat_max_retries: 3,             # How many times origin manager has to fail pinging server before setting it as offline / online
    origin_heartbeat_interval_after_failure: 10, # How frequently offline server is pinged by origin manager
    subscribe_key: :demo,
    publish_key:   :demo,
    origins_pool: ['geo1.devbuild.pubnub.com',
                   'geo2.devbuild.pubnub.com',
                   'geo3.devbuild.pubnub.com',
                   'geo4.devbuild.pubnub.com'],  # Origins list, order does count
    uuid: :origin_manager_tester
)

puts '              Script: We\'re subscribing :bot channel.'
puts '              Script: Now You\'ll see messages from :bot. There should be no gaps in the messages.'
puts '              Script: (Notice: You\'ll encounter pauses while receiving messages due to origin switching)'

subscribe_to_bot(client)

sleep 10

puts '              Script: We\'re taking geo1 origin down for 120 seconds'

take_down(1, 120, client)

puts '              Script: In ~45 seconds You should catch up with published messages and continue getting messages.'

countdown(45, 1)

sleep 10

puts '              Script: Now, let\'s take down geo2 as well.'

take_down(2, 120, client)

sleep 3

puts '              Script: We have to wait a moment before connecting to geo3.'

countdown(30, 1)

puts '              Script: Right now You can observe how we\'re getting reconnected up to geo1.'
puts '              Script: When You want to quit just break script hitting ctrl+z.'

while true do end