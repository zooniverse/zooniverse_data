require_relative 'manifest'

class Penguin
  include Manifest

  def prepare
    # penguin_files.json loads from ./data/penguin/penguin_files.json
    load_json(file_named('penguin_files.json')).each do |hash|
      # where hash['path'] is a relative path to the image.
      #   given "/Volumes/DriveName/Site/Folder/Image123.jpg"
      #   hash['path'] would be "Site/Folder/Image123.jpg"
      subject location: url_of(hash['path']), metadata: {
        path: hash['path'],
        index: hash['index'],
        timestamp: hash['timestamp'],
        lunar_phase: hash['lunar_phase'],
        temperature_f: hash['temperature_f']
      }
    end
  end
end

Penguin.create
