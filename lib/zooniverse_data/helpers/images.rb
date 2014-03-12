require 'fastimage'
require 'ostruct'

module ZooniverseData
  module Helpers
    module Images
      class ImageConversionError < StandardError; end
      class ImageOptimizationError < StandardError; end
      
      class Image
        attr_accessor :path, :raise_exceptions
        
        def initialize(path: path, raise_exceptions: true)
          self.path = path
          self.raise_exceptions = raise_exceptions
        end
        
        def size
          width, height = info.size
          OpenStruct.new width: width, height: height
        end
        
        def type
          info.type
        end
        
        def info
          @info ||= FastImage.new(path, raise_on_failure: raise_exceptions)
        end
        
        def optimize
          tap do
            case type
            when :jpeg
              _run_optimization "jpegtran -copy none -optimize -progressive -outfile '#{ tempfile.path }' '#{ path }'"
            when :png, :bmp, :gif, :tiff
              _run_optimization "optipng -strip all -o2 -quiet '#{ path }'"
            end
          end
        end
        
        def tempfile
          return @tempfile if @tempfile
          @tempfile = Tempfile.new File.basename path
        end
        
        def remove_tempfile
          tempfile.delete
          @tempfile = nil
        end
        
        def replace_with_tempfile
          `cp '#{ tempfile.path }' '#{ path }'`
          remove_tempfile
        end
        
        def _run_optimization(command)
          success = system command
          raise ImageOptimizationError.new('Image optimization failed') unless success
          replace_with_tempfile if @tempfile
        end
      end
      
      class Converter
        attr_accessor :input_image, :output_image, :flags
        attr_accessor :raise_exceptions, :remove_original, :optimize
        
        def initialize(path: path, raise_exceptions: true, remove_original: true, optimize: true)
          self.input_image = Image.new path: path, raise_exceptions: raise_exceptions
          self.remove_original = remove_original
          self.optimize = optimize
          self.flags = []
        end
        
        def command(string)
          tap do
            self.flags << string
          end
        end
        
        def resize(width: nil, height: nil, force: true, type: nil)
          tap do
            resize_type = type ? "#{ type }-resize" : 'resize'
            
            if width && height
              self.flags << "-#{ resize_type } #{ width }x#{ height }#{ force ? '\!' : '' }"
            elsif width || height
              self.flags << "-#{ resize_type } #{ [width, height].join('x') }"
            end
          end
        end
        
        def adaptive_resize(width: width, height: height, force: true)
          resize width: width, height: height, type: 'adaptive', force: force
        end
        
        def percentage_resize(percentage, type: nil)
          tap do
            resize_type = type ? "#{ type }-resize" : 'resize'
            self.flags << "-#{ resize_type } #{ percentage }% +repage"
          end
        end
        
        def adaptive_percentage_resize(percentage)
          percentage_resize percentage, type: 'adaptive'
        end
        
        def quality(percentage)
          tap do
            self.flags << "-quality #{ percentage }%"
          end
        end
        
        def crop(width: width, height: height, top: top, left: left)
          tap do
            self.flags << "-crop #{ width }x#{ height }+#{ left }+#{ top } +repage"
          end
        end
        
        def crop_center(width: width, height: height, top: 0, left: 0)
          tap do
            self.flags << "-gravity Center -crop #{ width }x#{ height }+#{ left }+#{ top } +repage"
          end
        end
        
        def negate
          tap do
            self.flags << "-negate"
          end
        end
        alias_method :invert, :negate
        
        def write_to(path: nil, prefix: nil, postfix: nil)
          to(path: path, prefix: prefix, postfix: postfix).write
        end
        
        def to(path: nil, prefix: nil, postfix: nil)
          raise ImageConversionError.new('Cannot convert an image without an output path') unless path || prefix || postfix
          tap do
            if prefix || postfix
              input_file = input_image.path
              input_path = File.dirname input_file
              input_ext = File.extname input_file
              input_name = File.basename(input_file).sub input_ext, ''
              
              input_name = "#{ prefix }_#{ input_name }" if prefix
              input_name = "#{ input_name }_#{ postfix }" if postfix
              path = "#{ input_path }/#{ input_name }#{ input_ext }"
            end
            
            self.output_image = Image.new path: path, raise_exceptions: raise_exceptions
          end
        end
        
        def write
          raise ImageConversionError.new('Cannot convert an image without an output path') unless output_image
          
          output_image.tap do
            success = system "convert #{ input_image.path } #{ flags.join(' ') } #{ output_image.path }"
            raise ImageConversionError.new('Image conversion failed') unless success
            `rm -f '#{ input_image.path }'` if remove_original && input_image.path != output_image.path
            output_image.optimize if optimize
          end
        end
      end
      
      def convert_image(path, remove_original: true, optimize: true)
        Converter.new path: path, remove_original: remove_original, optimize: optimize
      end
      
      def invert_image(path, remove_original: false, optimize: true)
        convert_image(path, remove_original: remove_original).invert.write_to prefix: 'inverted'
      end
      
      def convert_to_jpeg(path, remove_original: true, optimize: true)
        _simple_convert path, 'jpg', remove_original: remove_original, optimize: optimize
      end
      
      def convert_to_png(path, remove_original: true, optimize: true)
        _simple_convert path, 'png', remove_original: remove_original, optimize: optimize
      end
      
      def _simple_convert(path, extension, remove_original: true, optimize: true)
        out_path = path.sub(/#{ File.extname(path) }$/, ".#{ extension }")
        convert_image(path, remove_original: remove_original, optimize: optimize).to(path: out_path).write
      end
    end
  end
end
