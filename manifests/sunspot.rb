require_relative 'manifest'

class Sunspot
  include Manifest
  attr_accessor :columns, :types, :data, :angles, :context_images
  
  def initialize
    self.columns = []
    self.types = {
      sszn: :to_s,
      noaa: :to_i,
      n_nar: :to_i,
      filename: :to_s,
      date: :to_time,
      hgpos: :from_csv_to_f_a,
      hcpos: :from_csv_to_f_a,
      pxpos: :from_csv_to_f_a,
      hale: :to_s,
      zurich: :to_s,
      area: :to_f,
      areafrac: :to_f,
      areathesh: :to_f,
      flux: :to_f,
      fluxfrac: :to_f,
      bipolesep: :to_f,
      c1flr24hr: :to_bool,
      m1flr12hr: :to_bool,
      m5flr12hr: :to_bool,
      allnoaa: :to_i
    }
  end
  
  def prepare
    load_data
    
    %w(bin_0_20 bin_20_40 bin_40_50 bin_50_60 bin_60_65 bin_65_90).each do |bin|
      group name: bin
    end
    
    data.collect{ |row| parse(row) }.compact.each do |hash|
      location = { standard: url_of("cutouts/#{ hash[:file_name] }") }
      context_image = context_images[hash[:sszn].to_s]
      location[:context] = context_image ? url_of(context_image) : nil
      
      subject coords: hash[:hgpos], location: location, metadata: metadata_for(hash), group_name: group_name_of(hash)
    end
  end
  
  def load_data
    file_list = load_json file_named 'launch1_list.json'
    self.context_images = { }
    file_list.select{ |f| f =~ /^fulldisk/ }.each do |file|
      id = file.match(/fulldisk_(\d+)\.eps/)[1]
      context_images[id] = file
    end
    
    self.data = File.read(file_named('smart_cutouts_metadata_allclear.beta.1.20131127_0159.txt')).split "\n"
    self.data.shift while data.first.match(/^#/)
    
    angle_data = File.read(file_named('smart_cutouts_metadata_allclear.beta.1.20131127_0159_angle-to-dc.txt')).split "\n"
    angle_data.shift while angle_data.first.match(/^#/)
    
    self.angles = { }
    angle_data.each do |row|
      sszn, coords, angle = row.split(";").collect{ |r| r.strip }
      self.angles[sszn] = angle.to_f
    end
  end
  
  def metadata_for(hash)
    {
      sszn: hash[:sszn],
      noaa: hash[:noaa],
      n_nar: hash[:n_nar],
      filename: hash[:filename],
      date: hash[:date],
      hcpos: hash[:hcpos],
      pxpos: hash[:pxpos],
      hale: hash[:hale],
      zurich: hash[:zurich],
      area: hash[:area],
      areafrac: hash[:areafrac],
      areathesh: hash[:areathesh],
      flux: hash[:flux],
      fluxfrac: hash[:fluxfrac],
      bipolesep: hash[:bipolesep],
      c1flr24hr: hash[:c1flr24hr],
      m1flr12hr: hash[:m1flr12hr],
      m5flr12hr: hash[:m5flr12hr],
      angle: hash[:angle]
    }
  end
  
  def group_name_of(hash)
    if hash[:angle] < 20
      'bin_0_20'
    elsif hash[:angle] < 40
      'bin_20_40'
    elsif hash[:angle] < 50
      'bin_40_50'
    elsif hash[:angle] < 60
      'bin_50_60'
    elsif hash[:angle] < 65
      'bin_60_65'
    else
      'bin_65_90'
    end
  end
  
  def parse(row)
    Hash[ *types.keys.zip(row.split(';')).flatten ].tap do |hash|
      hash.each_pair do |key, value|
        format = types[key.to_sym]
        hash[key] = if value.respond_to?(format)
          value.send format
        else
          send format, value
        end
      end
      
      # actual hale: ["", "alpha", "alphagamma", "alphagamma-delta", "beta", "beta-gamma", "beta-gamma-delta", "betaa", "betaagamma", "betaagamma-delta", "x"]
      # should be: alpha, beta, beta-gamma, beta-gamma-delta, beta-delta (rare), gamma (rare), or an empty string
      #   least complex: alpha
      #   medium complex: beta
      #   most complex: beta-gamma, gamma, beta-gamma-delta, delta
      
      hash[:hale] = case hash[:hale]
      when 'alpha'
        'alpha'
      when 'alphagamma'
        'gamma'
      when 'alphagamma-delta'
        'gamma-delta'
      when 'beta', 'betaa'
        'beta'
      when 'beta-gamma', 'betaagamma'
        'beta-gamma'
      when 'beta-gamma-delta', 'betaagamma-delta'
        'beta-gamma-delta'
      else
        'unknown'
      end
      
      hash[:file_name] = "ar_cutout_#{ hash[:sszn] }.eps"
      hash[:angle] = angles[hash[:sszn]]
    end
  end
  
  def from_csv_to_f_a(text)
    from_csv_to_a(text).collect &:to_f
  end
  
  def from_csv_to_i_a(text)
    from_csv_to_a(text).collect &:to_i
  end
  
  def from_csv_to_a(text)
    text.split ','
  end
  
  def to_bool(text)
    text == '1'
  end
end

Sunspot.create
