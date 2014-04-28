module ZooniverseData
  module Projects
    class Penguin
      include Helpers
      
      def customize_subject
        standard = convert_image(entry.location['standard'])
          .resize(width: 1_000, height: 1_000, force: false)
          .quality(80)
          .write_to(prefix: 'resized')
        
        set_location standard: standard.path
      end
    end
  end
end
