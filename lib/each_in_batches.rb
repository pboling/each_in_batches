# BolingForBatches
# Copyright ©2008-2015 Peter H. Boling, Brian Kidd, released under the MIT license
# Gem Plugin for Rails: A Better Way To Run Heavy Queries
# License:  MIT License
# Labels:   Ruby, Rails, Gem
# Project owners:
#    Peter Boling, Brian Kidd
require "each_in_batches/version"
require "active_record"

module EachInBatches

  class Batch

    attr_accessor :arel
    attr_accessor :verbose
    attr_accessor :batch_size
    attr_accessor :backwards
    attr_accessor :last_batch
    attr_accessor :first_batch
    attr_accessor :skipped_batches
    attr_accessor :offset_array
    attr_accessor :total_records
    attr_accessor :size_of_last_run
    attr_accessor :extra_run
    attr_accessor :num_runs
    attr_accessor :total_time
    attr_accessor :elapsed_time
    attr_accessor :start_time
    attr_accessor :end_time
    attr_accessor :overhead_time
    attr_accessor :completion_times
    attr_accessor :show_results

    def print_debug
      print "verbose: #{verbose}\nbatch_size: #{batch_size}\nbackwards: #{backwards}\nlast_batch: #{last_batch}\nfirst_batch: #{first_batch}\noffset_array: #{offset_array}\ntotal_records: #{total_records}\nsize_of_last_run: #{size_of_last_run}\nextra_run: #{extra_run}\nnum_runs: #{num_runs}\ntotal_time: #{total_time}\nelapsed_time: #{elapsed_time}\nstart_time: #{start_time}\nend_time: #{end_time}\noverhead_time: #{overhead_time}\ncompletion_times: #{completion_times.inspect}\nshow_results: #{show_results.inspect}\n"
    end

    def self.help_text
      <<-HEREDOC
          Arguments for the initializer (Batch.new) method are:

        Required:

          :arel         - Usage: :arel => MyClass.some_scope.order("some_column ASC")
                            Required, as this is the class that will be batched

        Optional:

          :backwards     - Usage: :backwards => true or false
                            Whether or not the batches should be processed in reverse order or not.
                            NOTE: deletions must be processed backwards or you eat the set as you process
                                  and end the run half way through
                            Default: false (if not provided)

          :verbose       - Usage: :verbose => true or false
                            Sets verbosity of output
                            Default: false (if not provided)

          :batch_size    - Usage: :batch_size => x
                            Where x is some number.
                            How many AR Objects should be processed at once?
                            Default: 50 (if not provided)

          :last_batch    - Usage: :last_batch => x
                            Where x is some number.
                            Only process up to and including batch #x.
                              Batch numbers start at 0 for the first batch.
                            Default: won't be used (no limit if not provided)

          :first_batch   - Usage: first_batch => x
                            Where x is some number.
                            Begin processing batches beginning at batch #x.
                              Batch numbers start at 0 for the first batch.
                            Default: won't be used (no offset if not provided)

          :show_results  - Usage: :show_results => true or false
                            Prints statistics about the results of Batch#run.
                            Default: true if verbose is set to true and :show_results is not provided, otherwise false

       EXAMPLE:

         To create a new Batch, call Batch#new and pass it the class and any additional arguements (all as a hash).

           batch = EachInBatches::Batch.new(:arel => Payment.canceled.order("transaction_id ASC"), :batch_size => 50)

         To process the batched data, pass a block to Batch#run the same way you would to an object returned by

           Klass.all.each {|x| x.method}

         Batch#run will pass the data to your block, one at a time, in batches set by the :batch_size argument.

           batch.run {|x| puts x.id; puts x.transaction_id}

         Print the results!

           batch.print_results

         Or...

         Consolidate your code if you prefer

           EachInBatches::Batch.new(:arel => Payment.canceled.order("transaction_id ASC"), :batch_size => 50, :show_results => true).run{|x| puts x.id; puts x.transaction_id}

       Interpreting the output:
         '[O]' means the batch was skipped due to an offset.
         '[L]' means the batch was skipped due to a limit.
         '[P]' means the batch is processing.
         '[C]' means the batch is complete.
         and yes... it was a coincidence.  This class is not affiliated with 'one laptop per child'
      HEREDOC
    end

    def self.check(*args)
      if args.empty?
        puts self.help_text and return false
        #Are the values of these parameters going to be valid integers?
      elsif args.first[:batch_size] && (args.first[:batch_size].to_s.gsub(/\d/,'foo') == args.first[:batch_size].to_s)
        puts self.help_text and return false
      elsif args.first[:last_batch] && (args.first[:last_batch].to_s.gsub(/\d/,'foo') == args.first[:last_batch].to_s)
        puts self.help_text and return false
      elsif args.first[:first_batch] && (args.first[:first_batch].to_s.gsub(/\d/,'foo') == args.first[:first_batch].to_s)
        puts self.help_text and return false
      else
        return true
      end
    end

    def initialize(*args)
      return false unless Batch.check(*args)
      @arel = args.first[:arel]
      @verbose = args.first[:verbose].blank? ? false : args.first[:verbose]
      @backwards = args.first[:backwards].nil? ? false : !(args.first[:backwards] == 'false' || args.first[:backwards] == false)
      @batch_size = args.first[:batch_size] ? args.first[:batch_size].is_a?(Integer) ? args.first[:batch_size] : args.first[:batch_size].to_i : 50
      @last_batch = args.first[:last_batch] ? args.first[:last_batch].is_a?(Integer) ? args.first[:last_batch] : args.first[:last_batch].to_i : false
      @first_batch = args.first[:first_batch] ? args.first[:first_batch].is_a?(Integer) ? args.first[:first_batch] : args.first[:first_batch].to_i : 0
      @show_results = case
        when args.first[:show_results].blank? && !verbose?; false
        when args.first[:show_results].blank? &&  verbose?; true
        else args.first[:show_results]
      end
      @total_time = 0
      @skipped_batches = []

      puts "Counting Records..." if verbose?
      @total_records = @arel.count
      @num_runs = @total_records / @batch_size
      @size_of_last_run = @total_records.modulo(@batch_size)

      if @size_of_last_run > 0
        @num_runs += 1
        @extra_run = true
      else
        @extra_run = false
      end

      puts "Records: #{@total_records}, Batches: #{@num_runs}" if verbose?

      @last_batch = @num_runs - 1 unless @num_runs == 0 || @last_batch #because batch numbers start at 0 like array indexes, but only if it was not set in *args

      current_batch = 0
      @offset_array = Array.new
      if verbose?
        puts "Batch Numbering Begins With 0 (ZERO) and counts up"
        puts "Batch Size (SQL Limit): #{@batch_size}" #This is the SQL Limit
        puts "First Batch # to run: #{@first_batch}" #This is the number of the first batch to run
        puts "Last Batch # to run: #{@last_batch}" # This is the number of the last batch to run
        puts "Batches Before First and After Last will be skipped."
        puts "Creating Batches:\n"
      end
      while current_batch < @num_runs
        @offset_array << (current_batch * @batch_size)
        print "." if verbose?
        current_batch += 1
      end
      puts " #{@num_runs} Batches Created" if verbose?
      #in order to use batching for record deletion, the offsets need to start with largest first
      if @backwards
        @offset_array.reverse!
        puts "Backwards Mode:" if verbose?
      else
        puts "Normal Mode:" if verbose?
      end
      if verbose?
        puts "  First Offset: #{@offset_array.first}"
        puts "  Last Offset: #{@offset_array.last}"
        # technically the last run doesn't need a limit, and we don't technically use a limit on the last run,
        #  but there are only that many records left to process,
        #  so the effect is the same as if a limit were applied.
        # We do need the limit when running the batches backwards, however
        if @extra_run
          if @backwards
            puts "  Limit of first run: #{@size_of_last_run}"
          else
            puts "  Size of Last Run: #{@size_of_last_run}"
          end
        end
        puts "  Limit of all #{@extra_run ? "other" : ""} runs: #{@batch_size}" #This is the SQL Limit
      end
    end

    def is_first_run?
      #if no batches have been completed then we are in a first run situation
      self.completion_times.empty?
    end

    def verbose?
      !!verbose
    end

    def run(&block)
      return false unless block_given?
      self.start_time = Time.current
      unless self.num_runs > 0
        puts "There are no batches to run" if verbose?
        return false
      end
      self.total_time = 0
      self.completion_times = Array.new
      self.offset_array.each_with_index do |offset, current_batch|
        if self.backwards && self.is_first_run?
          limite = self.size_of_last_run
        else
          limite = self.batch_size
        end
        if self.first_batch > current_batch
          print "[O] #{show_status(current_batch, limite)} skipped" if verbose?
          self.skipped_batches << current_batch
        elsif self.last_batch && self.last_batch < current_batch
          print "[L] #{show_status(current_batch, limite)} skipped" if verbose?
          self.skipped_batches << current_batch
        else
          print "[P] #{show_status(current_batch, limite)}" if verbose?

          #start the timer
          beg_time = Time.current

          self.arel.limit(limite).offset(offset).each {|obj| yield obj}

          #stop the timer
          fin_time = Time.current

          this_time = fin_time.to_i - beg_time.to_i
          self.total_time += this_time unless extra_run && current_batch == self.num_runs
          puts "[C] #{show_status(current_batch, limite)} in #{this_time} seconds" if verbose?
          self.completion_times << [current_batch, {:elapsed => this_time, :begin_time => beg_time, :end_time => fin_time}]
        end
      end
      self.num_runs -= 1 if self.extra_run
      self.end_time = Time.current
      self.elapsed_time = (self.end_time.to_i - self.start_time.to_i)
      self.overhead_time = self.elapsed_time - self.total_time
      print_results if self.show_results
      puts "Process Complete" if verbose?
      return true
    end

    def show_status(current_batch, limite)
      "{#{current_batch} / #{self.last_batch} / #{limite}}"
    end

    # Allow caller to override verbosity when called from console
    def print_results(verbose = self.verbose)
      printf "Results..."
      printf "Average time per complete batch was %.1f seconds\n", (self.total_time/Float(self.num_runs)) unless self.num_runs < 1
      printf "Total time elapsed was %.1f seconds, about #{self.elapsed_time/60} minute(s)\n", (self.elapsed_time)
      if self.backwards # When backwards might be deleting records
        puts "Total # of #{self.arel.table} - Before: #{self.total_records}"
        puts "Total # of #{self.arel.table} - After : #{self.arel.count}"
      end
      # With a large number of batches this is far too verbose, but don't want to introduce a more complicated verbosity setting.
      # if verbose?
      #   puts "Completion times for each batch:"
      #   self.completion_times.each do |x|
      #     puts "Batch #{x[0]}: Time Elapsed: #{x[1][:elapsed]}s, Begin: #{x[1][:begin_time].strftime("%m.%d.%Y %I:%M:%S %p")}, End: #{x[1][:end_time].strftime("%m.%d.%Y %I:%M:%S %p")}"
      #   end
      # end
    end

  end
end
