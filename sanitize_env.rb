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
# --profile
#   accepted params: ghc
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
# Profile	    -> Application specific settings
module Sanitize
	
  ##############################################################################
  # Operating systems
  ##############################################################################
  # Base class for operating system specific settings
  ##############################################################################
  module OperatingSystem
    class Base
      attr_accessor :path
      attr_accessor :profiles
      def initialize
	@path = Array.new
	@profiles = Array.new
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
    
    ##############################################################################
    # Solaris specific environment settings
    ##############################################################################
    class Solaris < Base

      def initialize
	super
	@path << [ "/opt/csw/gcc4/bin", "/opt/csw/bin", "/bin", "/usr/bin" ]
      end

      def setenv
	@profiles.each do | profile |
	  profile.setenv_solaris(self)
	end
	super
	ENV['SANITIZED_OS'] = 'solaris'
      end
    end

    ##############################################################################
    # Generic linux environment settings
    ##############################################################################
    class Linux < Base
      def initialize
	super
	@path << [ "/usr/sbin", "/usr/bin", "/sbin", "/bin" ]
      end

      def setenv
	@profiles.each do | profile |
	  profile.setenv_linux(self)
	end

	super
	ENV['SANITIZED_OS'] = 'linux'
      end
    end
  end

  ##############################################################################
  # Application profiles
  ##############################################################################
  # Base profile
  ##############################################################################
  module Profile
    class Base
      
      def setenv_linux(os)
      end

      def setenv_solaris(os)
      end
    end

    ##############################################################################
    # GHC profile
    ##############################################################################
    class Ghc < Base
      def setenv_solaris(os)
	os.path.unshift('/pkgs/gcc/gcc-4.1.0/bin', '/pkgs/ghc/current/bin')
      end
    end
  end

  ##############################################################################
  # Shell specific settings
  ##############################################################################
  # Base class for the shell to execute
  ##############################################################################
  module Shell
    class Base
      def run
	$stderr.puts "Unknown shell type found, blindly executing #{ENV['SHELL']}"
	exec ENV['SHELL']
      end
    end
    
    class Bash < Base
      def run
	puts "Entering shell \"#{ENV['SHELL']}\" with sanitized environment."
	exec "#{ENV['SHELL']} --noprofile --norc"
      end
    end
  end

  ##############################################################################
  # Specific instance of an environment.
  ##############################################################################
  class Environment
    attr_accessor :os
    attr_accessor :shell

    def initialize
      @os = Sanitize::OperatingSystem::Base.new
      @shell = Sanitize::Shell::Base.new
    end

    def execute
      ENV['SANITIZED'] = '1'
      @os.setenv
      @shell.run
    end
  end
end


################################################################################
# help documentation
################################################################################

# --system, -s
#   accepted params: solaris, linux
# --prependpath, -p
# --appendpath, -a
# --profile
#   accepted params: ghc

################################################################################
# Begin main body of execution
################################################################################

require 'optparse'
require 'getoptlong'

new_env = Sanitize::Environment.new

opts = GetoptLong.new( 
  ['--system', '-s', GetoptLong::REQUIRED_ARGUMENT],
  ['--appendpath', GetoptLong::REQUIRED_ARGUMENT],
  ['--prependpath', GetoptLong::REQUIRED_ARGUMENT],
  ['--profile', '-p', GetoptLong::REQUIRED_ARGUMENT]
)

opts.each do | opt, arg |
  # TODO remove debug statement
  puts "DEBUG opt: #{opt}, arg: #{arg}"

  # Set operating system specific env
  if opt == "--system" 
    tmp_path = new_env.os.path
    tmp_profiles = new_env.os.profiles
    new_env.os = case arg
      when "solaris" then Sanitize::OperatingSystem::Solaris.new
      when "linux" then Sanitize::OperatingSystem::Linux.new
      else
	puts "WARNING: Operating system #{arg} unsupported."
	Sanitize::OperatingSystem::Base.new
    end

    # Transfer previously stored path and profiles to new OS, if it exists
    if tmp_path.size > 0
      new_env.os.path = tmp_path
    end
    if tmp_profiles.size > 0
      new_env.os.profiles = tmp_profiles
    end

  elsif opt == '--appendpath'
    new_env.os.path << arg

  elsif opt == '--prependpath'
    new_env.os.path.unshift arg

  elsif opt == '--profile'
    new_env.os.profiles << case arg
      when 'ghc' then Sanitize::Profile::Ghc.new
    end
  end

end


# Determine shell type

if ENV['SHELL'] == '/bin/bash'
  new_env.shell = Sanitize::Shell::Bash.new
elsif ENV['SHELL'] == '/bin/zsh'
  puts "Support for zsh to come."
end

# Set all environment variables and execute shell
new_env.execute

