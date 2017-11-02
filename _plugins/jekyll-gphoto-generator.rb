require 'deep_merge'
require 'yaml'

require_relative 'jekyll-google-maps-client'
require_relative 'jekyll-exif-reader'
require_relative 'jekyll-picasa-client'

module Jekyll
  class GPhotoGenerator < Generator
    TEMPLATE_INCLUDE = "\n{% include gphoto_album.html %}"

    def generate(site)
      config = site.config['gphoto']
      picasa_client = PicasaClient.new(config)
      exif_reader = ExifReader.new(config)
      gmaps_client = GoogleMapsClient.new(config)

      groups = (site.pages + site.posts.docs).group_by {|doc|
        search = doc.data['gphoto_album']
        search == true ?
          doc.data['title'] :
          search
      }.reject {|search, _|
        search.nil?
      }
      return if groups.empty?
      all_albums = select_accessible_entries picasa_client.album.list.entries
      #all_albums = picasa_client.album.list({'max-results' => 9999999}).entries
      #File.open("#{site.dest}/gphoto_albums.yml", 'w') do |f|
      #  f.write YAML.dump(all_albums)
      #  Jekyll.logger.debug 'GPhoto:', "Writing album metadata to #{f.path}"
      #end

      groups.each do |album_search_str, docs|
        album_id = find_album_id(all_albums, album_search_str)
        unless album_id
          Jekyll.logger.warn 'GPhoto:', "album matching `#{album_search_str}` not found - try
going to `Sharing options`, unsharing, and then resharing the album. Make sure it shows up
for you when you go to http://picasaweb.google.com"
          next
        end
        album = picasa_client.album.show(album_id, imgmax: 'd', thumbsize: '100c,400,800,1600')
        docs.each do |doc|
          album_data = get_album_data(album, exif_reader, gmaps_client)
          doc.data['tags'] += get_tags(album_data)
          doc.data['locality'] ||= common_val(album_data['entries'], 'locality')

          doc.data['gphoto_album_data'] = album_data
          doc.data['gphoto_album_data_yml'] = YAML.dump album_data
          # doc.data['gphoto_raw_album_yml'] = YAML.dump album.parsed_body
          doc.data['header'] = (doc.data['header'] || {}).dup
          doc.data['header']['overlay_image'] ||= get_cover_image_url(album_data)
          doc.content += TEMPLATE_INCLUDE unless doc.content.include? TEMPLATE_INCLUDE
        end
      end
    end

    private
    def get_cover_image_url(album_data)
      entry = album_data['entries'].find {|e| e['caption'].include? '#cover'}
      if entry
        image = entry['images'].find{|i|i['width'] > 800} || entry['images'].last
        image['url']
      end
    end

    def get_tags(album_data)
      media = album_data['entries'].map do |entry|
        case entry['best']['medium']
        when 'video'
          'Video'
        when 'image'
          if entry['photosphere']
            'PhotoSphere'
          else
            'Photo'
          end
        end
      end
      localities = album_data['entries'].map do |entry|
        (entry['locality'] || '').split(', ')
      end.flatten
      (localities + media).uniq
    end

    def select_accessible_entries(entries)
      entries.select {|entry| entry.access == 'public' || entry.access == 'protected'}
    end

    def common_val(hashes, key)
      set = Set.new(hashes.map{|h| h[key]}.reject(&:nil?))
      set.size == 1 ? set.first : nil
    end

    def find_album_id(albums, search_str)
      album = albums.find do |album|
        album.title.upcase.gsub(/\W/, '').include? search_str.upcase.gsub(/\W/, '')
      end
      album&.id
    end

    def get_album_data(album, exif_reader, gmaps_client)
      geo_json_features = []
      template_entries = []
      album.entries.each do |entry|
        contents = Picasa::Utils.safe_retrieve(entry.parsed_body, 'media$group', 'media$content')
        thumbnails = Picasa::Utils.safe_retrieve(entry.parsed_body, 'media$group', 'media$thumbnail')

        images = (thumbnails + contents.select{|i|i['medium'] == 'image'}).sort_by{|i|i['width']}
        videos = contents.select{|i|i['medium'] == 'video'}.sort_by{|i|i['width']}

        srcset = images.map{|i| "#{i['url']} #{i['width']}w"}.join(',')

        icon = images.first
        best = videos.last || images.last
        best_is_image = (best['medium'] == 'image')

        raw_exif = best_is_image ? exif_reader.for_url(best['url']) : {}

        unless raw_exif.empty?
          lat, lng = exif_to_lat_lng(raw_exif)
          unless lat.nil? or lng.nil?
            locality = gmaps_client.reverse_geocode(lat, lng)
            geo_json_features << {
              'type' => 'Feature',
              'geometry' => {
                'type' => 'Point',
                'coordinates' => [lng, lat]
              },
              'properties' => {
                'id' => entry.id,
                'icon' => icon['url']
              }
            }
          end
        end

        exif = {
          'make' => (raw_exif.dig :ifd0, :make),
          'model' => (raw_exif.dig :ifd0, :model),
          'fstop' =>
          begin
            f = (raw_exif.dig :exif, :fnumber)
            ("f/%.1f" % f) if f
          end,
          'exposure' =>
          begin
            t = (raw_exif.dig :exif, :exposure_time)
            format_exposure_time(t) if t
          end,
          'iso' =>
          begin
            i = (raw_exif.dig :exif, :iso_speed_ratings)
            ("ISO %s" % i) if i
          end
        }

        type =
          begin
            stream_id = Picasa::Utils.safe_retrieve(entry.parsed_body, 'gphoto$streamId')&.first&.[]('$t')
            if stream_id == 'photosphere'
              'photosphere'
            else
              best['medium']
            end
          end

        template_entries << {
          'id' => entry.id,
          'geo_json_id' => entry.id,
          'type' => type,
          'best' => best,
          'aspect_ratio' => best['height'] / best['width'].to_f,
          'exif' => exif,
          'images' => images.size > 1 ? images[1..-1] : images, # first image is a tiny icon
          'srcset' => srcset,
          'title' => entry.media.title,
          'caption' => entry.media.description,
          'locality' => locality
        }
      end

      geo_json = {
        'type' => 'FeatureCollection',
        'features' => geo_json_features
      }

      return {
        'id' => album.id,
        'entries' => template_entries,
        'geo_json' => geo_json
      }
    end

    def format_exposure_time(t)
      t < 1 ?
        '1/%.0f' % (1/t) :
        '%.0fs' % t
    end

    def dms_to_f(deg, min, sec, ref)
      sign = (ref == 'S' or ref == 'W') ? -1.0 : 1.0
      sign * (deg + (min / 60) + (sec / 3600))
    end

    def exif_to_lat_lng(exif)
      if exif[:gps].empty?
        nil
      else
        [dms_to_f(*(exif.dig :gps, :gps_latitude), (exif.dig :gps, :gps_latitude_ref)),
         dms_to_f(*(exif.dig :gps, :gps_longitude), (exif.dig :gps, :gps_longitude_ref))]
      end
    end
  end
end
