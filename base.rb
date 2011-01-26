class DbBuilder::Base
  attr_accessor :on_exception # other options :return, :puts, :puts_and_exit
  
  attr_reader :queries, 
              :target_db, 
              :target_model,
              :debug_mode, # Inspects all kinds of stuff in the queries before and after
              :verbose_mode
  
  def initialize
    @on_exception = :raise # other options :return, :puts, :puts_and_exit
    @queries = []
    @debug_mode = true
    @verbose_mode = true # spits out all interpolated queries before executing them
    set_target_db
    set_target_model
    set_queries
    inject_query_callbacks 
  end
  
  @@query_callbacks = []
  def self.before(reference_q, worker_q)
    @@query_callbacks << DbBuilder::QueryCallback.new(:before, reference_q, worker_q)
  end
  def self.after(reference_q, worker_q)
    @@query_callbacks << DbBuilder::QueryCallback.new(:after, reference_q, worker_q)
  end
  
  def inject_query_callbacks
    @@query_callbacks.each do |q_callback|
      case q_callback.type
      when :before
        if q_callback.reference_q == :first
          @queries.insert(0, q_callback.worker_q)
        elsif q_callback.reference_q == :last
          @queries.insert(@queries.length - 1, q_callback.worker_q)
        end
      when :after
        if q_callback.reference_q == :first
          @queries.insert(1, q_callback.worker_q)
        elsif q_callback.reference_q == :last
          @queries.insert(@queries.length, q_callback.worker_q)
        end
      else
        raise 'Invalid q_callback.type'
      end
    end
  end 
  # Interpolates all strings into queries
  # 
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


  module MustOverride
    protected 
    def set_target_db
      raise "The child class must override the 'set_target_db' instance method."
    end
    
    def set_queries
      raise "The child class must override the 'set_queries' instance method."
    end
    
    def set_target_model
      raise "The child class must override the 'set_target_model' instance method."
    end    
  end
  include MustOverride
  
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
          puts error_string
        when :puts_and_exit
          puts error_string
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
      puts "[#{self.class.to_s}][Q=#{the_query.name}]
#{the_query.query}      
      " 
    end
    
    # BEFORE
    if @debug_mode && (ENV['DRY_RUN'].blank?)
      output_strings = []
      if self.target_model.nil?
         output_strings << "@target_model not set, no stats available"
      else
        if self.target_model.table_exists?
          output_strings << "Before Count: #{count_on_target}"
        else
          output_strings << "Does Not Exist: #{self.target_model.table_name}"
        end
      end
      render_debug_output_string(the_query,output_strings)
    end
    if ENV['DRY_RUN'].blank?
      the_query_result = the_query.execute(self)
    else
      puts "[#{self.class.to_s}] Dry Run"
      the_query_result = "N/A Dry Run"      
    end
    
    # AFTER
    if @debug_mode && (ENV['DRY_RUN'].blank?)
      output_strings = []
      if self.target_model.nil?
         output_strings << "@target_model not set, no stats available"
      else
        if self.target_model.table_exists?
          output_strings << "After Count: #{count_on_target}"
        else
          output_strings << "Does Not Exist: #{self.target_model.table_name}"
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
      puts "[#{self.class.to_s}][Q=#{the_query.name}] #{s}"
    end
  end
  
  def count_on_target
    ActiveRecord::Base.connection.select_value("SELECT count(*) FROM #{self.target_db}.#{self.target_model.table_name}")
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
    puts "[#{class_name}] Started\n"
    result = table_builder.execute
    t2 = Time.now
    puts "[#{class_name}] Finished in #{distance_of_time_in_words(t1,t2)}\n"
    if result.kind_of? String and result.match /ERROR/i
      puts "[#{class_name}] FAILED\n #{result}"      
    else
      puts "[#{class_name}] SUCCESS\n"
    end
  end
end
