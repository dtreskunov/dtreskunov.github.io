require_relative 'jekyll-strava-client'

module Jekyll
  class StravaGenerator < Generator
    TEMPLATE_INCLUDE = "\n\n{% include strava.html %}"

    def generate(site)
      strava_client = StravaClient.new(site.config['strava'] || {})

      (site.pages + site.posts.docs).each do |doc|
        ids =
          case doc.data['strava']
          when true
            strava_client.get_activity_ids_by_date(doc.data['date'])
          when Integer
            [doc.data['strava']]
          when Array
            doc.data['strava']
          else
            []
          end
        doc.data['strava_activities'] = ids.map{|id| strava_client.get_activity(id)}.compact
        unless doc.data['strava_activities'].empty?
          doc.data['tags'] << 'Strava'
          doc.content += TEMPLATE_INCLUDE unless doc.content.include? TEMPLATE_INCLUDE
        end
      end
    end
  end
end
