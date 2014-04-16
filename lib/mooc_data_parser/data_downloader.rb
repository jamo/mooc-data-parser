
module MoocDataParser
  require 'httparty'
  require 'json'
  class DataDownloader

    def initialize(notes)
      @notes = notes
    end

    def download!
      auth = get_auth()
      thread = get_process_thread()
      url = "http://tmc.mooc.fi/mooc/participants.json?api_version=7&utf8=%E2%9C%93&filter_koko_nimi=&column_username=1&column_email=1&column_koko_nimi=1&column_hakee_yliopistoon_2014=1&group_completion_course_id=18"
      user_info = JSON.parse(HTTParty.get(url, basic_auth: auth).body)['participants']
      week_data = fetch_week_datas(auth)
      @notes['user_info'] = user_info.clone
      @notes['week_data'] = week_data.clone
      thread.kill
      puts
      {participants: user_info, week_data: week_data}
    end

    def get_auth
      AuthCoordinator.new.auth
    end

    def get_process_thread
      t = -> do
        loop do
          print '.'
          sleep 0.5
        end
      end
      Thread.new(&t)
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
  end
end
