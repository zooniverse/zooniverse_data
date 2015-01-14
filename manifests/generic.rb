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

  CSV_METADATA_FILE_REGEX = "filelist([0-9]*)\.(txt|csv)"
  IMAGE_FILE_REGEX = "\.(jp(e)?g|png)$"
  PROJECT_DATA_PATH = "project_data"

  def initialize
    if ENV['AWS_ACCESS_KEY_ID'] != nil
      AWS.config({
        access_key_id: ENV['AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['AWS_SECRET_KEY']
      })
    end

    @csv_image_metadata = {}
    @sample = false
    @sample_size = 200
    @header_row = []
  end

  def prepare
    load_csv_image_metadata
    image_paths = construct_image_paths

    image_paths.each do |hash|
      subject location: url_of(hash[:path]), metadata: hash
    end
  end

  def project_name
    ARGV[0]
  end

  private

    def strip_prefix_s3_object_key(s3_obj_key)
      s3_obj_key.match(/#{PROJECT_DATA_PATH}\/#{project_name}\/(.+)/)[1]
    end

    def construct_image_paths
      [].tap do |images|
        subject_count = 0
        s3_bucket_objects.each do |obj|
          next unless subject_image?(obj)
          csv_metadata_key = strip_prefix_s3_object_key(obj.key)
          images << (@csv_image_metadata[csv_metadata_key] || {}).merge!({ path: csv_metadata_key })
          subject_count += 1
          break if @sample && subject_count == @sample_size
        end
      end
    end

    def load_csv_image_metadata
      s3_bucket_objects.each do |obj|
        next unless obj.key.match(/#{CSV_METADATA_FILE_REGEX}/i)
        csv_file_data = CSV.parse(obj.read)
        metadata_csv_file_name = strip_prefix_s3_object_key(obj.key)
        @header_row = csv_file_data.shift

        read_csv_file_rows(csv_file_data, metadata_csv_file_name)
      end
    end

    def s3
      @s3 ||= AWS::S3.new
    end

    def zooniverse_data_bucket
      @zoo_data_bucket ||= s3.buckets['zooniverse-data']
    end

    def s3_bucket_objects
      zooniverse_data_bucket.objects.with_prefix("#{PROJECT_DATA_PATH}/#{project_name}/")
    end

    def read_csv_file_rows(csv_file_data, metadata_csv_file_name)
      csv_file_data.each do |row|
        row.unshift(nil) if row.length != @header_row.length && row.first.match(/#{IMAGE_FILE_REGEX}/i)
        row = row.map! { |val| val && (val.empty? || val.match(/na/i)) ? nil : val }
        image_file_name_key = construct_image_file_name_key(metadata_csv_file_name, row[0])
        @csv_image_metadata[image_file_name_key] = {}
        current_col = 0
        row.each do |col|
          @csv_image_metadata[image_file_name_key][current_col == 0 ? :path : @header_row[current_col]] = col
          current_col += 1
        end
      end
    end

    def construct_image_file_name_key(metadata_csv_file_name, image_file_name)
      if metadata_csv_file_name.match(/#{CSV_METADATA_FILE_REGEX}/i)
        metadata_prefix_name = image_file_name
      else
        metadata_prefix_name = metadata_csv_file_name.match(/(.+\/)#{CSV_METADATA_FILE_REGEX}/i)[1]
        metadata_prefix_name + "/#{image_file_name}"
      end
    end

    def subject_image?(s3_obj)
      s3_obj.key.match(/#{IMAGE_FILE_REGEX}/i)
    end
end

GenericManifest.create
