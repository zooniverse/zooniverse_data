require_relative 'manifest'

class Asteroid
  include Manifest
  attr_accessor :sources
  
  def initialize
    self.sources = Hash.new{ |hash, key| hash[key] = { } }
  end
  
  def prepare
    find_grouped_files
    combine_sources
  end
  
  def combine_sources
    sources.each_pair do |id, sequence|
      lists = sequence.values_at 1, 2, 3, 4
      primary = lists.shift
      
      primary.each do |entry|
        locations = [entry['scaled_path']] + lists.collect do |list|
          list.select{ |item| item['crop'] == entry['crop'] }.first['scaled_path']
        end
        
        locations = locations.collect{ |file| url_of file }
        
        metadata = {
          id: id,
          cutout: {
            x: [entry['crop']['xmin'], entry['crop']['xmax']],
            y: [entry['crop']['ymin'], entry['crop']['ymax']]
          }
        }
        
        subject location: locations, metadata: metadata
      end
    end
  end
  
  def url_of(file)
    "http://s3.amazonaws.com/zooniverse-data/project_data/asteroid/#{ File.basename(file) }"
  end
  
  def parse_filename(file)
    _, id, index = File.basename(file).match(/(\d+_[\d\w]+)_(\d+)\.json/).to_a
    { id: id, index: index.to_i, file: file }
  end
  
  def find_grouped_files
    files(type: 'json').each do |file|
      parts = parse_filename file
      self.sources[parts[:id]][parts[:index]] = load_json(parts[:file])['processed_images']
    end
  end
end

Asteroid.create
