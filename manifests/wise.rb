require_relative 'manifest'

class Wise
  include Manifest
  attr_accessor :data
  
  def prepare
    load_data
    create_subjects
  end
  
  def load_data
    self.data = load_json file_named('wise.json')
  end
  
  def create_subjects
    data.each do |h|
      subject location: locations_for(h), coords: h['coords'], metadata: h['metadata']
    end
  end
  
  def locations_for(hash)
    { }.tap do |locations|
      hash['location'].each do |path|
        image_type = path.match(/.*_(?<image_type>[a-zA-Z0-9]+)\.png$/)
        image_type = image_type[:image_type]
        locations[image_type] = path
      end
      locations['standard'] = locations['wise4']
    end
  end
end

Wise.create
