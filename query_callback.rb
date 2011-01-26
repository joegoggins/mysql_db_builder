class DbBuilder::QueryCallback
  attr_accessor :type, :reference_q, :worker_q
  def initialize(type, reference_q, worker_q)
    raise "Invalid callback type must be after or before" unless [:after,:before].include?(type)
    raise "worker query must respond to .execute" unless worker_q.respond_to? :execute
    @type = type
    @reference_q = reference_q
    @worker_q = worker_q
  end
end