require 'spec_helper'

describe Pubnub::OriginManager do
  around :each do |example|
    example.run
  end

  context 'sets' do
    context 'from defaults' do
      before :all do
        @pn = Pubnub.new(subscribe_key: :demo)
      end

      it 'ORIGINS_POOL' do
        expect(@pn.env[:origins_pool].nil?).to eq false
      end

      it 'ORIGIN_HEARTBEAT_INTERVAL' do
        expect(@pn.env[:origin_heartbeat_interval].nil?).to eq false
        expect(@pn.env[:origin_heartbeat_interval]).to eq Pubnub::Configuration::DEFAULT_ORIGIN_HEARTBEAT_INTERVAL
      end

      it 'NONSUBSCRIBE_TIMEOUT_SECONDS' do
        expect(@pn.env[:non_subscribe_timeout].nil?).to eq false
        expect(@pn.env[:non_subscribe_timeout]).to eq Pubnub::Configuration::DEFAULT_NON_SUBSCRIBE_TIMEOUT
      end

      it 'ORIGIN_HEARTBEAT_INTERVAL_AFTER_FAILURE' do
        expect(@pn.env[:origin_heartbeat_interval_after_failure].nil?).to eq false
        expect(@pn.env[:origin_heartbeat_interval_after_failure]).to eq Pubnub::Configuration::DEFAULT_ORIG_INTERVAL_AFTER_F
      end

      it 'ORIGIN_HEARTBEAT_MAX_RETRIES' do
        expect(@pn.env[:origin_heartbeat_max_retries].nil?).to eq false
        expect(@pn.env[:origin_heartbeat_max_retries]).to eq Pubnub::Configuration::DEFAULT_ORIG_HEARTBEAT_MAX_RETRIES
      end
    end

    context 'from options' do
      before :all do
        @pn = Pubnub.new(
            subscribe_key: :demo,
            origins_pool: ['mercury.pubnub.com', 'venus.pubnub.com', 'earth.pubnub.com', 'mars.pubnub.com'],
            origin_heartbeat_interval: 832,
            non_subscribe_timeout: 921,
            origin_heartbeat_interval_after_failure: 299,
            origin_heartbeat_max_retries: 1000
        )
      end

      it 'ORIGINS_POOL' do
        expect(@pn.env[:origins_pool].nil?).to eq false
        expect(@pn.env[:origins_pool]).to eq ['mercury.pubnub.com', 'venus.pubnub.com', 'earth.pubnub.com', 'mars.pubnub.com']
      end

      it 'ORIGIN_HEARTBEAT_INTERVAL' do
        expect(@pn.env[:origin_heartbeat_interval].nil?).to eq false
        expect(@pn.env[:origin_heartbeat_interval]).to eq 832
      end

      it 'NONSUBSCRIBE_TIMEOUT_SECONDS' do
        expect(@pn.env[:non_subscribe_timeout].nil?).to eq false
        expect(@pn.env[:non_subscribe_timeout]).to eq 921
      end

      it 'ORIGIN_HEARTBEAT_INTERVAL_AFTER_FAILURE' do
        expect(@pn.env[:origin_heartbeat_interval_after_failure].nil?).to eq false
        expect(@pn.env[:origin_heartbeat_interval_after_failure]).to eq 299
      end

      it 'ORIGIN_HEARTBEAT_MAX_RETRIES' do
        expect(@pn.env[:origin_heartbeat_max_retries].nil?).to eq false
        expect(@pn.env[:origin_heartbeat_max_retries]).to eq 1000
      end
    end
  end

  context 'manages origins and subscribes' do
    before :each do
      @pn = Pubnub.new(
          subscribe_key: :demo,
          publish_key: :demo,
          origin_heartbeat_interval: 1,
          origin_heartbeat_max_retries: 0,
          origins_pool: ['geo1.devbuild.pubnub.com',
                         'geo2.devbuild.pubnub.com',
                         'geo3.devbuild.pubnub.com',
                         'geo4.devbuild.pubnub.com']
      )
    end

    it 'case#1' do

      VCR.use_cassette('origin-manager-500', :record => :none) do
        @pn.subscribe(channel: :quiet_please_im_testing_here){ |e| puts e }
        eventually do
          expect(@pn.env[:origins_pool].first).to eq 'geo2.devbuild.pubnub.com'
        end
        eventually do
          expect(@pn.env[:origins_pool].first).to eq 'geo1.devbuild.pubnub.com'
        end
      end

      VCR.use_cassette('origin-manager-invalid-json', :record => :none) do
        @pn.subscribe(channel: :quiet_please_im_testing_here){ |e| puts e }
        eventually do
          expect(@pn.env[:origins_pool].first).to eq 'geo2.devbuild.pubnub.com'
        end
        eventually do
          expect(@pn.env[:origins_pool].first).to eq 'geo1.devbuild.pubnub.com'
        end
      end
    end
  end
end
