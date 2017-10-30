require 'jekyll'
require 'yaml'

module Jekyll
  class Cache
    LOG_ID = 'jekyll-cache.rb:'
    
    def initialize(filename, description, &fetcher)
      @filename = filename
      @description = description
      @fetcher = fetcher
      begin
        FileUtils.mkdir_p File.dirname(@filename)
        @cache = YAML.load_file(@filename)
        raise "YAML.load_file returned false - is the file empty?" unless @cache
        Jekyll.logger.debug LOG_ID, "Loaded #{@description} cache from `#{@filename}`"
      rescue => e
        Jekyll.logger.debug LOG_ID, "Could not load #{@description} cache from `#{@filename}` - cache will be empty"
        @cache = {}
      end

      Jekyll::Hooks.register :site, :post_write do
        save_cache
      end
    end

    def get(key)
      if @cache.include? key
        Jekyll.logger.debug LOG_ID, "Using cached #{@description} for key #{key}"
        val = @cache[key]
      else
        begin
          val = @fetcher.call(key)
          Jekyll.logger.debug LOG_ID, "Successfully fetched #{@description} for key #{key}"
          @cache[key] = val
        rescue => e
          Jekyll.logger.warn LOG_ID, "Error fetching #{@description} for key #{key}: #{e}"
        end
      end
      val
    end

    private
    def save_cache
      open(@filename, 'w') do |file|
        file.write(YAML.dump(@cache))
      end
      Jekyll.logger.debug LOG_ID, "Saved #{@description} cache to #{@filename}"
    end
  end
end
