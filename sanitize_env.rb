#!/usr/bin/env ruby
################################################################################
# sanitize.rb
################################################################################
# 
# Author: Adrien Thebo
#
# sanitize is a ruby script for setting up an environment with standardized 
# values.
#
# Current options:
#
# --system, -s
#   accepted params: solaris, linux
# --prependpath, -p
# --appendpath, -a
#
################################################################################

################################################################################
# module Sanitize
################################################################################
#
# Containing module for all the sanitizing goodies that this script contains.
# 
# Classes to note:
# OperatingSystem   -> base class for all operating systems.
# Shell		    -> base class for shells. 
# Environment	    -> class for a full environment
module Sanitize
	
  # Base class for operating system specific settings
  class OperatingSystem
    attr_accessor :path

    def initialize
      @path = []
    end

    def setpath
      if @path.length > 0
	ENV['PATH'] = @path.join(":")
      end
    end

    # Basic setenv method. 
    def setenv
      self.setpath
      ENV.delete 'LD_LIBRARY_PATH'
    end

    def unset
      ENV.each_key do | k |
	ENV.delete k
      end
    end
  end
  
  # Solaris specific environment settings
  class Solaris < OperatingSystem

    def initialize
      super
      @path << [ "/opt/csw/gcc4/bin", "/opt/csw/bin", "/bin", "/usr/bin" ]
    end

    def setenv
      super
      ENV['SANITIZED_OS'] = 'solaris'
    end
  end

  # Generic linux environment settings
  class Linux < OperatingSystem
    
    def initialize
      super
      @path << [ "/usr/sbin", "/usr/bin", "/sbin", "/bin" ]
    end

    def setenv
      super
      ENV['SANITIZED_OS'] = 'linux'
    end
  end

  # Base class for the shell to execute
  class Shell
    def run
      exec ENV['SHELL']
    end
  end
  
  class Bash < Shell
    def run
      exec "#{ENV['SHELL']} --noprofile --norc"
    end
  end

  # Specific instance of an environment.
  class Environment
    attr_accessor :os
    attr_accessor :shell

    def initialize
      @os = Sanitize::OperatingSystem.new
      @shell = Sanitize::Shell.new
    end

    def execute
      ENV['SANITIZED'] = '1'
      @os.setenv
      @shell.run
    end
  end
end

# Begin main body of execution

require 'getoptlong'

#TODO Remove TODO statement
puts "TODO add manpath munging"

new_env = Sanitize::Environment.new

opts = GetoptLong.new( 
  ['--system', '-s', GetoptLong::REQUIRED_ARGUMENT],
  ['--appendpath', '-a', GetoptLong::REQUIRED_ARGUMENT],
  ['--prependpath', '-p', GetoptLong::REQUIRED_ARGUMENT],
)

opts.each do | opt, arg |
  # TODO remove debug statement
  puts "DEBUG opt: #{opt}, arg: #{arg}"

  # Set operating system specific env
  if opt == "--system" 
    tmp_path = new_env.os.path
    new_env.os = case arg
      when "solaris" then Sanitize::Solaris.new
      when "linux" then Sanitize::Linux.new
      else
	puts "WARNING: Operating system #{arg} unsupported."
	Sanitize::OperatingSystem.new
    end

    # Transfer previously stored path to new OS, if it exists
    if tmp_path.size > 0
      new_env.os.path = tmp_path
    end

  elsif opt == "--appendpath"
    new_env.os.path << arg
  end
end


# Determine shell type

if ENV['SHELL'] == '/bin/bash'
  new_env.shell = Sanitize::Bash.new
end

# Set all environment variables and execute shell
puts "Entering shell \"#{ENV['SHELL']}\" with sanitized environment."
new_env.execute

