require_relative 'manifest'

class HiggsHunter
  include Manifest

  def prepare
    load_json(file_named('higgs_hunter_files.json')).each do |subject_entry|
      image_locations = construct_image_locations(subject_entry["image_metadata"])
      subject location: image_locations, metadata: subject_entry
    end
  end

  private

  def construct_image_locations(image_metadata)
    file_names = image_metadata.map do |image_set|
      image_set.select { |k,v| k.to_s.match(/name/i) }.values
    end
    file_names.flatten.map { |file_name| url_of(file_name) }
  end
end

HiggsHunter.create
