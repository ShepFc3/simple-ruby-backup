#!/usr/bin/env ruby

=begin 
 Author: Chris Shepherd 
 Site: http://shep-dev.com
 Version: 0.9
 Release Date: 2008.11.04
 Contact: ChrisA.Shepherd@gmail.com 
=end

require 'yaml'
require 'ftools'
require 'fileutils'

def initial_run?(backup_dir)
  Dir.entries(backup_dir).select{|dir| dir[/\b(backup)\./]}.empty?
end

def rotate_backups(num_backups_to_rotate, backup_num, backup_dir)
  backup_num.downto 1 do |i|
    case i
      when num_backups_to_rotate
        puts "Removing backup.#{i}"
        FileUtils.rm_r("#{backup_dir}/backup.#{i}")
      when 1
        FileUtils.mv("#{backup_dir}/backup.current", "#{backup_dir}/backup.#{i+1}")
      else
        FileUtils.mv("#{backup_dir}/backup.#{i}", "#{backup_dir}/backup.#{i+1}")
    end
  end
end

def current_backup_num(num_backups_to_keep, backup_dir)
  2.upto num_backups_to_keep+1 do |i|
    return i-1 unless File.directory?("#{backup_dir}/backup.#{i}")
  end
end

settings = YAML::load_file('backup_settings.yml')
exclude_directories = settings["backup"]["excludes"].split(":")
exclude_string = exclude_directories.collect{|e| "--exclude #{e}"}.join(' ')

File.open("ruby_backup.log", "w"){|log| log.write "Starting backup #{Time.now}...\n"}

settings["backup"]["rsync_folders"].each{|source, dest|
  unless initial_run?(dest)
    backup_num = current_backup_num(settings["backup"]["num_backups_to_keep"], dest)
    rotate_backups(settings["backup"]["num_backups_to_keep"], backup_num, dest)
  end

  if File.directory?(dest)
    puts "About to backup #{source} to #{dest}"
    if initial_run?(dest)
      system("#{settings['environment']['rsync_path']}/rsync -av --delete #{exclude_string} #{source} #{dest}/backup.current >> ruby_backup.log")
    else
      system("#{settings['environment']['rsync_path']}/rsync -av --delete #{exclude_string} --link-dest=#{dest}/backup.2 #{source} #{dest}/backup.current >> ruby_backup.log")
    end
    puts "Backup completed successfully"
    File.open("ruby_backup.log", "a"){|log| log.write "Backup complete #{Time.now}"}
  else
    puts "Error: Please mount or create the destination folder #{dest} and try again"
    File.open("ruby_backup.log", "a"){|log| log.write "Backup failed #{Time.now}"}
    exit 1
  end
}
