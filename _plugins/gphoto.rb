require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'picasa'
require 'shellwords'
require 'deep_merge'
require 'exif'
require 'open-uri'
require 'yaml'

# Google responds with incorrect encoding if a User-Agent containing "gzip" is used
# BAD: ruby-gem-picasa-v0.9.1 (gzip)
# BAD: gzip
# GOOD: foo (blah)
# GOOD: ruby-gem-picasa-v0.9.1
# GOOD: foo
# GOOD: <none>
#
# https://github.com/morgoth/picasa/issues/41
Picasa::HTTP.instance_variable_get(:@default_options)[:headers]['User-Agent'].sub!(/ \(gzip\)/, '')

module GooglePhotos
  class Auth
    OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
    SCOPE = 'https://picasaweb.google.com/data/'

    attr_reader :user_id

    def initialize(user_id, client_secrets_json, tokens_yml)
      @user_id = user_id
      @client_secrets_json = client_secrets_json
      @tokens_yml = tokens_yml
    end

    def access_token
      @credentials ||= credentials
      @credentials.refresh! if @credentials.expired?
      @credentials.access_token
    end

    private

    def credentials
      client_id = Google::Auth::ClientId.from_file(@client_secrets_json)
      token_store = Google::Auth::Stores::FileTokenStore.new(:file => @tokens_yml)
      authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)

      credentials = authorizer.get_credentials(@user_id)
      if credentials.nil?
        url = authorizer.get_authorization_url(base_url: OOB_URI )
        puts "Open the following URL in your browser and enter the resulting code:\n\n#{url}"
        code = gets
        credentials = authorizer.get_and_store_credentials_from_code(
          user_id: @user_id, code: code, base_url: OOB_URI)
      end
      credentials
    end
  end
end

module Jekyll
  module GPhoto
    DEFAULT_CONFIG = {
      'client_secrets_json' => 'secrets/gphoto_client_secrets.json',
      'tokens_yml' => 'secrets/gphoto_tokens.yml',
      'exif_cache_yml' => 'caches/gphoto_exif.yml'
    }

    ERR_EMAIL = "Specify `gphoto.email` in _config.yml"
    ERR_CLIENT_SECRETS = <<-EOS
Login to Google API Console to register an app and create OAuth client_id and client_secret.
Then click on `DOWNLOAD JSON` and save the file to %s. This path comes from _config.yml
key `gphoto.client_secrets_json`.

https://console.developers.google.com/apis/credentials
EOS

    class PicasaClient < Picasa::Client
      def initialize(config)
        config = DEFAULT_CONFIG.merge(config)
        email = config['email']
        client_secrets_json = File.expand_path(config['client_secrets_json'])
        tokens_yml = File.expand_path(config['tokens_yml'])

        raise ERR_EMAIL if email.nil?
        raise (ERR_CLIENT_SECRETS % client_secrets_json) unless File.file? client_secrets_json
        FileUtils.mkdir_p(File.dirname tokens_yml)

        auth = GooglePhotos::Auth.new(email, client_secrets_json, tokens_yml)

        super(user_id: email, access_token: auth.access_token)
      end
    end

    class ExifReader
      def initialize(config)
        config = DEFAULT_CONFIG.merge(config)
        @filename = config['exif_cache_yml']
        begin
          FileUtils.mkdir_p File.dirname(@filename)
          @cache = YAML.load_file(@filename)
          Jekyll.logger.debug 'GPhoto:', "Loaded EXIF cache from `#{@filename}`"
        rescue => e
          Jekyll.logger.debug 'GPhoto:', "Could not load EXIF cache from `#{@filename}` - cache will be empty"
          @cache = {}
        end

        Jekyll::Hooks.register :site, :post_write do
          save_cache
        end
      end

      def for_url(url)
        if @cache.include? url
          Jekyll.logger.debug 'GPhoto:', "Using cached EXIF for image #{url}"
          exif = @cache[url]
        else
          begin
            exif = Exif::Data.new(open(url)).to_h
            Jekyll.logger.debug 'GPhoto:', "Successfully fetched EXIF for image #{url}"
            @cache[url] = exif
          rescue => e
            Jekyll.logger.warn 'GPhoto:', "Error fetching EXIF for image #{url}: #{e}"
          end
        end
        exif
      end

      private
      def save_cache
        open(@filename, 'w') do |file|
          file.write(YAML.dump(@cache))
        end
        Jekyll.logger.debug 'GPhoto:', "Saved EXIF cache to #{@filename}"
      end
    end

    class Generator < ::Jekyll::Generator
      PHOTO_REGEX = /\.(jpg|jpeg|gif|png)$/i
      VIDEO_REGEX = /\.(mp4|mov|mkv)$/i

      def generate(site)
        config = site.config['gphoto']
        picasa_client = PicasaClient.new(config)
        exif_reader = ExifReader.new(config)

        groups = (site.pages + site.posts.docs).group_by {|doc| doc.data['gphoto_album']}.reject {|k, _| k.nil?}
        return if groups.empty?
        all_albums = picasa_client.album.list.entries

        groups.each do |album_search_str, docs|
          album_id = find_album_id(all_albums, album_search_str)
          unless album_id
            Jekyll.logger.warn 'GPhoto:', "album matching `#{album_search_str}` not found"
            next
          end
          album = picasa_client.album.show(album_id, imgmax: 'd', thumbsize: '400,800,1600')
          docs.each do |doc|
            album_data = get_album_data(album, exif_reader)
            cover_entry = album_data['entries'].find {|e| e['caption'].include? '#cover'}

            doc.data.deep_merge!({'gphoto_album_data' => album_data})
            doc.data['header'] = (doc.data['header'] || {}).dup
            doc.data.deep_merge!({'header' => {'overlay_image' => cover_entry['thumbnails'].last['url']}}) if cover_entry
          end
        end
      end

      private
      def find_album_id(albums, search_str)
        album = albums.find do |album|
          album.title.upcase.gsub(/\W/, '').include? search_str.upcase.gsub(/\W/, '')
        end
        album&.id
      end

      def get_album_data(album, exif_reader)
        {'entries' => album.entries.map {|entry|
           contents = Picasa::Utils.safe_retrieve(entry.parsed_body, 'media$group', 'media$content')
           best = contents.max_by{|i|i['width']}

           exif_data = exif_reader.for_url(best['url']) if best['medium'] == 'image'

           exif = "#{entry.exif.make} #{entry.exif.model}"
           exif += " f/#{entry.exif.fstop}" if entry.exif.fstop
           exif += " 1/#{'%.0f' % (1 / entry.exif.exposure)}" if entry.exif.exposure
           exif += " ISO#{entry.exif.iso}" if entry.exif.iso

           raw_thumbnails = Picasa::Utils.safe_retrieve(entry.parsed_body, 'media$group', 'media$thumbnail')
           thumbnails = raw_thumbnails.map{|i|content_item(i)}.sort_by{|i|i['width']}

           srcset = thumbnails.map{|t| "#{t['url']} #{t['width']}w"}.join(',')

           stream_id = Picasa::Utils.safe_retrieve(entry.parsed_body, 'gphoto$streamId')&.first&.[]('$t')
           photosphere = ('photosphere' == stream_id)

           {'raw' => entry.parsed_body,
            'raw_debug' => JSON.pretty_unparse(entry.parsed_body),
            'best' => content_item(best),
            'exif' => exif,
            'thumbnails' => thumbnails,
            'srcset' => srcset,
            'title' => entry.media.title,
            'caption' => entry.media.description,
            'photosphere' => photosphere}
         }}
      end

      def content_item(raw_item)
        {'url' => raw_item['url'],
         'height' => raw_item['height'],
         'width' => raw_item['width'],
         'type' => raw_item['type'],
         'medium' => raw_item['medium']
        }
      end
    end
  end
end
