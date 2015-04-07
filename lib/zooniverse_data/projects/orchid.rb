module ZooniverseData
  module Projects
    class Orchid
      include Helpers

      def customize_subject
        original = convert_image(entry.location['standard']).input_image
        thumb = converter_for(original.path, type: 'thumbnail', max_size: 300, quality: 50)
        entry.update :$set => {
          'location.thumb' => thumb,
        }
      end

      private

        def converter_for(path, type: type, max_size: max_size, quality: 80)
          convert_image(path, remove_original: false)
            .resize(width: max_size, height: max_size, force: false)
            .quality(quality)
            .write_to(prefix: type)
            .path
        end
    end
  end
end
