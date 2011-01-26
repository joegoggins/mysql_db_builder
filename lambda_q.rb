# The third argument is expected to be a lambda
class DbBuilder::LambdaQ < DbBuilder::AbstractQ  
  def execute(caller)
    raise "Your worker query in LambdaQ was not a lambda" unless self.query.kind_of? Proc
    # Bind the lambda code to the caller (which will be a DbBuilder instance)
    # and call it, this will give it access to db builder instance variables 
    self.query.bind(caller).call
  end  
end