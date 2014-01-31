module ZooniverseData
  module Helpers
    module Base
      extend ActiveSupport::Concern
      
      included do
        attr_accessor :manifest
        attr_accessor :entry
      end
      
      def customize(manifest: manifest, entry: entry)
        self.manifest = manifest
        self.entry = entry
        
        if entry.subject?
          customize_subject
        elsif entry.group?
          customize_group
        end
      end
      
      def customize_subject
        
      end
      
      def customize_group
        
      end
      
      def each_location
        new_locations = { }
        entry.location.each_pair do |key, value|
          new_locations[key] = if value.is_a?(Array)
            value.collect do |location|
              _new_location_from yield(key, location)
            end
          else
            _new_location_from yield(key, value)
          end
        end
        
        set_location new_locations
      end
      
      def set_location(hash)
        entry.update :$set => { location: hash }
      end
      
      def _new_location_from(result)
        result.respond_to?(:path) ? result.path : result
      end
    end
  end
end
