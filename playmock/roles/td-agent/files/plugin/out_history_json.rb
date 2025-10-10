class Fluent::HistoryJson < Fluent::Output
  Fluent::Plugin.register_output('history_json', self)

  config_param :file, :string
  config_param :key, :string, :default => nil # nil allowed for json format

  def initialize
    super
  end

  def configure(conf)
    super

    begin
      File.open(@file, "r+").close
    rescue Errno::ENOENT
      File.open(@file, "w").close
    rescue => err
      raise Fluent::ConfigError, "invalid file name.(#{err.message})"
    end
  end

  def start
    super
  end

  def shutdown
    super
  end

  def format(tag, time, record)
    [tag, time, @format_proc.call(tag, time, record)].to_msgpack
  end

  def emit(tag, es, chain)
    yaml_hash={}

    begin
      yaml_str = File.read(@file)
      unless yaml_str.empty?
        yaml_hash=JSON.load(yaml_str)
      end
    rescue TypeError
    end

    es.each {|time,record|
      if record[@key].nil?
        raise Fluent::ConfigError, "invalid key: #{@key}"
      end
      value=record[@key].to_s
      if yaml_hash[value].nil?
        yaml_hash[value]={'first'=>Time.at(time).to_s, 'last'=>'-', 'count'=>1}
      else
        yaml_hash[value]['last']  = Time.at(time).to_s
        yaml_hash[value]['count'] += 1
      end
    }
    file=open(@file,"w")
    file.write(JSON.dump(yaml_hash))
    file.close
  end
end
