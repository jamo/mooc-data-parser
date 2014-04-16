module MoocDataParser
  require 'optparse'
  require 'ostruct'
  class OptionsParcerLogic

    def initialize(argv)
      @argv = argv
    end

    def parse
      options = OpenStruct.new
      opt = OptionParser.new do |opts|
        opts.banner = "Usage: show-mooc-details.rb [options]"

        opts.on("-f", "--force", "Reload data from server") do |v|
          options.reload = true
        end
        opts.on("-u", "--user username", "Show details for user") do |v|
          options.user = v
        end
        opts.on("-m", "--missing-points", "Show missing compulsary points") do |v|
          options.show_missing_compulsory_points = true
        end
        opts.on("-c", "--completion-precentige", "Show completition percentige") do |v|
          options.show_completion_percentige = true
        end
        opts.on("-e", "--email emailaddress", "Show details for user") do |v|
          options.user_email = v
        end
        opts.on("-t", "--tmc-account tmc-account", "Show details for user") do |v|
          options.user_tmc_username = v
        end
        opts.on("-l", "--list", "Show the basic list") do |v|
          options.list = true
        end
        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          exit
        end
      end
      opt.parse!(@args)
      [options, opt]
    end
  end
end
