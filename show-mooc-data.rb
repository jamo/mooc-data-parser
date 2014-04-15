#!/usr/bin/env ruby -w

require 'optparse'
require 'ostruct'
require 'httparty'
require 'json'
require 'io/console'
class ShowMoocData

  def run(args)
    pos = DATA.pos
    rest = DATA.read

    @notes = begin JSON.parse(rest) rescue  {} end

    @options = OpenStruct.new
    opt = OptionParser.new do |opts|
      opts.banner = "Usage: show-mooc-details.rb [options]"

      opts.on("-f", "--force", "Reload data from server") do |v|
        @options.reload = true
      end
      opts.on("-u", "--user username", "Show details for user") do |v|
        @options.user = v
      end
      opts.on("-m", "--missing-points", "Show missing compulsary points") do |v|
        @options.show_missing_compulsory_points = true
      end
      opts.on("-c", "--completion-precentige", "Show completition percentige") do |v|
        @options.show_completion_percentige = true
      end
      opts.on("-e", "--email emailaddress", "Show details for user") do |v|
        @options.user_email = v
      end
      opts.on("-t", "--tmc-account tmc-account", "Show details for user") do |v|
        @options.user_tmc_username = v
      end
      opts.on("-l", "--list", "Show the basic list") do |v|
        @options.list = true
      end
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end
    opt.parse!(args)

    json = maybe_fetch_json(get_auth())
    if @options.user
      show_info_about(@options.user, 'username', json)
    elsif @options.user_email
      show_info_about(@options.user_email, 'email', json)
    elsif @options.user_tmc_username
      show_info_about(@options.user_tmc_username, 'username', json)
    elsif @options.list
      list_and_filter_participants(json)
    else
      DATA.reopen(__FILE__, "r+")
      DATA.truncate(pos)
      DATA.seek(pos)
      DATA.puts @notes.to_json
      puts opt
      abort
    end

    DATA.reopen(__FILE__, "r+")
    DATA.truncate(pos)
    DATA.seek(pos)
    DATA.puts @notes.to_json
  end

  def get_auth
    print 'username: '
    username = $stdin.gets.strip
    print 'password: '
    password = $stdin.noecho(&:gets).strip
    puts
    {username: username, password: password}
  end

  def maybe_fetch_json(auth)
    if @options.reload or @notes['user_info'].nil? or @notes['week_data'].nil?

      t = -> do
        loop do
          print '.'
          sleep 0.5
        end
        puts
      end


      th = Thread.new(&t)

      url = "http://tmc.mooc.fi/mooc/participants.json?api_version=7&utf8=%E2%9C%93&filter_koko_nimi=&column_username=1&column_email=1&column_koko_nimi=1&column_hakee_yliopistoon_2014=1&group_completion_course_id=18"
      user_info = JSON.parse(HTTParty.get(url, basic_auth: auth).body)['participants']
      week_data = fetch_week_datas(auth)
      @notes['user_info'] = user_info.clone
      @notes['week_data'] = week_data.clone
      th.kill
      puts
      {participants: user_info, week_data: week_data}
    else
      {participants: @notes['user_info'].clone, week_data: @notes['week_data'].clone}
    end
  end

  def show_info_about(user, user_field = 'username', json)
    participants = json[:participants]
    week_data = json[:week_data]
    my_user = participants.find{|a| a[user_field] == user }
    if my_user.nil?
      abort "User not found"
    end
    formatted_print_user_details ["Username", my_user['username']]
    formatted_print_user_details ["Email", my_user['email']]
    formatted_print_user_details ["Hakee yliopistoon", my_user['hakee_yliopistoon_2014']]
    formatted_print_user_details ["Koko nimi", my_user['koko_nimi']]
    missing_points = get_points_info_for_user(my_user, week_data)

    missing_points.each do |k,v|
      formatted_print_user_details [k, v.join(", ")]
    end
  end

  def formatted_print_user_details(details)
    puts "%18s: %-20s" % details
  end

  def fetch_week_datas(auth)
    base_url = "http://tmc.mooc.fi/mooc/courses/18/points/"
    weeks = %w(1 2 3 4 5 6 7 8 9 10 11 12)
    rest = ".json?api_version=7"
    week_data = {}
    weeks.each do |week|
      week_data[week] = JSON.parse(HTTParty.get(base_url + week + rest, basic_auth: auth).body)['users_to_points']
    end
    week_data
  end

  def list_and_filter_participants(json)
    wanted_fields = %W(username email koko_nimi)

    participants = json[:participants]
    week_data = json[:week_data]
    everyone_in_course = participants.size
    only_applying!(participants)
    hakee_yliopistoon = participants.size

    puts "%-20s %-35s %-25s %-120s" % ["Username", "Email", "Real name", "Missing points"]
    puts '-'*200
    participants.each do |participant|
      nice_string_in_array = wanted_fields.map do |key|
        participant[key]
      end
      if @options.show_completion_percentige
        nice_string_in_array << format_done_exercises_percents(done_exercise_percents(participant, participants))
      end
      if @options.show_missing_compulsory_points
        nice_string_in_array << missing_points_to_list_string(get_points_info_for_user(participant, week_data))
      end


      to_be_printed = "%-20s %-35s %-25s "
      to_be_printed << "%-180s " if @options.show_completion_percentige
      to_be_printed << "%-120s" if @options.show_missing_compulsory_points

      puts to_be_printed % nice_string_in_array
    end

    puts
    puts
    puts "Stats: "
    puts "%25s: %4d" % ["Kaikenkaikkiaan kurssilla", everyone_in_course]
    puts "%25s: %4d" % ["Hakee yliopistoon", hakee_yliopistoon]

  end


  def format_done_exercises_percents(hash)
    hash.map do |k|
      begin
        k = k.first
      "#{k[0].scan(/\d+/).first}: #{k[1]}"
      rescue
        nil
      end
    end.compact.join(", ")
  end


  def done_exercise_percents(participant, participants_data)
    user_info = participants_data.find{ |p| p['username'] == participant['username'] }
    exercise_weeks = user_info['groups']
    week_keys = (1..12).map{|i| "viikko#{i}"}

    week_keys.map do |week|
      details = exercise_weeks[week]
      unless details.nil?
        {week => ("%3.1f%" % [(details['points'].to_f / details['total'].to_f) * 100])}
      end
    end
  end

  def missing_points_to_list_string(missing_by_week)
    str = ""
    missing_by_week.keys.each do |week|
      missing = missing_by_week[week]
      unless missing.nil? or missing.length == 0
        str << week
        str << ": "
        str << missing.join(",")
        str << "  "
      end
    end

    str

  end

  def get_points_info_for_user(participant, week_data)
    # TODO: täydennä data viikolle 12
    compulsory_exercises = {'6' => %w(102.1 102.2 102.3 103.1 103.2 103.3), '7' => %w(116.1 116.2 116.3), '8' => %w(124.1 124.2 124.3 124.4),
                            '9' => %w(134.1 134.2 134.3 134.4 134.5), '10' => %w(141.1 141.2 141.3 141.4), '11' => %w(151.1 151.2 151.3 151.4), '12' => %w()}
    points_by_week = {}
    week_data.keys.each do |week|
      points_by_week[week] = week_data[week][participant['username']]
    end


    missing_by_week = {}
    points_by_week.keys.each  do |week|
      weeks_points = points_by_week[week] || [] #palauttaa arrayn
      weeks_compulsory_points = compulsory_exercises[week] || []
      missing_by_week[week] = weeks_compulsory_points - weeks_points
    end

    missing_by_week
  end

  def only_applying!(participants)
    participants.select! do |participant|
      participant['hakee_yliopistoon_2014']
    end
  end
end

ShowMoocData.new.run(ARGV)

__END__
