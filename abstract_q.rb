# All DbBuilder::<ANYTHING>Q objects inherit from this
#
class DbBuilder::AbstractQ
  attr_accessor :name, :description, :query, :query_method
  def initialize(name, description, query, query_method=:execute)
    @name = name
    @description = description
    @query = query
    
    # This determines what Ruby function gets called on the query object, options are
    # :insert_sql
    # :update_sql
    @query_method = query_method
  end
  
  def execute(caller)
    raise "CHILD MUST OVERRIDE THIS"
  end
  
  # CHILDREN SHOULD OVERRIDE THIS
  def to_s(format=:short)
    x = <<-EOS
    :#{self.name} => (#{self.description})
    EOS
  end
end