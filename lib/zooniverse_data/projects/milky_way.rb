module ZooniverseData
  module Projects
    class MilkyWay
      include Helpers

      def customize_subject
        standard = convert_to_jpeg entry.location['standard']
        set_location standard: standard.path
      end
    end
  end
end
