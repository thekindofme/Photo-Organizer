#!/usr/bin/env ruby

require 'find'
require 'exifr'
require "fileutils"

require "lib/phile"
require "lib/dir_walker"
require "lib/phlogger"

class PhotoOrg

  def run argv
    log = Phlogger.new argv[0], argv[1]

    DirWalker.new(argv[0], log).walk_the_source_dir do |path|
      Phile.new(path, argv[1], log).copy
    end

    log.save
  end
end

#ARGV
#0 - source dir
#1 - dest dir
#2 - exclude dirs like
PhotoOrg.new.run ARGV