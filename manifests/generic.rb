#!/usr/bin/env ruby
require_relative 'manifest'

require 'aws-sdk'
require 'json'
require 'csv'
require 'active_support'
require 'pry'

class GenericManifest
  include Manifest

  InvalidMetadata = Class.new(StandardError)
  DupImageName = Class.new(StandardError)

  CSV_FILELIST_NAME = "filelist.csv"
  CSV_GROUPLIST_NAME = "grouplist.csv"
  IMAGE_FILE_REGEX = "\.(jp(e)?g|png)$"
  SUBJECT_META_REGEX = "((?<group_name>[a-zA-Z0-9_-]+)/)(?<key>.+)#{IMAGE_FILE_REGEX}"
  PROJECT_DATA_PATH = "project_data"

  def initialize
    if ENV['AWS_ACCESS_KEY_ID'] != nil
      AWS.config({
        access_key_id: ENV['AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['AWS_SECRET_KEY']
      })
    end

    if ARGV[1]
      @subject_meta_regex = ARGV[1]
    else
      @subject_meta_regex = SUBJECT_META_REGEX
    end

    if ARGV[2]
      @multifile_metadata_prefix = ARGV[2]
    else
      @multifile_metadata_prefix = nil
    end

    @group_metadata = Hash.new { |h,k| h[k] = { :metadata => {} } }
    @group_header_row = []

    @csv_image_metadata = Hash.new { |h,k| h[k] = { :location => [], :metadata => {} } }
    @image_header_row = []
  end

  def prepare
    load_group_metadata

    @group_metadata.each_pair do |group_key, group_hash|
      group_hash[:name] = group_key
      group group_hash
    end

    load_image_metadata

    @csv_image_metadata.each_pair do |subject_key, subject_hash|
      if subject_hash[:location].length == 1
        subject_hash[:location] = subject_hash[:location][0]
      end
      subject subject_hash
    end
  end

  def project_name
    ARGV[0]
  end

  private
    def load_group_metadata
      begin
        grouplist = zooniverse_data_bucket.objects["#{PROJECT_DATA_PATH}/#{project_name}/#{CSV_GROUPLIST_NAME}"]
        csv_file_data = CSV.parse(grouplist.read)
      rescue AWS::S3::Errors::NoSuchKey
        return
      end
      @group_header_row = csv_file_data.shift
      read_group_file_rows(csv_file_data)
    end

    def read_group_file_rows(csv_file_data)
      csv_file_data.each do |row|
        group_name = row[0]
        @group_metadata[group_name] = { :metadata => {} }

        # Skip col 0
        current_col = 1
        row.shift
        row.each do |col|
          @group_metadata[group_name][:metadata][@group_header_row[current_col]] = col
          current_col += 1
        end
      end
    end

    def load_image_metadata
      filelist = zooniverse_data_bucket.objects["#{PROJECT_DATA_PATH}/#{project_name}/#{CSV_FILELIST_NAME}"]
      csv_file_data = CSV.parse(filelist.read.unpack('U*').pack('U*'))
      @image_header_row = csv_file_data.shift
      read_image_file_rows(csv_file_data)
    end

    def read_image_file_rows(csv_file_data)
      csv_file_data.each do |row|
        subject_match = row[0].match(/#{@subject_meta_regex}/)
        @csv_image_metadata[subject_match[:key]][:location].push(url_of(row[0]))

        if subject_match.names.include? 'group_name'
          @csv_image_metadata[subject_match[:key]][:group_name] = subject_match[:group_name]
        end

        # Skip col 0
        current_col = 1
        row.shift
        coords = {}
        metadata = {}
        multifile_metadata = {}

        row.each do |col|
          if @image_header_row[current_col] == 'latitude' or @image_header_row[current_col] == 'longitude'
            coords[@image_header_row[current_col]] = col
          else
            if @multifile_metadata_prefix and @image_header_row[current_col].start_with?("#{@multifile_metadata_prefix}_")
              multifile_metadata[@image_header_row[current_col].sub(/^#{@multifile_metadata_prefix}_/, '')] = col
            else
              metadata[@image_header_row[current_col]] = col
            end
          end
          current_col += 1
        end

        @csv_image_metadata[subject_match[:key]][:metadata].merge!(metadata)

        if @multifile_metadata_prefix
          @csv_image_metadata[subject_match[:key]][:metadata][@multifile_metadata_prefix] = @csv_image_metadata[subject_match[:key]][:metadata].fetch(@multifile_metadata_prefix, [])
          @csv_image_metadata[subject_match[:key]][:metadata][@multifile_metadata_prefix].push(multifile_metadata)
        end

        if coords['latitude'] and coords['longitude']
           @csv_image_metadata[subject_match[:key]][:coords] = [ coords['longitude'], coords['latitude'] ]
        end
      end
    end

    def s3
      @s3 ||= AWS::S3.new
    end

    def zooniverse_data_bucket
      @zoo_data_bucket ||= s3.buckets['zooniverse-data']
    end
end

GenericManifest.create
