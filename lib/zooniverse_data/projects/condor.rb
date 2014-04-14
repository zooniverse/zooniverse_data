require 'ostruct'

module ZooniverseData
  module Projects
    class Condor
      include Helpers
      
      def customize_subject
        original = convert_image entry.location['standard']
        dimensions = original.input_image.size rescue OpenStruct.new(width: nil, height: nil)
        resized = original.resize(width: 1200, force: false)
          .quality(80)
          .write_to(prefix: 'resized')
          .path
        
        entry.update :$set => {
          'location.standard' => resized,
          'metadata.original_size' => {
            width: dimensions.width,
            height: dimensions.height
          }
        }
      end
    end
  end
end
