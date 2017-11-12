require 'yaml'
require 'strava/api/v3'

require_relative 'jekyll-cache'

module Jekyll
  class StravaClient
    DEFAULT_CONFIG = {
      'strava_yml' => 'secrets/strava.yml',
      'strava_activities_cache_yml' => 'caches/strava_activities.yml'
    }

    def initialize(config)
      config = DEFAULT_CONFIG.merge(config)
      begin
        strava_config = YAML.load_file(config['strava_yml'])
        access_token = strava_config['access_token']
        raise 'access_token is not defined' if access_token.nil?
        @client = Strava::Api::V3::Client.new(access_token: access_token)
      rescue => e
        raise "Unable to initialize Strava client. Check `#{config['strava_yml']}`. Error: #{e}"
      end
      @activities_cache = Cache.instance(config['strava_activities_cache_yml'], 'Strava activities') do |id|
        begin
          @client.retrieve_an_activity(id)
        rescue Strava::Api::V3::ClientError => e
          e.http_status.to_s == '404' ? nil : raise
        end
      end
    end

    def get_activity(id)
      @activities_cache.get(id)
    end

    # ids of activities whose start_date_local is on specified date
    def get_activity_ids_by_date(date)
      after = date.to_time.utc - 24*60*60
      before = date.to_time.utc + 24*60*60
      day = date.to_time.utc.day
      @client.list_athlete_activities(after: after, before: before).select do |activity|
        start_date_local = DateTime.parse(activity['start_date_local']).to_time.utc
        day == start_date_local.day
      end.map do |activity|
        activity['id']
      end
    end
  end
end
