module Xen
  module Parentable
    # Returns the parent Domain object (d) for a sub-object. 
    # We ensure d.instance.object_id == self.object_id
    # 
    # ==== Example
    #   i = Xen::Instance.all[2]
    #   d = i.domain
    #   # i.object_id == d.instance.object_id
    #
    def domain
      d = Xen::Domain.new(name)
      d.instance_variable_set("@#{self.class.to_s.sub('Xen::','').downcase}", self)
      d
    end
  end
  
  class Commands
    def self.xm_info
      `xm info`
    end
    def self.xen_list_images
      `xen-list-images`
    end    
  end
  
  class Host
    attr_reader :host, :machine, :total_memory, :free_memory
    
    def initialize
      result = Xen:Commands.xm_info
      result.scan(/(\S+)\s*:\s*([^\n]+)/).each do |i,j| 
        instance_variable_set("@#{i}", j)
      end
    end
  end
  

  class Domain
    attr_accessor :name, :image, :config, :instance
  
    def initialize(name)
      @name = name
      @config = Xen::Config.find(name)
      @instance = Xen::Instance.find(name)
      @image = Xen::Image.find(name)
    end
  
    def self.find(*args)
      options = args.extract_options!
      case args.first
        when :all       then Xen::Config.find(:all, options).collect { |config| config.domain }
        when :running   then Xen::Instance.find(:all, options).collect { |instance| instance.domain }
        # Retrieve a Domain by name
        else            Xen::Config.find_by_name(args.first) && self.new(args.first)
      end
    end
    
    def all(options={})
      self.find(:all, options)
    end
  
    def running?
      @instance
    end
  end


  class Config
    include Xen::Parentable
    attr_reader :name, :memory, :ip
  
    def initialize(*args)
      options = args.extract_options!
      @name = args.first
      @memory = options[:memory] || nil
      @ip = options[:ip] || nil
    end
  
    def self.find(*args)
      options = args.extract_options!
      case args.first
        when :all       then all
        else            find_by_name(args.first)
      end
    end

    def self.all
      result = Xen::Commands.xen_list_images
      configs = result.scan(/Name: (\w+)\nMemory: (\w+)\nIP: (\S+)/)
      configs.collect do |config|
        name, memory, ip = config
        new(name, :memory => memory, :ip => ip)
      end
    end    
  
    def self.find_by_name(name)
      return new('Domain-0') if name == 'Domain-0' 
      all.detect {|config| puts config; config.name == name.to_s}
    end
  end


  class Image
    include Xen::Parentable
    attr_accessor :name
  
    def initialize(name)
      @name = name
    end
  
    def self.find(name)
      new name
    end
  end


  class Instance
    include Xen::Parentable
    attr_reader :name, :domid, :memory, :cpu_time, :vcpus, :state, :start_time
  
    def initialize(name, options={})
      @name       = name
      @domid      = options[:domid] || nil 
      @memory     = options[:memory] || nil
      @cpu_time   = options[:cpu_time] || nil
      @vcpus      = options[:vcpus] || nil
      @state      = options[:state] || nil
      @start_time = options[:start_time] || nil
    end
    
    def self.find(*args)
      options = args.extract_options!
      case args.first
        when :all       then all
        else            find_by_name(args.first)
      end
    end
  
    def self.all
      result = `xm list`
      # XXX check for failed command
      result_array = result.split("\n")
      result_array.shift
      result_array.collect do |domain|
        name, domid, memory, vcpus, state, cpu_time = domain.scan(/[^ ,]+/)
        new(name, :domid => domid, :memory => memory, :cpu_time => cpu_time)
      end
    end
  
    def self.find_by_name(name)
      all.detect{|domain| domain.name == name.to_s }
    end
  
    # XXX Rails version - we need some error checking! 
    #
    # def self.find_by_name(name, options)
    #   if result = find_every(options)
    #     result.detect{ |domain| domain.name == name }
    #   else
    #     raise RecordNotFound, "Couldn't find domain with name=#{name}"
    #   end
    # end
    
    # A convenience wrapper for <tt>find(:dom0)</tt>.</tt>.
    def self.dom0(*args)
      find_by_name(:dom0)
    end
  
    def uptime
      start_time ? Time.now - start_time : nil
    end
  
    def running?
      output = `xm list #{name}`
      $? == 0 ? true : false
    end
  
    def start
      output = `xm create #{name}.cfg`
      $? == 0 ? true : false
    end
  
    def shutdown
      output = `xm shutdown #{name}`
      $? == 0 ? true : false
    end
  
    def reboot
      `xm reboot #{name}`
      $? == 0 ? true : false
    end
  
    def destroy
    end
  
    def pause
    end
  
  end

  class Backup
    include Xen::Parentable
  end
  
end

class Array #:nodoc:
  # Extracts options from a set of arguments. Removes and returns the last
  # element in the array if it's a hash, otherwise returns a blank hash.
  #
  #   def options(*args)
  #     args.extract_options!
  #   end
  #
  #   options(1, 2)           # => {}
  #   options(1, 2, :a => :b) # => {:a=>:b}
  def extract_options!
    last.is_a?(::Hash) ? pop : {}
  end
end