
module MoocDataParser
  require 'httparty'
  require 'json'
  class DataDownloader

    def download
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

  end
end
