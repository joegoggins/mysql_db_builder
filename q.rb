# A class for encapsulating a single SQL query
class DbBuilder::Q < DbBuilder::AbstractQ  
  def execute(caller)
    ActiveRecord::Base.connection.send(self.query_method,self.query)
  end
  
  def to_s(format=:short)
x = <<-EOS
:#{self.name} => (#{self.description})
EOS
    if format == :long
      x << "\n#{self.query}"
    end
    x
  end  
end
