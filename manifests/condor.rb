require_relative 'manifest'

class Condor
  include Manifest
  attr_accessor :data
  
  def prepare
    load_data
    create_subjects
  end
  
  def load_data
    self.data = load_json file_named('condor.json')
  end
  
  def create_subjects
    data.each do |h|
      file = h['file'].match(/\"(.*)\"/)[1]
      subject location: url_of(file), metadata: {
        file: file,
        taken_at: parse_time(h['taken_at']),
        file_timestamp: parse_time(h['file_timestamp']),
        exif_timestamp: parse_time(h['exif_timestamp'])
      }
    end
  end
  
  def parse_time(t)
    t && Time.parse(t)
  end
end

Condor.create
