require 'timeout'
require 'aws-sdk'

module ZooniverseData
  module Helpers
    module Transport
      extend ActiveSupport::Concern
      
      module ClassMethods
        def s3
          @s3 ||= AWS::S3.new
        end
      end
      
      def download(from: nil, to: nil, timeout: 60)
        _with_retries(20) do
          `rm -f '#{ to }'`
          Timeout::timeout(timeout) do
            `wget '#{ from }' -t 50 -c -q -O '#{ to }'`
          end
          
          raise 'File not downloaded' unless File.exists?(to)
          raise 'File is empty' unless File.new(to).size > 0
        end
      end
      
      def upload(from: nil, to: nil, content_type: nil)
        content_type ||= `file -bI '#{ from }'`.chomp.split(';').first
        path = [bucket_path, to].compact.join('/').gsub(/^\//, '').gsub '//', '/'
        obj = bucket.objects[path]
        
        _with_retries(20) do
          obj.write file: from, acl: :public_read, content_type: content_type
          raise 'File not uploaded' unless obj.exists?
        end
        
        path
      end
      
      def bucket
        @bucket ||= self.class.s3.buckets[bucket_name]
      end
      
      def bucket_name
        @bucket_name ||= manifest.project.bucket
      end
      
      def bucket_path
        @bucket_path ||= manifest.project.bucket_path
      end
      
      def _with_retries(retries)
        tries = 0
        begin
          yield
        rescue => e
          tries += 1
          if tries < retries
            retry
          else
            raise e
          end
        end
      end
    end
  end
end
