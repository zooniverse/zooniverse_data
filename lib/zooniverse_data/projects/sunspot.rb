module ZooniverseData
  module Projects
    class Sunspot
      include Helpers
      
      def customize_subject
        standard_path = entry.location['standard']
        standard_jpg_path = standard_path.sub '.eps', '.jpg'
        
        standard = convert_image(standard_path).resize(width: 360, height: 360, force: true).write_to path: standard_jpg_path
        inverted = convert_image(standard.path, remove_original: false).invert.write_to prefix: 'inverted'
        
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
