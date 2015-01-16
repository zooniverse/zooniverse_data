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

    @csv_image_metadata.each_pair do |file_path, metadata|
      puts file_path
      subject location: url_of(file_path), metadata: metadata
    end
  end

  def project_name
    ARGV[0]
  end

  private

    def load_csv_image_metadata
      filelist = zooniverse_data_bucket.objects["#{PROJECT_DATA_PATH}/#{project_name}/#{CSV_FILELIST_NAME}"]
      csv_file_data = CSV.parse(filelist.read)
      @header_row = csv_file_data.shift
      read_csv_file_rows(csv_file_data)
    end

    def s3
      @s3 ||= AWS::S3.new
    end

    def zooniverse_data_bucket
      @zoo_data_bucket ||= s3.buckets['zooniverse-data']
    end

    def read_csv_file_rows(csv_file_data)
      csv_file_data.each do |row|
        row.unshift(nil) if row.length != @header_row.length && row.first.match(/#{IMAGE_FILE_REGEX}/i)
        row = row.map! { |val| val && (val.empty? || val.match(/na/i)) ? nil : val }
        @csv_image_metadata[row[0]] = {}
        current_col = 0
        row.each do |col|
          @csv_image_metadata[row[0]][current_col == 0 ? :path : @header_row[current_col]] = col
          current_col += 1
        end
      end
    end
end

GenericManifest.create
