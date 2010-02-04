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
	  ENV['PATH'] = @path.join(':')
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
  
    class Zsh < Base
      def run
	puts "Entering shell \"#{ENV['SHELL']}\" with sanitized environment."
	exec "#{ENV['SHELL']} -f"
      end
    end
  end

  ##############################################################################
  # Specific instance of an environment.
  ##############################################################################
  class Environment
    attr_accessor :system
    attr_accessor :shell

    def initialize
      @system = Sanitize::OperatingSystem::Base.new
      @shell = Sanitize::Shell::Base.new
    end

    def execute
      ENV['SANITIZED'] = '1'
      @system.setenv
      @shell.run
    end
  end
end


################################################################################
# Begin main body of execution
################################################################################

require 'optparse'

# Make sure sanitizing hasn't occurred.

if ENV['SANITIZED'].to_i == 1
  $stderr.puts "Already in a sanitized environment. Exiting."
  exit 1
end

options = Hash.new

opt_parser = OptionParser.new do | opts |
  opts.banner ="Usage #{$0} [options]"

  opts.on('-s', '--system=val', 'Specify target operating system') do | os |
    options[:system] = os
  end

  opts.on('--prependpath=val', 'Prepend a string to path') do | path |
    options[:ppath] ||= Array.new
    options[:ppath] << path
  end

  opts.on('--appendpath=val', 'Append a string to path') do | path |
    options[:apath] ||= Array.new
    options[:apath] << path
  end

  opts.on('-p', '--profile=val', 'Load a package profile') do | profile |
    options[:profile] ||= Array.new
    options[:profile] << profile
  end

  opts.on('--shell=val', 'Specify a shell to load') do | shell |
    $stderr.puts "--shell switch not available at this time."
    options[:shell] = shell
  end

  opts.on('-h', '--help', 'Display this help screen') do
    puts opts
    exit
  end
end

opt_parser.parse!

################################################################################
# Assemble environment
################################################################################
new_env = Sanitize::Environment.new

new_env.system = case options[:system]
  when 'solaris' then Sanitize::OperatingSystem::Solaris.new
  when 'linux' then Sanitize::OperatingSystem::Linux.new
  else
    if ! options[:system].nil?
      $stderr.puts "Error: Unsupported system \"#{options[:system]}\""
      puts opt_parser
      exit 1
    else
      $stderr.puts "Error: --system switch must be specified."
      puts opt_parser
      exit 1
    end
end

################################################################################
# Load profiles
################################################################################

if ! options[:profile].nil? && options[:profile].length > 0
  options[:profile].each do | profile |
    new_env.system.profiles << case profile
      when 'ghc' then Sanitize::Profile::Ghc.new
    end
  end
end

################################################################################
# Path munging
################################################################################

if ! options[:ppath].nil? && options[:ppath].length > 0
  new_env.system.path.unshift options[:ppath]
end

if ! options[:apath].nil? && options[:ppath].length > 0
  new_env.system.path.push options[:apath]
end

################################################################################
# Determine shell type
################################################################################

#new_env.shell = case options[:shell]
#  when 'bash' then Sanitize::Shell::Bash.new
#  when 'zsh' then Sanitize::Shell::Zsh.new
#end

new_env.shell = case ENV['SHELL']
  when '/bin/bash' then Sanitize::Shell::Bash.new
  when '/bin/zsh' then Sanitize::Shell::Zsh.new
  else Sanitize::Shell::Base.new
end

# Set all environment variables and execute shell
new_env.execute

