require_relative 'manifest'

# Break up the data into batches
BATCH = (2_500...3_000)

class Asteroid
  include Manifest
  attr_accessor :data, :grouped_images, :ephm_data, :subject_data
  
  def initialize
    Aws.config.update({
      access_key_id: ENV['ASTEROID_S3_ACCESS_ID'],
      secret_access_key: ENV['ASTEROID_SECRET_ACCESS_KEY']
    })
    @ephm_matcher = Regexp.new(/(((?:")([^"]+)"\s*)|((\S+)\s*?))/)
    @coords_matcher = Regexp.new(/->\s*([-\d\.]+)\s+([-\d\.]+)/)
    @base_url = 'http://asteroidzoo.s3.amazonaws.com'
    
    self.data = { }
    self.ephm_data = { }
    self.grouped_images = { }
    self.subject_data = []
  end
  
  def prepare
    identify_groups
    prepare_images
    identify_knowns
    create_groups
    create_subjects
  end
  
  def identify_groups
    json_files = Dir['data/asteroid/files/**/*.json'].sort
    json_files.each do |json_file|
      json_name = File.basename json_file
      i, date, id, index = json_name.split '_'
      name = "#{ i }_#{ date }_#{ id }"
      
      self.data[name] ||= []
      self.data[name] << json_file
      self.data[name] = data[name].sort
    end; nil
  end
  
  def prepare_images
    self.data = data.to_a[BATCH]
    total = data.length
    i = 0
    data.each do |name, files|
      puts "#{ i += 1 } / #{ total }"
      files.each do |file|
        json = JSON.parse File.read file
        base_name = File.basename(file).sub File.extname(file), ''
        
        fits_path = json['original_path']
        local_fits = "data/asteroid/fits/#{ File.basename(fits_path) }"
        has_fits = false
        
        begin
          download(from: fits_path, to: local_fits) unless File.exists?(local_fits)
          has_fits = true
        rescue => e
          puts "rescued #{ e.message }"
        end
        
        ephm_path = fits_path.sub /_\d{4}\.arch.H/, '_0001.ephm'
        local_ephm = "data/asteroid/ephm/#{ File.basename(ephm_path) }"
        has_ephm = false
        
        begin
          download(from: ephm_path, to: local_ephm) unless File.exists?(local_ephm)
          self.ephm_data[name] ||= parse_ephm local_ephm
          has_ephm = true
        rescue => e
          puts "rescued #{ e.message }"
        end
        
        json['processed_images'].each do |hash|
          pos = hash['crop']
          key = "#{ pos['xmin'].round }-#{ pos['ymin'].round }"
          grouped_images[name] ||= { }
          grouped_images[name][key] ||= []
          grouped_images[name][key] << hash
        end
      end
    end
  end
  
  def identify_knowns
    grouped_images.each_pair do |name, list|
      list.each_pair do |key, images|
        image = images.first
        
        hash = {
          location: {
            standard: images.collect{ |h| url_of(h['scaled_path']) },
            inverted: images.collect{ |h| url_of(h['negative_path']) }
          },
          coords: [image['center']['ra'], image['center']['dec']],
          cutout: {
            x: [image['crop']['xmin'].round, image['crop']['xmax'].round],
            y: [image['crop']['ymin'].round, image['crop']['ymax'].round]
          },
          known_objects: { },
          filename: name
        }
        
        ephm_data.fetch(name, { }).each_pair do |object_name, list|
          list.each do |object|
            x_bounds = object[:x] > image['crop']['xmin'] && object[:x] < image['crop']['xmax']
            y_bounds = object[:y] > image['crop']['ymin'] && object[:y] < image['crop']['ymax']
            
            if x_bounds && y_bounds && images[object[:index].to_i - 1]
              relative_x = object[:x] - image['crop']['xmin']
              relative_y = object[:y] - image['crop']['ymin']
              relative_y = 256 - relative_y
              hash[:known_objects][object[:index]] ||= []
              hash[:known_objects][object[:index]] << {
                object: object[:object],
                x: relative_x,
                y: relative_y,
                mag: object[:mag]
              }
            end
          end
        end
        
        subject_data << hash
      end
    end
  end
  
  def create_groups
    # only create groups on the first batch
    return unless BATCH.first.zero?
    group name: 'with_known'
    group name: 'without_known'
  end
  
  def create_subjects
    self.subject_data.each do |hash|
      hash = with_verified_knowns hash
      group_name = if hash[:has_good_known]
        'with_known'
      else
        'without_known'
      end
      
      subject coords: hash[:coords], group_name: group_name, location: hash[:location], metadata: {
        filename: hash[:filename],
        cutout: hash[:cutout],
        known_objects: hash[:known_objects]
      }
    end
  end
  
  def with_verified_knowns(hash)
    objects = { }
    hash[:known_objects].each_pair do |i, list|
      list.each do |object|
        name = object[:object]
        objects[name] ||= []
        objects[name] << object
      end
    end
    
    hash[:has_good_known] = false
    
    objects.each_pair do |name, list|
      avg_magnitude = list.collect{ |h| h[:mag] }.inject(:+) / list.length.to_f
      is_good = list.length > 3 && avg_magnitude < 20
      
      if is_good
        hash[:has_good_known] = true
        hash[:known_objects].each_pair do |i, list|
          hash[:known_objects][i] = list.collect do |o|
            o[:good_known] = true if o[:object] == name
            o
          end
        end
      end
    end
    
    hash
  end
  
  def parse_ephm(file)
    fits_file = "data/asteroid/fits/#{ File.basename(file).sub(/\.ephm$/, '.arch.H') }"
    { }.tap do |objects|
      File.read(file).split("\n").each do |row|
        mjd, ra, dec, mag, _, _, dates, name = row.scan(@ephm_matcher).collect{ |m| m[4] || m[2] }.collect &:strip
        x, y = `sky2xy #{ fits_file } #{ ra } #{ dec }`.match(@coords_matcher)[1..2]
        
        objects[name] ||= []
        index = '%04d' % (objects[name].length + 1)
        objects[name] << {
          object: name,
          index: index,
          ra: ra, dec: dec,
          x: x.to_f, y: y.to_f,
          mag: mag.to_f,
          dates: dates,
          mjd: mjd
        }
        objects[name] = objects[name].sort{ |a, b| a[:index] <=> b[:index] }
      end
    end
  end
  
  def download(from: nil, to: nil, timeout: 60)
    _with_retries(5) do
      `rm -f '#{ to }'`
      bucket.object(from).get(response_target: to)
    end
  end
  
  def bucket
    @bucket ||= self.class.s3.bucket(bucket_name)
  end
  
  def bucket_name
    'asteroidzoo'
  end
  
  def url_of(path)
    "http://asteroidzoo.s3.amazonaws.com/#{ path }"
  end
  
  def output_path
    "#{ data_path }/asteroid_manifest_#{ BATCH.first }-#{ BATCH.last }.json"
  end
  
  def upload_file
    # manual upload since we're dealing with multiple S3 accounts
  end
end

manifest = Asteroid.create

with_knowns = manifest.subject_data.reject{ |h| h[:known_objects].empty? }
with_good_knowns = manifest.subject_data.select{ |h| h[:has_good_known] }

puts "subjects: #{ manifest.subject_data.length }"
puts "with known: #{ with_knowns.length }"
puts "with good known: #{ with_good_knowns.length }"

puts "#{ (100 * (with_good_knowns.length / manifest.subject_data.length.to_f)).round }% known"
