require_relative 'manifest'
require 'bson'
require 'active_support/core_ext'
require 'active_support/time'
Time.now.utc.to_json # hack: lazy loading issue?

class Serengeti
  include Manifest
  attr_accessor :by_site_and_roll, :grouped_data
  
  def initialize
    self.by_site_and_roll = { }
    self.grouped_data = { }
  end
  
  def prepare
    load_data
    sort_images
    group_capture_events
    sort_grouped_events
    group name: 'season_7'
    create_subjects
  end
  
  def load_data
    files = load_json file_named 'season7_sample.json'
    files.each do |hash|
      site, roll = hash['file'].match(/S7\/(\w+)_(\w+)\//)[1..2]
      hash['site'] = site
      hash['roll'] = roll
      
      self.by_site_and_roll[site] ||= { }
      self.by_site_and_roll[site][roll] ||= []
      self.by_site_and_roll[site][roll] << hash
    end
  end
  
  def sort_images
    by_site_and_roll.each_pair do |site, rolls|
      rolls.each_pair do |roll, images|
        self.by_site_and_roll[site][roll] = images.sort do |a, b|
          a_key = a['date_time']
          b_key = b['date_time']
          
          if a_key && b_key
            Time.parse(a_key) <=> Time.parse(b_key)
          elsif a_key
            -1
          elsif b_key
            1
          else
            File.basename(a['file']) <=> File.basename(b['file'])
          end
        end
      end
    end
  end
  
  def group_capture_events
    minimum_date = Time.parse('2011-11-1 0:0:0 UTC')
    
    by_site_and_roll.each_pair do |site, rolls|
      rolls.each_pair do |roll, images|
        images.each.with_index do |hash, i|
          next if hash['capture_event_id']
          hash['capture_event_id'] = id = BSON::ObjectId.new.to_s
          
          self.grouped_data[id] ||= []
          self.grouped_data[id] << hash
          
          date = Time.parse hash.fetch('date_time', Time.at(0).to_s)
          next if date < minimum_date
          
          images[i + 1 .. i + 2].each do |other|
            other_date = Time.parse other.fetch('date_time', Time.at(0).to_s)
            within_range = other_date > date - 1.second && other_date < date + 1.second
            not_source = other['file'] != hash['file']
            
            if within_range && not_source
              other['capture_event_id'] = id
              self.grouped_data[id] << other
            end
          end
        end
      end
    end
  end
  
  def sort_grouped_events
    grouped_data.each_pair do |id, images|
      self.grouped_data[id] = images.sort do |a, b|
        a['file'] <=> b['file']
      end
    end
  end
  
  def create_subjects
    grouped_data.each do |id, images|
      hash = {
        location: [],
        filenames: [],
        timestamps: []
      }
      
      images.each.with_index do |image, i|
        hash[:location] << url_of(image['file'].sub('/home/packerc/shared/S7/', ''))
        hash[:filenames] << File.basename(image['file'])
        hash[:timestamps] << Time.parse(image['date_time']).utc.as_json
      end
      
      subject group_name: 'season_7', location: hash[:location], metadata: {
        capture_event_id: id,
        filenames: hash[:filenames],
        site_roll_code: "S7_#{ images.first['site'] }_#{ images.first['roll'] }",
        timestamps: hash[:timestamps]
      }
    end
  end
end

Serengeti.create
