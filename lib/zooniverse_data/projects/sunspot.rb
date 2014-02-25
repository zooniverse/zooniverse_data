module ZooniverseData
  module Projects
    class Sunspot
      include Helpers
      
      def customize_subject
        standard = convert_to_jpeg entry.location['standard']
        inverted = convert_image(standard.path, remove_original: false).invert.write_to(prefix: 'inverted')
        if entry.location['context']
          context_image = convert_to_jpeg(entry.location['context'])
          set_location standard: standard.path, inverted: inverted.path, context: context_image.try(:path)
        else
          set_location standard: standard.path, inverted: inverted.path
        end
      end
    end
  end
end
