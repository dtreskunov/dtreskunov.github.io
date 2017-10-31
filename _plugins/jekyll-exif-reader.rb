require 'jekyll'
require 'exif'
require 'open-uri'

require_relative 'jekyll-cache'

module Jekyll
  class ExifReader
    DEFAULT_CONFIG = {
      'exif_cache_yml' => 'caches/gphoto_exif.yml',
    }

    def initialize(config)
      config = DEFAULT_CONFIG.merge(config)
      @cache = Cache.instance(config['exif_cache_yml'], 'EXIF') do |url|
        Exif::Data.new(open(url)).to_h
      end
    end

    def for_url(url)
      @cache.get(url)
    end
  end
end
