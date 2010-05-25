require 'tempfile'

helpers do

  # service_name
  #
  # Return our virtual server name as a minimal URL.
  #
  # Safety note: HTTP_HOST, according to the rack docs, is preffered
  # over SERVER_NAME if it the former exists, but it can be borken -
  # sometimes comes with port attached! SERVER_NAME is always defined.

  def service_name
    'http://' + 
      (@env['HTTP_HOST'] || @env['SERVER_NAME']).gsub(/:\d+$/, '') +
      (@env['SERVER_PORT'] == '80' ? '' : ":#{@env['SERVER_PORT']}")
  end

end 
