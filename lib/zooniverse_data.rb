require 'zooniverse_data/version'

module ZooniverseData
  class << self
    attr_accessor :projects
  end
  self.projects = { }
  
  def self.dispatch(manifest: manifest, entry: entry)
    klass = self.projects[manifest.project_id]
    
    unless klass
      klass_name = manifest.project.name.classify
      klass = if ZooniverseData::Projects.const_defined?(klass_name)
        "ZooniverseData::Projects::#{ klass_name }".constantize
      else
        ZooniverseData::Projects::Default
      end
      
      self.projects[manifest.project_id] = klass
    end
    
    klass.new.customize manifest: manifest, entry: entry
  end
  
  require 'zooniverse_data/helpers'
  require 'zooniverse_data/projects'
end
