# BolingForBatches
#Copyright ©2008 Peter H. Boling, released under the MIT license
#Plugin for Rails: A Better Way To Run Heavy Queries
#License:  MIT License
#Labels:   Ruby, Rails, Plugin
#Project owners:
#    peter.boling
module BolingForBatches

  class Batch
    #We need to include this so we have access to the pluralize method we're using in the print_results
    include ActionView::Helpers::TextHelper

    attr_accessor :klass
    attr_accessor :verbose
    attr_accessor :include
    attr_accessor :select
    attr_accessor :conditions
    attr_accessor :order
    attr_accessor :batch_size
    attr_accessor :last_batch
    attr_accessor :first_batch
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
    attr_accessor :method_name
  
    def print_debug
      print "klass: #{klass}\nverbose: #{verbose}\ninclude: #{include}\nselect: #{select}\nconditions: #{conditions}\norder: #{order}\nbatch_size: #{batch_size}\nlast_batch: #{last_batch}\nfirst_batch: #{first_batch}\noffset_array: #{offset_array}\ntotal_records: #{total_records}\nsize_of_last_run: #{size_of_last_run}\nextra_run: #{extra_run}\nnum_runs: #{num_runs}\ntotal_time: #{total_time}\nelapsed_time: #{elapsed_time}\nstart_time: #{start_time}\nend_time: #{end_time}\noverhead_time: #{overhead_time}\ncompletion_times: #{completion_times.inspect}\nmethod_name: #{method_name}\n"
    end
    
    def self.help_text
      "Options are:
  
        :klass         - Usage: :klass => MyClass
                          Required, as this is the class that will be batched
  
        :include       - Usage: :include => [:assoc]
                          Optional
  
        :select       - Usage: :select => \"DISTINCT field_name\"
                                    or
                               :select => \"field1, field2, field3\"
  
        :order         - Usage: :order => \"field DESC\"
  
        :conditions    - Usage: :conditions => [\"field1 is not null and field2 = ?\", x]
  
        :verbose       - Usage: :verbose => 'yes' or 'no'
                          Sets verbosity of output
                        Default: yes (if not provided)
                        
        :batch_size    - Usage: :batch_size => x
                          Where x is some number.
                          How many AR Objects should be processed at once?
                        Default: 50 (if not provided)
                        
        :last_batch   - Usage: :last_batch => x
                          Where x is some number.
                          Only process up to and including batch #x.
                            Batch numbers start at 0 for the first batch.
                        Default: won't be used (no limit if not provided)
                        
        :first_batch  - Usage: first_batch => x
                          Where x is some number.
                          Begin processing batches beginning at batch #x.
                            Batch numbers start at 0 for the first batch.
                        Default: won't be used (no offset if not provided)
                      
        EXAMPLE:
            #Setup your new batch, and tell it what options to use, and what class to run batches of
            batch = BolingForBatches::Batch.new(:klass => Payment, :select => \"DISTINCT transaction_id\", :batch_size => 50, :order => 'transaction_id')
            #Run a specific instance method on each record in each batch
            batch.run(:remove_duplicates, false, true, true)
            #Print the results!
            batch.print_results
        
        Interpreting the output:
          '[O]' means the batch was skipped due to an offset.
          '[L]' means the batch was skipped due to a limit.
          '[P]' means the batch is processing.
          '[C]' means the batch is complete.
          and yes... it was a coincidence.  This class is not affiliated with 'one laptop per child'
        "
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
      @klass = args.first[:klass]
      @include = args.first[:include]
      @select = args.first[:select]
      @order = args.first[:order]
      @conditions = args.first[:conditions]
      @verbose = args.first[:verbose].nil? ? true : args.first[:verbose]
      @batch_size = args.first[:batch_size] ? args.first[:batch_size].is_a?(Integer) ? args.first[:batch_size] : args.first[:batch_size].to_i : 50
      @last_batch = args.first[:last_batch] ? args.first[:last_batch].is_a?(Integer) ? args.first[:last_batch] : args.first[:last_batch].to_i : false
      @first_batch = args.first[:first_batch] ? args.first[:first_batch].is_a?(Integer) ? args.first[:first_batch] : args.first[:first_batch].to_i : 0
      
      puts "Counting Records" if self.verbose
      @total_records = @klass.count(:all, :include => @include, :conditions => @conditions)
      @num_runs = @total_records / @batch_size
      puts "Records: #{@total_records}, Batches: #{@num_runs}" if @verbose
      @size_of_last_run = @total_records.modulo(@batch_size)
  
      if @size_of_last_run > 0
        @num_runs += 1
        @extra_run = true
      else
        @extra_run = false
      end
      
      current_batch = 0
      @offset_array = Array.new
      if @verbose
        puts "Batch Numbering Begins With 0 (ZERO)"
        puts "Batch Size (SQL Limit): #{@batch_size}" #This is the SQL Limit
        puts "First Batch # to run: #{@first_batch}" #This is the number of the first batch to run
        puts "Creating Batches:\n"
      end
      while current_batch < @num_runs
        @offset_array << (current_batch * @batch_size)
        print '.' if @verbose
        current_batch += 1
      end
      @last_batch = @num_runs - 1 unless @last_batch #because batch numbers start at 0 like array indexes, but only if it was not set in *args
      if @verbose
        puts "\n#{@num_runs} Batches Created"
        puts "Last Batch # to run: #{@last_batch}" # This is the number of the last batch to run
        puts "Batches Before First and After Last will be skipped."
      end
    end
  
    def run(mname = nil, *args)
      self.start_time = Time.now
      return false if mname.nil?
      puts 'There are no batches to run' and return false unless self.num_runs > 0
      self.method_name = mname.is_a?(Symbol) ? mname : mname.to_s.to_sym
      current_batch = 0
      self.total_time = 0
      self.completion_times = Array.new
      for offset in self.offset_array
        if self.first_batch > current_batch
          print "[O] {#{current_batch} / #{self.last_batch}}" if self.verbose
        elsif self.last_batch && self.last_batch < current_batch
          print "[L] {#{current_batch} / #{self.last_batch}}" if self.verbose
        else
          print "[P] {#{current_batch} / #{self.last_batch}} " if self.verbose
          
          #start the timer
          beg_time = Time.now
  
          self.klass.find(:all, :offset => offset, :select => self.select, :limit => self.batch_size, :include => self.include, :conditions => self.conditions, :order => self.order).each do |x|
            result = x.send(self.method_name.to_sym, *args)
            print result if result.is_a?(String)
          end
          
          #stop the timer
          fin_time = Time.now
          
          this_time = fin_time.to_i - beg_time.to_i
          self.total_time += this_time unless extra_run && current_batch == self.num_runs
          puts "\n[C] {#{current_batch} / #{self.last_batch}} in #{this_time} seconds" if self.verbose
          self.completion_times << [current_batch, {:elapsed => this_time, :begin_time => beg_time, :end_time => fin_time}]
        end
        current_batch += 1
      end
      self.num_runs -= 1 if self.extra_run
      self.end_time = Time.now
      self.elapsed_time = (self.end_time.to_i - self.start_time.to_i)
      self.overhead_time = self.elapsed_time - self.total_time
    end
  
    def print_results(verbose = true)
      printf "Average time per complete batch was %.1f seconds\n", (self.total_time/Float(self.num_runs)) unless self.num_runs < 1
      printf "Total time elapsed was %.1f seconds (about #{pluralize(self.elapsed_time/60, 'minute')})\n", (self.elapsed_time)
      printf "Total time spent outside batched method (#{self.klass}##{self.method_name}) was %.1f seconds (about #{pluralize(self.overhead_time/60, 'minute')})\n", (self.overhead_time)
      puts "Total # of #{self.klass.to_s.pluralize} - Before: #{self.total_records}"
      puts "Total # of #{self.klass.to_s.pluralize} - After : #{self.klass.count(:include => self.include, :conditions => self.conditions)}"
      if verbose
        puts "Completion times for each batch:"
        self.completion_times.each do |x|
          puts "Batch #{x[0]}: Time Elapsed: #{x[1][:elapsed]}s, Begin: #{x[1][:begin_time].strftime("%m.%d.%Y %I:%M:%S %p")}, End: #{x[1][:end_time].strftime("%m.%d.%Y %I:%M:%S %p")}"
        end
      end
    end
  
  end
end

#Copyright ©2008 Peter H. Boling, released under the MIT license
