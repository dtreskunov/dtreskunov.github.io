require 'deep_merge'
require 'yaml'

require_relative 'jekyll-google-maps-client'
require_relative 'jekyll-exif-reader'
require_relative 'jekyll-picasa-client'

module Jekyll
  class GPhotoGenerator < Generator
    TEMPLATE_INCLUDE = '{% include gphoto_album.html %}'

    def generate(site)
      config = site.config['gphoto']
      picasa_client = PicasaClient.new(config)
      exif_reader = ExifReader.new(config)
      gmaps_client = GoogleMapsClient.new(config)

      groups = (site.pages + site.posts.docs).group_by {|doc| doc.data['gphoto_album']}.reject {|k, _| k.nil?}
      return if groups.empty?
      all_albums = select_accessible_entries picasa_client.album.list.entries

      groups.each do |album_search_str, docs|
        album_id = find_album_id(all_albums, album_search_str)
        unless album_id
          Jekyll.logger.warn 'GPhoto:', "album matching `#{album_search_str}` not found"
          next
        end
        album = picasa_client.album.show(album_id, imgmax: 'd', thumbsize: '100c,400,800,1600')
        docs.each do |doc|
          album_data = get_album_data(album, exif_reader, gmaps_client)
          doc.data['tags'] += get_tags(album_data)
          doc.data['locality'] ||= common_val(album_data['entries'], 'locality')

          cover_entry = album_data['entries'].find {|e| e['caption'].include? '#cover'}

          doc.data['gphoto_album_data'] = album_data
          doc.data['gphoto_album_data_yml'] = YAML.dump album_data
          # doc.data['gphoto_raw_album_yml'] = YAML.dump album.parsed_body
          doc.data['header'] = (doc.data['header'] || {}).dup
          doc.data.deep_merge!({'header' => {'overlay_image' => cover_entry['thumbnails'].last['url']}}) if cover_entry
          doc.content += TEMPLATE_INCLUDE unless doc.content.include? TEMPLATE_INCLUDE
        end
      end
    end

    private
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
        raw_thumbnails = Picasa::Utils.safe_retrieve(entry.parsed_body, 'media$group', 'media$thumbnail')
        thumbnails = raw_thumbnails[1..-1].map{|i|content_item(i)}.sort_by{|i|i['width']}
        icon = content_item raw_thumbnails[0]

        contents = Picasa::Utils.safe_retrieve(entry.parsed_body, 'media$group', 'media$content')
        videos = contents.select{|i|i['medium']=='video'}
        best = videos.max_by{|i|i['width']} || contents.max_by{|i|i['width']}

        exif_data = best['medium'] == 'image' ?
                      exif_reader.for_url(best['url']) :
                      {}
        unless exif_data.empty?
          lat, lng = exif_to_lat_lng(exif_data)
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

        exif_arr = []
        exif_arr << (exif_data.dig :ifd0, :make) if (exif_data.dig :ifd0, :make)
        exif_arr << (exif_data.dig :ifd0, :model) if (exif_data.dig :ifd0, :model)
        exif_arr << ("f/%.1f" % (exif_data.dig :exif, :fnumber)) if (exif_data.dig :exif, :fnumber)
        exif_arr << format_exposure_time(exif_data.dig :exif, :exposure_time) if (exif_data.dig :exif, :exposure_time)
        exif_arr << ("ISO %s" % (exif_data.dig :exif, :iso_speed_ratings)) if (exif_data.dig :exif, :iso_speed_ratings)
        exif = exif_arr.join ' '

        srcset = thumbnails.map{|t| "#{t['url']} #{t['width']}w"}.join(',')

        stream_id = Picasa::Utils.safe_retrieve(entry.parsed_body, 'gphoto$streamId')&.first&.[]('$t')
        photosphere = ('photosphere' == stream_id)

        template_entries << {
          'id' => entry.id,
          'geo_json_id' => entry.id,
          'best' => content_item(best),
          'exif' => exif,
          'thumbnails' => thumbnails,
          'srcset' => srcset,
          'title' => entry.media.title,
          'caption' => entry.media.description,
          'photosphere' => photosphere,
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
        'geo_json' => JSON.unparse(geo_json)
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

