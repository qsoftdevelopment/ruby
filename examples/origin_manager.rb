require 'pubnub'

# CONFIGURATION: Change this constants to change behaviour
# Notice: That constants are used internally withing this demo,
#         You won't find them in Pubnub library code.
TIMEOUT                = 10
INTERVAL               = 10
MAX_RETRIES            = 3
INTERVAL_AFTER_FAILURE = 10

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
    non_subscribe_timeout: TIMEOUT,                                  # It is used for non-subscribe events and origin manager ping timeout
    origin_heartbeat_interval: INTERVAL,                             # How frequently current origin server is pinged by origin manager
    origin_heartbeat_max_retries: MAX_RETRIES,                       # How many times origin manager has to fail pinging server before setting it as offline / online
    origin_heartbeat_interval_after_failure: INTERVAL_AFTER_FAILURE, # How frequently offline server is pinged by origin manager
    subscribe_key: :demo,
    publish_key:   :demo,
    error_callback: lambda { |_error_envelope| }, # For this example let's mute it
    origins_pool: ['geo1.devbuild.pubnub.com',
                   'geo2.devbuild.pubnub.com',
                   'geo3.devbuild.pubnub.com',
                   'geo4.devbuild.pubnub.com'],  # Origins list, order does count
    uuid: :origin_manager_tester
)

puts `clear`
puts 'Please be sure that geo1, geo2, geo3 and geo4 servers are up before running that demo.'

sleep 5
puts `clear`

puts '              Script: We\'re subscribing :bot channel.'
puts '              Script: Now You\'ll see messages from :bot. There should be no gaps in the messages.'
puts '              Script: (Notice: You\'ll encounter pauses while receiving messages due to origin switching)'

subscribe_to_bot(client)

sleep 10

puts '              Script: We\'re taking geo1 origin down for 160 seconds'

take_down(1, 160, client)

puts "              Script: After #{TIMEOUT * MAX_RETRIES} - #{TIMEOUT * (MAX_RETRIES + 1)} seconds You should catch up with published messages and continue getting messages."

countdown(TIMEOUT * MAX_RETRIES, 1)

sleep 20

puts '              Script: Now, let\'s take down geo2 as well (for 50s).'

take_down(2, 50, client)

puts '              Script: We have to wait a moment before connecting to geo3.'

countdown(TIMEOUT * MAX_RETRIES, 1)

puts '              Script: Right now You can observe how we\'re getting reconnected up to geo1 through geo2.'

sleep(3 * TIMEOUT * (MAX_RETRIES + 1))

puts '              Script: Let\'s take down geo1 once again and look if failback manager stopped fine and will start fine as well.'
puts '              Script: When You want to quit just break script hitting ctrl+z.'

take_down(1, 40, client)
countdown(TIMEOUT * MAX_RETRIES, 1)

while true do end
