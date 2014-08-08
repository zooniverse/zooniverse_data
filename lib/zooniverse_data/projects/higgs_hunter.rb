module ZooniverseData
  module Projects
    class HiggsHunter
      include Helpers

      def customize_subject
        new_locations = default_empty_locations
        entry.location['standard'].each do |image_path|
          standard_image = standard_image(image_path)
          new_locations['standard'] << standard_image
          thumbnail_image = converter_for(standard_image, type: 'thumbnail', max_size: 400)
          new_locations['thumbnail'] << thumbnail_image
        end
        set_location new_locations
      end

      private

      def standard_image(path)
        convert_image(path)
          .write_to(prefix: 'standard')
          .path
      end

      def converter_for(path, type: type, max_size: max_size)
        convert_image(path, remove_original: false)
          .resize(width: max_size, height: max_size, force: false)
          .quality(80)
          .write_to(prefix: type)
          .path
      end


      def default_empty_locations
        {
          'standard' => [],
          'thumbnail' => []
        }
      end
    end
  end
end
