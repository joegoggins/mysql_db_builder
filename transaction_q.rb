# WARNING: HAVENT USED THIS CLASS YET
class DbBuilder::TransactionQ < DbBuilder::AbstractQ
  def execute(caller)
    raise "Your query param to DbBuilder::TransactionQ needs to be an array of queries to execute in a transaction" unless self.query.kind_of? Array
    ActiveRecord::Base.connection.transaction do
      self.query.each do |actual_sql|
        ActiveRecord::Base.connection.execute(actual_sql)
      end
    end
  end
end