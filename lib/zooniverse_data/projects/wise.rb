module ZooniverseData
  module Projects
    class Wise
      include Helpers

      def customize_subject
        new_locations = {}

        entry.location['standard'].each do |path|
          image_type = path.match(/.*_(?<image_type>[a-zA-Z0-9]+)\.png$/)
          image_type = image_type[:image_type]
          new_locations[image_type] = path
        end

        if new_locations.key?('wise4')
          new_locations['standard'] = new_locations['wise4']
        end

        set_location new_locations
      end
    end
  end
end
