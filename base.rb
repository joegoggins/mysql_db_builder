class DbBuilder::Base
  attr_accessor :on_exception # other options :return, :puts, :puts_and_exit
  
  attr_reader :debug_mode, # Inspects all kinds of stuff in the queries before and after
              :verbose_mode,
              :target_table
  
  def initialize
    @on_exception = :raise # other options :return, :puts, :puts_and_exit
    @queries = []
    @debug_mode = true
    @verbose_mode = true # spits out all interpolated queries before executing them
  end
 
  def target_db
    set_target_db
    @target_db
  end 

  def source_db
    set_source_db
    @source_db
  end

  def queries
    set_queries
    @queries
  end

  def target_table
    set_target_table
    @target_table
  end

  def to_s
    r = ''
    @queries.each_with_index do |q,i|
      r << <<-EOS
==========================================================================
Q#{i} #{q.to_s(:long)}
==========================================================================
EOS
    end
    r
  end
  
  def output(msg,options={})
    puts "#{msg}"
  end
  def self.output(msg,options={})
    puts "#{msg}"
  end


  module Overridable
    protected
    def set_source_db
      raise "The child class must override the 'set_source_db' instance method."
    end
    def set_target_db
      raise "The child class must override the 'set_target_db' instance method."
    end
    
    def set_queries
      raise "The child class must override the 'set_queries' instance method."
    end
    
    def set_target_table
      # Override if you want before and after counts stats on the tables
    end    
  end
  include Overridable
  
  def execute
    self.queries.each_with_index do |q,i|
      begin
        execute_query(q)
      rescue Exception => e
        error_string = <<-EOS
==========================================================================
FAILURE on #{self.class.to_s}
QUERY #{i}: #{q.to_s}
EXCEPTION:
#{e.to_s}
==========================================================================
        EOS
        case self.on_exception
        when :raise
          # for the console
          raise e
        when :return
          return error_string
        when :puts
          self.output error_string
        when :puts_and_exit
          self.output error_string
          exit
        end
      end        
    end
    return true
  end

  # either takes a symbol of a name of a query (handy for console usage)
  # or an instance of the query
  def execute_query(q_or_q_name_sym)
    if q_or_q_name_sym.kind_of?(Symbol) || q_or_q_name_sym.kind_of?(String)
      the_query = @queries.find {|x| x.name == q_or_q_name_sym.to_sym}
    elsif q_or_q_name_sym.kind_of?(DbBuilder::AbstractQ)
      the_query = q_or_q_name_sym
    else
      raise "Only know how to do stuff with symbols, strings, or "
    end
    if @verbose_mode
      self.output "[#{self.class.to_s}][Q=#{the_query.name}]
#{the_query.query}      
      " 
    end
    
    # BEFORE
    if @debug_mode && (ENV['DRY_RUN'].blank?)
      output_strings = []
      if self.target_table.nil?
         output_strings << "@target_table not set, no before stats available"
      else
        if self.target_table_exists?
          output_strings << "Before Count: #{count_on_target}"
        else
          output_strings << "Does Not Exist: #{self.target_table}"
        end
      end
      render_debug_output_string(the_query,output_strings)
    end
    if ENV['DRY_RUN'].blank?
      the_query_result = the_query.execute(self)
    else
      self.output "[#{self.class.to_s}] Dry Run"
      the_query_result = "N/A Dry Run"      
    end
    
    # AFTER
    if @debug_mode && (ENV['DRY_RUN'].blank?)
      output_strings = []
      if self.target_table.nil?
         output_strings << "@target_table not set, no after stats available"
      else
        if self.target_table_exists?
          output_strings << "After Count: #{count_on_target}"
        else
          output_strings << "Does Not Exist: #{self.target_table}"
        end      
      end
      case the_query.query_method
      when :execute
        # Do nothing
        #output_strings << "Query type not specified"
      when :insert_sql
        output_strings << "Insert Statement last insert id #{the_query_result}"
      when :update_sql
        output_strings << "Update Statement Affected #{the_query_result}"
      else
        raise "invalid query_method"
      end
      render_debug_output_string(the_query,output_strings)
    end
  end
  
  def render_debug_output_string(the_query,output_strings)
    output_strings.each do |s|
      self.output "[#{self.class.to_s}][Q=#{the_query.name}] #{s}"
    end
  end
  
  # returns a hash if exists, which is true, returns nil otherwise...
  # NOTE: if you don't have mysql permissions it won't work (but in this
  # case you probably have bigger issues)
  def target_table_exists?
    ActiveRecord::Base.connection.select_one("select * from information_schema.tables where 
                                              table_name='#{self.target_table}' 
                                              and table_schema='#{self.target_db}'")
  end

  def count_on_target
    ActiveRecord::Base.connection.select_value("SELECT count(*) FROM #{self.target_db}.#{self.target_table}")
  end
  
  def affected_rows
    # not sure
  end
  
  # A helper for calling from Rake Tasks, liked the distance_of_time_in_words method, hence the extend
  #  
  extend ActionView::Helpers::DateHelper
  def self.execute_and_output(class_name)
    table_builder = class_eval("#{class_name}.new")
    t1 = Time.now
    self.output "[#{class_name}] Started\n"
    result = table_builder.execute
    t2 = Time.now
    self.output "[#{class_name}] Finished in #{distance_of_time_in_words(t1,t2)}\n"
    if result.kind_of? String and result.match /ERROR/i
      self.output "[#{class_name}] FAILED\n #{result}"      
    else
      self.output "[#{class_name}] SUCCESS\n"
    end
  end
end
