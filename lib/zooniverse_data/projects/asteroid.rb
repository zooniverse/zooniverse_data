module ZooniverseData
  module Projects
    class Asteroid
      include Helpers
      
      def customize_subject
        standard = []
        inverted = []
        
        entry.location['standard'].each do |location|
          standard << convert_to_png(location).path
          inverted << invert_image(location).path
        end
        
        set_location standard: standard, inverted: inverted
      end
    end
  end
end
