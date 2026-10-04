require "./haversack_tasks"

begin
  HaversackTasks.main(ARGV)
rescue ex
  STDERR.puts ex.message
  exit 1
end
