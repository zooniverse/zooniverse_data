require_relative 'manifest'

class Serengeti
  include Manifest
  attr_accessor :data, :sites
  
  def initialize
    self.data = { }
    self.sites = load_json(file_named('sites.json'))
  end
  
  def prepare
    group name: 'season_8'
    load_data
    create_subjects
  end
  
  def load_data
    load_json(file_named('season8.json')).each do |hash|
      next if hash['invalid'] == '1'
      hash['site_roll_code'] = "S8_#{ hash['site'] }_R#{ hash['roll'] }"
      key = "#{ hash['site_roll_code'] }_#{ hash['capture'] }"
      hash['newtime'] = timestamp_of hash['newtime']
      self.data[key] ||= { }
      self.data[key][hash['image']] = hash
    end
  end
  
  def create_subjects
    data.each do |key, capture|
      images = capture.values_at('1', '2', '3').compact
      coords = sites[images.first['site']] || []
      locations = []
      filenames = []
      timestamps = []
      
      images.each do |image|
        locations << url_of(image['path'])
        filenames << File.basename(image['path'])
        timestamps << image['newtime']
      end
      
      subject group_name: 'season_8', location: locations, coords: coords, metadata: {
        capture_event_id: images.first['capture'].to_i,
        filenames: filenames,
        site_roll_code: images.first['site_roll_code'],
        timestamps: timestamps
      }
    end
  end
  
  def timestamp_of(timestamp)
    date, time = timestamp.split ' '
    month, day, year = date.split '/'
    Time.parse("#{ year }-#{ month }-#{ day } #{ time } +0300").utc
  end
end

serengeti = Serengeti.create
