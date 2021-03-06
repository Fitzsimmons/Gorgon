require 'yajl'

module Gorgon
  class RuntimeFileReader

    def initialize(configuration)
      @runtime_filename = configuration[:runtime_file] || ""
      @globs_of_files = configuration[:files] || [] # e.g. ["spec/file1_spec.rb", "spec/**/*_spec.rb"]
    end

    def old_files
      @old_files ||= unless File.file?(@runtime_filename)
                       []
                     else
                       File.open(@runtime_filename, 'r') do |f|
                         parser = Yajl::Parser.new
                         hash = parser.parse(f)
                         hash.nil? ? [] : hash.keys
                       end
                     end
    end

    def sorted_files # sorts by 1.) globs, 2.) runtime
      @globs_of_files.reduce([]) do |memo, glob|
        memo.concat( sorted_files_by_runtime(Dir[glob]) )
      end.uniq
    end

    private

    def sorted_files_by_runtime(current_files = [])
      (self.old_files+current_files).uniq - (self.old_files-current_files)
    end



  end
end
