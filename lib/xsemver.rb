require 'yaml'
require 'semver/semvermissingerror'

module XSemVer
# sometimes a library that you are using has already put the class
# 'SemVer' in global scope. Too Bad®. Use this symbol instead.
  class SemVer
    FILE_NAME = '.semver'
    TAG_FORMAT = 'v%M.%m.%p%s'

    def SemVer.find dir=nil
      v = SemVer.new
      f = SemVer.find_file dir
      v.load f
      v
    end

    def SemVer.find_file dir=nil
      dir ||= Dir.pwd
      raise "#{dir} is not a directory" unless File.directory? dir
      path = File.join dir, FILE_NAME

      Dir.chdir dir do
        while !File.exists? path do
          raise SemVerMissingError, "#{dir} is not semantic versioned", caller if File.dirname(path).match(/(\w:\/|\/)$/i)
          path = File.join File.dirname(path), ".."
          path = File.expand_path File.join(path, FILE_NAME)
          puts "semver: looking at #{path}"
        end
        return path
      end

    end

    attr_accessor :major, :minor, :patch, :special

    def initialize major=0, minor=0, patch=0, special=''
      major.kind_of? Integer or raise "invalid major: #{major}"
      minor.kind_of? Integer or raise "invalid minor: #{minor}"
      patch.kind_of? Integer or raise "invalid patch: #{patch}"

      unless special.empty?
        special =~ /[A-Za-z][0-9A-Za-z\.]+/ or raise "invalid special: #{special}"
      end

      @major, @minor, @patch, @special = major, minor, patch, special
    end

    def load file
      @file = file
      hash = YAML.load_file(file) || {}
      @major = hash[:major] or raise "invalid semver file: #{file}"
      @minor = hash[:minor] or raise "invalid semver file: #{file}"
      @patch = hash[:patch] or raise "invalid semver file: #{file}"
      @special = hash[:special]  or raise "invalid semver file: #{file}"
    end

    def save file=nil
      file ||= @file

      hash = {
        :major => @major,
        :minor => @minor,
        :patch => @patch,
        :special => @special
      }

      yaml = YAML.dump hash
      open(file, 'w') { |io| io.write yaml }
    end

    def format fmt
      fmt = fmt.gsub '%M', @major.to_s
      fmt = fmt.gsub '%m', @minor.to_s
      fmt = fmt.gsub '%p', @patch.to_s
      if @special.nil? or @special.length == 0 then
        fmt = fmt.gsub '%s', ''
      else
        fmt = fmt.gsub '%s', "-" + @special.to_s
      end
      fmt
    end

    def to_s
      format TAG_FORMAT
    end

    def <=> other
      maj = major.to_i <=> other.major.to_i
      return maj unless maj == 0

      min = minor.to_i <=> other.minor.to_i
      return min unless min == 0

      pat = patch.to_i <=> other.patch.to_i
      return pat unless pat == 0

      return 1 if prerelease? && !other.prerelease?
      return -1 if !prerelease? && other.prerelease?
      
      special <=> other.special
    end

    include Comparable

    # Parses a semver from a string and format.
    def self.parse(version_string, format = nil, allow_missing = true)
      format ||= TAG_FORMAT
      regex_str = Regexp.escape format

      # Convert all the format characters to named capture groups
      regex_str = regex_str.gsub('%M', '(?<major>\d+)').
        gsub('%m', '(?<minor>\d+)').
        gsub('%p', '(?<patch>\d+)').
        gsub('%s', '(?:-(?<special>[A-Za-z][0-9A-Za-z\.]+))?')

      regex = Regexp.new(regex_str)
      match = regex.match version_string

      if match
          major = minor = patch = nil
          special = ''

          # Extract out the version parts
          major = match[:major].to_i if match.names.include? 'major'
          minor = match[:minor].to_i if match.names.include? 'minor'
          patch = match[:patch].to_i if match.names.include? 'patch'
          special = match[:special] || '' if match.names.include? 'special'

          # Failed parse if major, minor, or patch wasn't found
          # and allow_missing is false
          return nil if !allow_missing and [major, minor, patch].any? {|x| x.nil? }

          # Otherwise, allow them to default to zero
          major ||= 0
          minor ||= 0
          patch ||= 0

          SemVer.new major, minor, patch, special
      end
    end
    
    # SemVer specification 2.0.0-rc2 indicates notes that anything after the '-' character is prerelease data.
    # To be more consistent with the specification, #prerelease returns the same value as #special.
    def prerelease
      special
    end
    
    # SemVer specification 2.0.0-rc2 indicates notes that anything after the '-' character is prerelease data.
    # To be more consistent with the specification, #prerelease= sets the same value as #special.
    def prerelease=(pre)
      self.special = pre
    end
    
    # Return true if the SemVer has a non-empty #prerelease value. Otherwise, false.
    def prerelease?
      special.nil? or special.length == 0
    end
    
  end
end
