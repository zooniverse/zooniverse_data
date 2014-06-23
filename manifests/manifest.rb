$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'json'
require 'active_support'
require 'active_support/core_ext'
require 'zooniverse_data'
require 'aws-sdk'

module Manifest
  extend ActiveSupport::Concern
  include ZooniverseData::Helpers::Transport
  
  included do
    attr_accessor :output
    attr_accessor :_groups
  end
  
  module ClassMethods
    def project_name
      name.underscore
    end
    
    def create(*args)
      manifest = new(*args)
      manifest._groups = { }
      manifest.output = []
      manifest.prepare
      manifest.write
      manifest.upload_file
      manifest
    end
  end
  
  def project_name
    self.class.project_name
  end
  
  def write
    File.open(output_path, 'w') do |out|
      out.puts JSON.dump output
    end
  end
  
  def upload_file
    path = upload from: output_path, to: "#{ project_name }_manifest.json", content_type: 'application/json'
    puts "Uploaded to #{ bucket.url }#{ path }"
  end
  
  def input_path
    "#{ data_path }/#{ project_name }"
  end
  
  def output_path
    "#{ data_path }/#{ project_name }_manifest.json"
  end
  
  def data_path
    File.expand_path("../../data", __FILE__)
  end
  
  def load_json(file)
    JSON.load File.read file
  end
  
  def file_named(name)
    Dir["#{ input_path }/**/#{ name }"].first
  end
  
  def files(type: nil)
    type = ".#{ type }" if type
    Dir["#{ input_path }/**/*#{ type }"]
  end
  
  def each_file(type: nil)
    files(type: type).each do |path|
      yield path
    end
  end
  
  def subject(location: location, coords: [], metadata: { }, group_name: nil)
    hash = {
      type: 'subject',
      coords: coords,
      location: location,
      metadata: metadata
    }
    hash[:group_name] = group_name if group_name
    self.output << hash
  end
  
  def group(name: name, type: nil, categories: [], metadata: { }, parent_group_name: nil)
    return _groups[name] if _groups[name]
    hash = {
      type: 'group',
      name: name,
      categories: categories,
      metadata: metadata
    }
    hash[:group_type] = type if type
    hash[:parent_group_name] = parent_group_name if parent_group_name
    _groups[name] = hash
    self.output << hash
  end
  
  def bucket_name
    'zooniverse-data'
  end
  
  def bucket_path
    "project_data/#{ project_name }"
  end
  
  def url_of(file)
    "http://s3.amazonaws.com/zooniverse-data/project_data/#{ project_name }/#{ file }"
  end
end
