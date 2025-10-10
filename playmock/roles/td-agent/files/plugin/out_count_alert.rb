require 'fluent/plugin/output'

class Fluent::Plugin::CountAlertOutput < Fluent::Plugin::Output
  Fluent::Plugin.register_output('count_alert', self)

  helpers :event_emitter, :timer

  PATTERN_MAX_NUM = 20

  config_param :for_time,       :time,    default: 30,
               desc: 'item clear time(sec).'
  config_param :interval,       :time, default: 60,
               desc: 'The interval time to count in seconds.'
  config_param :tag, :string, default: 'datacount',
               desc: 'The output tag.'
  config_param :count_key, :string,
               desc: 'The key to count in the event record.'
  config_param :output_values, :string,  default: "",
               desc: 'output value'
  config_param :count,         :integer, default: 1,
               desc: 'alert count'

  # pattern0 reserved as unmatched counts
  config_param :pattern1, :string, # string: NAME REGEXP
               desc: 'Specify RegexpName and Regexp. format: NAME REGEXP'
  (2..PATTERN_MAX_NUM).each do |i|
    config_param ('pattern' + i.to_s).to_sym, :string, default: nil, # NAME REGEXP
                 desc: "Specify RegexpName and Regexp. format: NAME REGEXP"
  end

  attr_accessor :tick
  attr_accessor :counts
  attr_accessor :last_checked

  def configure(conf)
    super

    @tick = @for_time.to_i
    @count_key = count_key

    @patterns = [[0, 'unmatched', nil]]
    pattern_names = ['unmatched']

    pattern_keys = conf.keys.select{|k| k =~ /^pattern(\d+)$/}
    invalids = pattern_keys.select{|arg| arg =~ /^pattern(\d+)/ and not (1..PATTERN_MAX_NUM).include?($1.to_i)}
    if invalids.size > 0
      log.warn "invalid number patterns (valid pattern number:1-20)", invalids: invalids
    end
    (1..PATTERN_MAX_NUM).each do |i|
      next unless conf["pattern#{i}"]
      name,regexp = conf["pattern#{i}"].split(' ', 2)
      @patterns.push([i, name, Regexp.new(regexp)])
      pattern_names.push(name)
    end
    pattern_index_list = conf.keys.select{|s| s =~ /^pattern\d$/}.map{|v| (/^pattern(\d)$/.match(v))[1].to_i}
    unless pattern_index_list.reduce(true){|v,i| v and @patterns[i]}
      raise Fluent::ConfigError, "jump of pattern index found"
    end
    unless @patterns.length == pattern_names.uniq.length
      raise Fluent::ConfigError, "duplicated pattern names"
    end

    if system_config.workers > 1
      log.warn "Fluentd is now working with multi process workers, and count_alert plugin will produce counter results in each separeted processes."
    end

    @counts = count_initialized
    @mutex = Mutex.new

    @output_values_array = []
    unless  @output_values.empty?
      @output_values_array = @output_values.split(',')
    end

    # DEBUG
    log.info "config :for_time       => #{@for_time}"
    log.info "config :interval       => #{@interval}"
    log.info "config :tag            => #{@tag}"
    log.info "config :count_key      => #{@count_key}"
    log.info "config :output_values  => #{@output_values}"
    log.info "config :count          => #{@count}"
    log.info "config :patterns       => #{@patterns}"
  end

  def multi_workers_ready?
    true
  end

  def start
    super

    @last_checked = Fluent::Engine.now
    timer_execute(:out_count_alert, @interval, &method(:watch))
  end

  def shutdown
    super
  end

  def count_initialized(keys=nil)
    # counts['tag'][num] = count
    # counts['tag'][-1] = sum
    if keys
      values = Array.new(keys.length) {|i|
        Array.new(@patterns.length + 1){|j| 0 }
      }
      Hash[[keys, values].transpose]
    else
      {}
    end
  end

  def countups(tag, counts)

    #DEBUG
    #log.info "count up : #{@counts}"

    @mutex.synchronize {
      if @counts[tag].nil?
        @counts[tag] = {}
      end
      counts.each_with_index do |rec, i|
        #DEBUG
        #log.info "count up : #{i}  #{rec}"
        if @counts[tag][rec[:name]].nil?
          @counts[tag][rec[:name]] = {}
          @counts[tag][rec[:name]][:first_time] = Fluent::Engine.now
          @counts[tag][rec[:name]][:cnt]        = 0
          @counts[tag][rec[:name]][:regexp]     = 0
          @counts[tag][rec[:name]][:emit]       = false
          @counts[tag][rec[:name]][:values]     = rec[:values]
        end
        @counts[tag][rec[:name]][:cnt] += 1
      end
    }
  end

  def flush_emit(message)
    # DEBUG
    #log.info "flush_emit: #{@tag} => #{message}"
    router.emit(@tag, time = Fluent::Engine.now, message)
  end

  def watch
    # instance variable, and public accessable, for test
    now = Fluent::Engine.now
    @counts.each { |tag, value|
      value.each { |name, rec|
        next if name.empty?
        next if rec.nil?
        #DEBUG
        #log.info "watch  name: #{name}"
        #log.info "watch  rec : #{rec}"
        @mutex.synchronize {
          if (rec[:cnt] >= @count) && (rec[:emit] == false)
            output_message = "Key:#{@count_key}\tPattern:#{name}\tStart:#{Time.at(rec[:first_time])}\tDetect:#{Time.at(Fluent::Engine.now)}\tCount:#{@count}"
            rec[:values].each{|value|
              output_message += "\t#{value.to_s}"
            }
            log.info "EMIT : #{name} => #{output_message}"
            flush_emit({@count_key => output_message})
            @counts[tag][name][:emit] = true
          end
          if Fluent::Engine.now - rec[:first_time] >= @tick
            log.info "CLEAR : #{name} #{rec}"
            @counts[tag][name] = nil
          end
        }
      }
    }
    @last_checked = now
  end

  def process(tag, es)
    c=[]
    for num in 0..@patterns.length-1 do
      c[num] = {:name=>"", :regexp=>""}
    end 

    dust_msg = true
    es.each do |time,record|
      value = record[@count_key]
      next if value.nil?

      value = value.to_s.force_encoding('ASCII-8BIT')
      matched = false
      @patterns.each do |index, name, regexp|
        next unless regexp and regexp.match(value)
        c[index][:name]   = name
        c[index][:regexp] = regexp.to_s.dup
        c[index][:values] = []
        @output_values_array.each {|key|
          if record[key.strip].nil?
            $log.warn "invalid output_values: #{key.strip}"
          else
            c[index][:values].push(record[key.strip])
          end
        }
        dust_msg = false
        matched = true
        break
      end
    end
    if dust_msg == true
      # DEBUG
      #$log.info "Dust msg: #{es}"
      return
    else
      countups(tag, c)
    end
  end

end
