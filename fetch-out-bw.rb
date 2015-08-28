#!/usr/bin/env ruby

require 'rubygems'
require 'optparse'
require 'ostruct'
require 'pp'

require 'snmp'
require 'yaml'

class App
  VERSION = '0.0.3'

  attr_reader :options

  def initialize(arguments, stdin)
    @arguments = arguments
    @stdin = stdin

    # Set defaults
    @options = OpenStruct.new
    @options.quiet = false
    @options.debug = false
    @options.count = 1
    @options.delay = 30
    @options.gateway_conf = './gateways.yml'
  end

  def run
    if parsed_options? && arguments_valid?
      process_arguments
      exit process_command
    else
      puts "Please read help: #{File.basename(__FILE__)} --help"
      exit 1
    end
  end

  protected

  def parsed_options?
    # Specify options
    opts = OptionParser.new
    opts.banner = "Usage: #{File.basename(__FILE__)} [options]"
    opts.on('-v', '--version')    		{ output_version ; exit 0 }
    opts.on('-h', '--help')       		{ puts opts ; exit 0 }
    opts.on('-q', '--quiet')      		{ @options.quiet = true }
    opts.on('-u', '--debug')      		{ @options.debug = true }
    opts.on("-g", "--gateways=val", String)  	{ |val| @options.gateway_conf = val }
    opts.on("-c", "--count=val", Integer)  	{ |val| @options.count = val }
    opts.on("-d", "--delay=val", Integer)  	{ |val| @options.delay = val }

    opts.parse!(@arguments) rescue return false

    process_options
    true
  end

  # Performs post-parse processing on options
  def process_options
    @options.quiet = false if @options.debug

    if @options.debug
      output_options
    end
  end

  def output_options
    puts "Options:"

    @options.marshal_dump.each do |name, val|
      puts "  #{name} = #{val}"
    end
  end

  # True if required arguments were provided
  def arguments_valid?
    true if @arguments.length == 0
  end

  # Setup the arguments
  def process_arguments
    true
  end

  def output_version
    puts "#{File.basename(__FILE__)} version #{VERSION}"
  end

  def process_command
    begin
      gateways = YAML.load_file(@options.gateway_conf)
    rescue
      fail("could not read file #{@options.gateway_conf}")
    end

    pp gateways if @options.debug

    ref_results = Hash.new

    gateways["gateways"].each { |gw|
      timestamp, value = get_if_out(gw["name"], gw["snmp_community"], gw["interface_id"], gw["interface_descr"])
      ref_results[gw["name"]] = { :timestamp => timestamp, :if_out => value }
    }

    i = 0; while i < @options.count
      wait_for(@options.delay, @options.quiet)

      total_octets_per_sec = 0
      gateways["gateways"].each { |gw|
        timestamp, value = get_if_out(gw["name"], gw["snmp_community"], gw["interface_id"], gw["interface_descr"])
        time_delta = timestamp - ref_results[gw["name"]][:timestamp]
        value_delta = value - ref_results[gw["name"]][:if_out]
        puts "delta of #{gw["name"]} is 0" if value_delta == 0 if @options.debug
        ops = value_delta / time_delta
        total_octets_per_sec += ops
        out = sprintf("%s has a delta of %d in a time delta %s: %d octets per second", gw["name"], value_delta, time_delta, ops)
        puts out if @options.debug
        ref_results[gw["name"]] = { :timestamp => timestamp, :if_out => value }
      }

      puts octets_as_mbit(total_octets_per_sec).to_s

      i += 1
    end

    return 0
  end

  def fail(out)
    puts "\e[31m#{out}\e[0m"
    exit 1
  end
end

module Exceptions
  class NoValidSNMPResponseError < StandardError; end
  class DescrDoesNotMatchError < NoValidSNMPResponseError; end
  class VeryStrangeError < NoValidSNMPResponseError; end
end

def get_if_out(host, comm, if_id, if_descr)
  SNMP::Manager.open(:host => host, :community => comm) do |manager|
    descr_verified = false
    if_out_value = 0

    ts = Time.now

    resp = manager.get([
        "IF-MIB::ifDescr." + if_id,
        "IF-MIB::ifHCOutOctets." + if_id,
        "IF-MIB::ifSpeed." + if_id
    ])

    resp.each_varbind{|v|
      if v.name.to_s.include? "ifDescr" and v.value.to_s.include? if_descr
        descr_verified = true
      elsif v.name.to_s.include? "ifHCOutOctets"
        if_out_value = v.value.to_i
      end
    }

    if not descr_verified
      raise Exceptions::DescrDoesNotMatchError
    end
    if if_out_value == 0
      raise Exceptions::NoValidSNMPResponse
    end
    return ts, if_out_value
  end
  raise Exceptions::VeryStrangeError
end

def octets_as_mbit(octets)
  return octets * 8 / 1000 / 1000
end

def wait_for(sec, quiet=false)
  i = 0
  while i < sec do
    print "\r#{i}" if !quiet
    sleep 1
    i += 1
  end
  print "\r" if !quiet
end

# Create and run the application
app = App.new(ARGV, STDIN)
app.run
