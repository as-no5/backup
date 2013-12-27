#!/usr/bin/ruby

require 'rainbow'
require 'net/ssh'
require 'net/sftp'
require 'terminal-table'

#============================= OPTIONS ==============================#

SCRIPT_VERSION = '2.4.2'


# == Options for local machine.

FOLDERS        = ['/volumes/data/someSampleFolder',
                  '/volumes/data/anotherSampleFolder']

NO_OF_BACKUPS  = 5

# == Options for remote machine.

SSH_USER       = 'someUser'
SSH_SERVER     = 'some.server.de'
BACKUP_ROOT    = 'some/folder'
BACKUP_DIR     = BACKUP_ROOT + '/bkp_' + Time.now.strftime('%Y%m%d')


# == Options for rsync.

RSYNC_OPTIONS  = "-az --delete --exclude='.DS_Store'"

#========================== END OF OPTIONS ==========================#


#============================= METHODS ==============================#

def createBackup

  rows = []

  # Call "rsync" for every folder in the array and put a record to the table
  FOLDERS.each do |folder|  
    print '.'
    status = system("rsync #{RSYNC_OPTIONS} " + folder + " #{SSH_USER}@#{SSH_SERVER}:#{BACKUP_DIR}")

    if (status)
      rows << [folder, " DONE ".color(:green)]
    else
      rows << [folder, "ERROR".color(:red)]
    end
  end

  # Clear terminal and print out table
  system("clear")
  table = Terminal::Table.new :headings => ['Folder', 'Status'], :rows => rows
  table.align_column(1, :center)
  puts table
end

#========================== END OF METHODS ==========================#


#=============================== MAIN ===============================#

# Start SSH-session and connecting via SFTP
Net::SSH.start("#{SSH_SERVER}", "#{SSH_USER}") do |ssh|
  ssh.sftp.connect do |sftp|
    START_TIME = Time.now
    puts "\nBackup started at: #{START_TIME}\n"

    # Do backup and print table
    createBackup

    # Create @existing_backups with filtering unwanted folders
    existing_backups = sftp.dir.entries("/home/#{SSH_USER}/#{BACKUP_ROOT}").reject do |backup_folder|
      %w(. ..).include?(backup_folder.name)
    end

    # Sort @existing_backups by name
    existing_backups.sort! { |a, b| a.name <=> b.name }

    # Delete old backups if NO_OF_BACKUPS exceeded
    if existing_backups.size > NO_OF_BACKUPS   
      ssh.exec!("rm -rf /home/#{SSH_USER}/#{BACKUP_ROOT}/" + existing_backups.first.name)
      backup_deleted = true
      existing_backups.pop
    else
      backup_deleted = false
    end

    # Put statistics at the end of the backup
    output_ssh = ssh.exec!("du -sh /home/#{SSH_USER}/#{BACKUP_ROOT}").split
    puts "\n---------------------------------------------------------------------------------"
    puts "Started running at:  #{START_TIME}"
    puts "Finished running at: #{Time.now} - Duration: #{"%.0f" % ((Time.now - START_TIME)/60)} min, #{"%.0f" % ((Time.now - START_TIME) % 60)} sec"
    if backup_deleted == true
      print "1 backup has been deleted, "
    else
      print "No backup has been deleted, "
    end
    puts (existing_backups.size).to_s() + " backup(s) remain(s) on your server, using " + output_ssh[0]
    puts "Version " + SCRIPT_VERSION
    puts "---------------------------------------------------------------------------------\n\n"
  end
end