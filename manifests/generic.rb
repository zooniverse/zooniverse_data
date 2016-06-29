#!/usr/bin/env ruby
require_relative 'manifest'

require 'active_support'
require 'aws-sdk'
require 'csv'
require 'json'
require 'optparse'
require 'pry'

class GenericManifest
  include Manifest

  InvalidMetadata = Class.new(StandardError)
  DupImageName = Class.new(StandardError)

  CSV_FILELIST_NAME = "filelist.csv"
  CSV_GROUPLIST_NAME = "grouplist.csv"
  IMAGE_FILE_REGEX = "\.(jp(e)?g|png)$"
  SUBJECT_META_REGEX = "(?<key>.+)#{IMAGE_FILE_REGEX}"
  GROUPED_SUBJECT_META_REGEX = "((?<group_name>[a-zA-Z0-9_-]+)/)#{SUBJECT_META_REGEX}"
  PROJECT_DATA_PATH = "project_data"

  def initialize
    if ENV['AWS_ACCESS_KEY_ID'] != nil
      Aws.config.update({
        access_key_id: ENV['AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['AWS_SECRET_KEY']
      })
    end

    @options = {
      :groups => false,
      :subject_meta_regex => SUBJECT_META_REGEX,
      :multifile_metadata_prefix => nil
    }

    OptionParser.new do |opts|
      opts.banner = "Usage: generic.rb [-g] [-r regex] [-m prefix] project_name"

      opts.on('-g', 'Enable grouped subjects') do |g|
        @options[:groups] = g
        @options[:subject_meta_regex] = GROUPED_SUBJECT_META_REGEX
      end

      opts.on('-r regex', String, 'Regex for extracting metadata from subject filenames') do |r|
        @options[:subject_meta_regex] = r
      end

      opts.on('-m prefix', String, 'Filelist column prefix for multifile metadata') do |m|
        @options[:multifile_metadata_prefix] = m
      end

      opts.on('-j prefix', String, 'Prefix for names of columns which are in JSON format') do |m|
        @options[:json_metadata_prefix] = m
      end
      opts.on_tail("-h", "--help", "Show this message") do

        puts opts
        exit
      end
    end.parse!

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
      if not @options[:groups]
        return
      end

      begin
        grouplist = zooniverse_data_bucket.object("#{PROJECT_DATA_PATH}/#{project_name}/#{CSV_GROUPLIST_NAME}")
        csv_file_data = CSV.parse(grouplist.get.body.read)
      rescue Aws::S3::Errors::NoSuchKey
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
      filelist = zooniverse_data_bucket.object("#{PROJECT_DATA_PATH}/#{project_name}/#{CSV_FILELIST_NAME}")
      csv_file_data = CSV.parse(filelist.get.body.read.unpack('U*').pack('U*'))
      @image_header_row = csv_file_data.shift
      read_image_file_rows(csv_file_data)
    end

    def read_image_file_rows(csv_file_data)
      csv_file_data.each do |row|
        subject_match = row[0].match(/#{@options[:subject_meta_regex]}/i)
        if subject_match.nil?
          puts "WARNING: Invalid file name: #{row[0]}"
          next
        end
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
            if @options[:multifile_metadata_prefix] and @image_header_row[current_col].start_with?("#{@options[:multifile_metadata_prefix]}_")
              multifile_metadata[@image_header_row[current_col].sub(/^#{@options[:multifile_metadata_prefix]}_/, '')] = col
            elsif @options[:json_metadata_prefix] and @image_header_row[current_col].start_with?("#{@options[:json_metadata_prefix]}_")
              metadata[@image_header_row[current_col].sub(/^#{@options[:json_metadata_prefix]}_/, '')] = JSON.parse col
            elsif @options[:groups] and @image_header_row[current_col] == 'group_name'
              @csv_image_metadata[subject_match[:key]][:group_name] = col
            else
              metadata[@image_header_row[current_col]] = col
            end
          end
          current_col += 1
        end

        @csv_image_metadata[subject_match[:key]][:metadata].merge!(metadata)

        if @options[:multifile_metadata_prefix]
          @csv_image_metadata[subject_match[:key]][:metadata][@options[:multifile_metadata_prefix]] = @csv_image_metadata[subject_match[:key]][:metadata].fetch(@options[:multifile_metadata_prefix], [])
          @csv_image_metadata[subject_match[:key]][:metadata][@options[:multifile_metadata_prefix]].push(multifile_metadata)
        end

        if coords['latitude'] and coords['longitude']
           @csv_image_metadata[subject_match[:key]][:coords] = [ coords['longitude'], coords['latitude'] ]
        end
      end
    end

    def s3
      self.class.s3
    end

    def zooniverse_data_bucket
      @zoo_data_bucket ||= s3.bucket('zooniverse-data')
    end
end

GenericManifest.create
