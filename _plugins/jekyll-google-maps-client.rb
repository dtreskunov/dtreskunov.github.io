require 'jekyll'
require 'httparty'

require_relative 'jekyll-cache'

module Jekyll
  class GoogleMapsClient
    DEFAULT_CONFIG = {
      'google_api_key_yml' => 'secrets/google_api_key.yml',
      'reverse_geocode_cache_yml' => 'caches/gphoto_reverse_geocode.yml',
    }

    include HTTParty

    base_uri 'https://maps.googleapis.com/maps/api'
    format :json

    def initialize(config)
      config = DEFAULT_CONFIG.merge(config)
      api_key_yml = config['google_api_key_yml']
      begin
        api_key = YAML.load_file(api_key_yml)
      rescue => e
        Jekyll.logger.error 'GPhoto:', "Google API key (required for geocoding) must be provided in `#{api_key_yml}`"
        raise
      end
      self.class.default_params key: api_key

      @reverse_geocode_cache = Cache.instance(config['reverse_geocode_cache_yml'], 'reverse geocode') do |lat_lng|
        response = self.class.get('/geocode/json', {query: {latlng: ("%f,%f" % lat_lng)}})
        code = response.code.to_i
        raise "invalid HTTP response code #{code}, body: #{response.body}" unless code == 200
        status = response.parsed_response['status']
        raise "invalid application response status #{status}, body: #{response.body}" unless status == 'OK'
        response.parsed_response['results']
      end
    end

    # returns a human-readable locality, e.g. "Seattle, WA" or "Milan, Lombardy, Italy"
    def reverse_geocode(lat, lng)
      # see https://developers.google.com/maps/documentation/geocoding/intro#ReverseGeocoding
      results = @reverse_geocode_cache.get([lat, lng])
      ac = results&.first&.[]('address_components')
      city    = ac&.find{|c| c['types'].include? 'locality'}&.[]('long_name')
      state   = ac&.find{|c| c['types'].include? 'administrative_area_level_1'}&.[]('short_name')
      country = ac&.find{|c| c['types'].include? 'country'}&.[]('long_name')

      "#{city}, #{state}#{country == 'United States' ? '' : ', ' + country}" if (city and state and country)
    end
  end
end
