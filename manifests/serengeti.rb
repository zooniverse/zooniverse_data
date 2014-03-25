require_relative 'manifest'

class Serengeti
  include Manifest
  attr_accessor :data
  
  def initialize
    self.data = { }
  end
  
  def prepare
    group name: 'season_7'
    load_data
    create_subjects
  end
  
  def load_data
    load_json(file_named('season7.json')).each do |hash|
      next if hash['include'] == 'exclude'
      hash['site_roll_code'] = "S7_#{ hash['site'] }_R#{ hash['roll'] }"
      key = "#{ hash['site_roll_code'] }_#{ hash['capture'] }"
      self.data[key] ||= { }
      self.data[key][hash['image']] = hash
    end
  end
  
  def create_subjects
    data.each do |key, capture|
      images = capture.values_at('1', '2', '3').compact
      locations = []
      filenames = []
      timestamps = []
      
      images.each do |image|
        locations << url_of(image['path'])
        filenames << File.basename(image['path'])
        timestamps << image['newtime']
      end
      
      subject group_name: 'season_7', location: locations, metadata: {
        capture_event_id: images.first['capture'].to_i,
        filenames: filenames,
        site_roll_code: images.first['site_roll_code'],
        timestamps: timestamps
      }
    end
  end
end

serengeti = Serengeti.create
