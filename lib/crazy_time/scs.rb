module CrazyTime
  class nutsie_radio
    attr_accessor :date_string
    def strptime(string)
      # find the date in the string and cast to date
      string[/(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+).(\d+)/]
      # $1 year, $2 month, $3 day, $4 hour, $5 min, $6 sec, $7 milli
      @date = $1, $2, $3, $4, $5, $6, $7
      @date_string = date.strftime("%m-%d-%Y")
      return @date_string
    end
  
  end
end
    