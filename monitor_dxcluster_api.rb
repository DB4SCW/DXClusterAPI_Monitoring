#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'sqlite3'
require 'fileutils'

# File to store the daemon process PID
PID_FILE = "/tmp/dxstats_daemon.pid"
# SQLite3 database file name
DB_FILE = File.expand_path('../', __FILE__) + "/dxstats.db"

# Daemonize the process
def daemonize
  # First fork: exit parent
  exit if fork
  # Detach from controlling terminal and create a new session
  Process.setsid
  # Second fork: ensure the process can never reacquire a controlling terminal
  exit if fork

  # Change working directory, reset file mode creation mask,
  # and redirect standard file descriptors to /dev/null.
  Dir.chdir('/')
  File.umask(0000)
  STDIN.reopen('/dev/null')
  STDOUT.reopen('/dev/null', 'a')
  STDERR.reopen('/dev/null', 'a')
end

# Create the SQLite3 database table if it doesn't exist.
def init_db
  db = SQLite3::Database.new(DB_FILE)
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS stats (
      id INTEGER PRIMARY KEY,
      inserted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      entries INTEGER,
      cluster INTEGER,
      pota INTEGER,
      freshest TEXT,
      oldest TEXT
    );
  SQL
  db
end

# Main loop to fetch stats and insert into the database
def main_loop(url)
  # Initialize the DB (table will be created if needed)
  db = init_db

  # Handle SIGTERM to exit gracefully.
  trap("TERM") do
    db.close if db
    exit
  end

  loop do
    begin
      # Query the stats endpoint
      uri = URI(url)
      response = Net::HTTP.get(uri)
      data = JSON.parse(response)
      
      # Extract values from JSON response
      entries  = data["entries"]
      cluster  = data["cluster"]
      pota     = data["pota"]
      freshest = data["freshest"]
      oldest   = data["oldest"]

      # Insert the data into the database. The inserted_at timestamp will default to the current time.
      db.execute("INSERT INTO stats (entries, cluster, pota, freshest, oldest) VALUES (?, ?, ?, ?, ?)",
                 [entries, cluster, pota, freshest, oldest])
    rescue => e
      # For production use, consider logging errors to a file.
      # Here we simply ignore errors to keep the daemon running.
    end

    # Wait one minute before next query
    sleep 60
  end
end

# Start the daemon process
def start_daemon(url)
  if File.exist?(PID_FILE)
    puts "Daemon is already running."
    exit 1
  end

  daemonize

  # Write the daemon's PID to file so it can be stopped later.
  File.write(PID_FILE, Process.pid)

  # Start the main loop
  main_loop(url)
end

# Stop the daemon process
def stop_daemon
  unless File.exist?(PID_FILE)
    puts "Daemon is not running."
    exit 1
  end

  pid = File.read(PID_FILE).to_i
  begin
    Process.kill("TERM", pid)
    puts "Daemon stopped."
  rescue Errno::ESRCH
    puts "Process with PID #{pid} does not exist."
  ensure
    File.delete(PID_FILE) if File.exist?(PID_FILE)
  end
end

# Command-line interface
if ARGV.empty?
  puts "Usage: #{$0} {start|stop} https://your.api.here/dxcache/stats"
  exit 1
end

command = ARGV[0].downcase

case command
when "start"
  if ARGV.count < 2
    puts "Usage: #{$0} {start|stop} https://your.api.here/dxcache/stats"
    exit 1
  end
  url = ARGV[1].downcase
  puts "Starting daemon..."
  start_daemon(url)
when "stop"
  puts "Stopping daemon..."
  stop_daemon
else
  puts "Unknown command: #{command}"
  puts "Usage: #{$0} {start|stop}"
  exit 1
end
