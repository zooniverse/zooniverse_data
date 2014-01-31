module ZooniverseData
  module Helpers
    extend ActiveSupport::Concern
    
    included do
      include Base
      include Transport
      include Images
    end
    
    autoload :Base,      'zooniverse_data/helpers/base'
    autoload :Transport, 'zooniverse_data/helpers/transport'
    autoload :Images,    'zooniverse_data/helpers/images'
  end
end
