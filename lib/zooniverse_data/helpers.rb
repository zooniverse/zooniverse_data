module ZooniverseData
  module Helpers
    extend ActiveSupport::Concern
    
    included do
      include Base
      include Transport
      include Images
    end
    
    require 'zooniverse_data/helpers/base'
    require 'zooniverse_data/helpers/transport'
    require 'zooniverse_data/helpers/images'
  end
end
