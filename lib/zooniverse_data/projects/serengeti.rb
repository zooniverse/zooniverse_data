module ZooniverseData
  module Projects
    class Serengeti
      include Helpers

      def customize_subject
        new_locations = {
          'standard' => [],
          'thumbnail' => [],
          'large' => []
        }

        entry.location['standard'].each do |path|
          large_image = large_converter path
          new_locations['large'] << large_image
          new_locations['standard'] << converter_for(large_image, type: 'standard', max_size: 600)
          new_locations['thumbnail'] << converter_for(large_image, type: 'thumbnail', max_size: 300)
        end

        set_location new_locations
      end

      def large_converter(path)
        convert_image(path)
          .write_to(prefix: 'large')
          .path
      end

      def converter_for(path, type: nil, max_size: nil)
        convert_image(path, remove_original: false)
          .resize(width: max_size, height: max_size, force: false)
          .quality(80)
          .write_to(prefix: type)
          .path
      end
    end
  end
end
