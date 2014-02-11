require_relative 'manifest'

class MilkyWay
  include Manifest
  
  def prepare
    file_list = load_json file_named 'round_2_list.json'
    file_list.each do |file|
      _, group_name, size, file_name = file.match(/([\.\+\-\w]+)\/([\.\+\-\w]+?)(?:_jpgs)?\/([\.\+\-\w]+\.jpg)/).to_a
      coords = file_name.match(/\w*?([\d\.]+)((\-|\+)[\d\.]+)\w*?/)[1..2].collect &:to_f
      
      group name: group_name
      subject group_name: group_name, location: url_of(file.gsub('+', '%2B')), coords: coords, metadata: { size: size, file_name: file_name }
    end
  end
end

MilkyWay.create
