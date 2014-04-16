module MoocDataParser
  require 'io/console'
  class AuthCoordinator
    def auth
      print 'username: '
      username = $stdin.gets.strip
      print 'password: '
      password = $stdin.noecho(&:gets).strip
      puts
      {username: username, password: password}
    end
  end
end
