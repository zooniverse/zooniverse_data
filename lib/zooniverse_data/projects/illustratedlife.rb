module ZooniverseData
  module Projects
    class IllustratedLife
      include Helpers

      def customize_subject
        original = convert_image(entry.location['standard']).input_image
        original_dims = original.size rescue OpenStruct.new(width: nil, height: nil)
        resized = converter_for(original.path, type: 'standard', max_size: 1400)
        thumb = converter_for(original.path, type: 'thumbnail', max_size: 400, quality: 50)
        entry.update :$set => {
          'location.standard' => resized,
          'location.thumb' => thumb,
          'metadata.original_size' => { width: original_dims.width, height: original_dims.height }
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
