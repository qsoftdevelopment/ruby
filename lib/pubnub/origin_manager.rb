module Pubnub
  class OriginManager
    attr_reader :dead_origins

    def initialize(app)
      @app  = app

      @http                     = app.env[:ssl] ? 'https://' : 'http://'
      @ping_interval            = app.env[:origin_heartbeat_interval]
      @timeout                  = app.env[:non_subscribe_timeout]
      @max_retries              = app.env[:origin_heartbeat_max_retries]
      @online_manager           = nil
      @failback_managers        = {}
      @last_failback_ping_start = {}
      @dead_origins             = []
      @original_origins_pool    = app.env[:origins_pool].dup.freeze
    end

    def start
      Pubnub.logger.debug('Pubnub::OriginManager') { 'Starting ORIGIN MANAGER' }

      failures = 0

      EM.add_periodic_timer(@ping_interval) do
        @last_alive_ping_start = ::Time.now
        begin
          Pubnub.logger.debug('Pubnub::OriginManager') { 'Setting current_origin' }
          current_origin = @app.env[:origins_pool].first
          Pubnub.logger.debug('Pubnub::OriginManager') { "Pinging #{current_origin + '/time/0'}" }


          if origin_online?(current_origin)
            @app.start_async if @app.async_halted?
            failures = 0
          else
            @app.halt_async unless @app.async_halted?
            failures += 1
          end

          if failures > @max_retries
            failures = 0
            set_origin_offline(current_origin)
            restart_subscription
            @app.start_async if @app.async_halted?
            start_failback_manager(current_origin)
          end

        rescue => e
          Pubnub.logger.error('Pubnub::OriginManager') { "#{e} #{e.backtrace}" }
        end unless @app.env[:origins_pool].empty?
      end
    end

    def start_failback_manager(dead_origin)
      Pubnub.logger.debug('Pubnub::OriginManager') { 'Starting FAILBACK ORIGIN MANAGER' }

      successes = 0
      @failback_managers[dead_origin] = EM.add_periodic_timer(@ping_interval) do
        @last_failback_ping_start[dead_origin] = ::Time.now
        begin
          dead_origin_to_test = dead_origin

          # if dead_origin_to_test != nil # Timer could fire again before cancelled

            Pubnub.logger.debug('Pubnub::OriginManager') { "Pinging dead origin #{dead_origin_to_test + '/time/0'}" }
            uri_to_test = URI.parse(@http + dead_origin_to_test + '/time/0')

            Pubnub.logger.debug('Pubnub::OriginManager') { "Origin manager: failback manager #{dead_origin_to_test}" }

            if alive_and_valid?(uri_to_test)
              Pubnub.logger.warn('Pubnub::OriginManager') { "Origin manager: #{dead_origin_to_test} is online, adding success"}
              successes += 1
            else
              Pubnub.logger.warn('Pubnub::OriginManager') { "Origin manager: #{dead_origin_to_test} is offline"}
              successes = 0
            end

            if successes == @max_retries
              Pubnub.logger.debug('Pubnub::OriginManager') { "Origin comes back to us! #{dead_origin_to_test}" }
              successes = 0
              set_origin_online(dead_origin_to_test)
              restart_subscription
              @failback_managers[dead_origin].cancel
              until @failback_managers[dead_origin].instance_variable_get(:@cancelled) do end
              @failback_managers[dead_origin] = nil
              Pubnub.logger.debug('Pubnub::OriginManager') { "Canceled FailbackManager for #{dead_origin}" }
            end
          # else
          #   restart_subscription
          #   Pubnub.logger.debug('Pubnub::OriginManager') { 'Cancelling FailbackManagerb' }
          #   @failback_manager.cancel
          #   until @failback_manager.instance_variable_get(:@cancelled) do end
          # end

        rescue => e
          Pubnub.logger.error('Pubnub::OriginManager') { "#{e} #{e.backtrace}" }
        end
      end
    end

    private

    def origin_online?(origin)
      Pubnub.logger.debug('Pubnub::OriginManager') { 'origin_online?' }
      uri_to_test = URI.parse(@http + origin + '/time/0')
      Pubnub.logger.debug('Pubnub::OriginManager') { "origin_online? #{uri_to_test}" }

      if alive_and_valid?(uri_to_test)
        Pubnub.logger.debug('Pubnub::OriginManager') { "Origin manager: #{origin} is online" }
         true
      else
        Pubnub.logger.debug('Pubnub::OriginManager') { "Origin manager: #{origin} is offline" }
        false
      end

    end

    def restart_subscription
      Pubnub.logger.debug('Pubnub::OriginManager') { 'Restarting subscription' }
      @app.start_subscribe(true)
    end

    def set_origin_offline(origin)
      Pubnub.logger.warn('Pubnub::OriginManager') { "Setting origin offline #{origin}" }
      @app.env[:origins_pool].delete_if { |o| o == origin }
      @dead_origins << origin
      Pubnub.logger.debug('Pubnub::OriginManager') { "Marked origin as offline. Online origins: #{@app.env[:origins_pool].join(" ")} Offline origins: #{@dead_origins.join(" ")}" }
    end

    def set_origin_online(origin)
      Pubnub.logger.warn('Pubnub::OriginManager') { "Setting origin online #{origin}" }
      @dead_origins.delete_if { |o| o == origin }
      @app.env[:origins_pool].unshift(origin)
      @app.env[:origins_pool].sort_by! { |o| @original_origins_pool.index(o) }
      Pubnub.logger.debug('Pubnub::OriginManager') { "Marked origin as online. Online origins: #{@app.env[:origins_pool].join(" ")} Offline origins: #{@dead_origins.join(" ")}" }
    end

    def alive_and_valid?(uri)
      Pubnub.logger.debug('Pubnub::OriginManager') { "Checking alive_and_valid #{uri}" }
      begin
        response = Net::HTTP.start(uri.host, uri.port) do |http|
          request = Net::HTTP::Get.new uri
          http.read_timeout = @timeout
          http.request request
        end
        response.is_a?(Net::HTTPSuccess) && Parser.valid_json?(response.body) ? true : false

      rescue Errno::ECONNREFUSED
        false
      rescue => e
        Pubnub.logger.error('Pubnub::OriginManager'){ "#{e.inspect} #{e.backtrace}" }
        false
      end
    end
  end
end
