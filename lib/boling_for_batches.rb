# BolingForBatches
# Copyright ©2008-2015 Peter H. Boling, released under the MIT license
# Gem Plugin for Rails: A Better Way To Run Heavy Queries
# License:  MIT License
# Labels:   Ruby, Rails, Gem
# Project owners:
#    peter.boling
require "boling_for_batches/version"

module BolingForBatches

  class Batch
    #We need to include this so we have access to the pluralize method we're using in the print_results
    include ActionView::Helpers::TextHelper

    attr_accessor(:klass,
                  :verbose,
                  :include,
                  :select,
                  :conditions,
                  :order,
                  :batch_size,
                  :last_batch,
                  :first_batch,
                  :offset_array,
                  :total_records,
                  :size_of_last_run,
                  :extra_run,
                  :num_runs,
                  :total_time,
                  :elapsed_time,
                  :start_time,
                  :end_time,
                  :overhead_time,
                  :completion_times,
                  :skipped_batches,
                  :method_name,
                  :backwards,
                  :method_klass,
                  :send_batch,
                  :run_klass_method,
                  :before_klass_method,
                  :after_klass_method,
                  :before_instance_method,
                  :after_instance_method,
                  :error_notification,
                  :skip_errors)

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

        :verbose       - Usage: :verbose => true # or any of ['true','false',false] or an integer value 0, 1, 2 with 0 being no output, and 2 being most verbose
                          Sets verbosity of output
                        Default: true (if not provided)

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

        :backwards    - Usage: :backwards => true # or any of ['true','false',false]
                          When running a batch backwards the offsets will go from large to small.
                          This makes it possible to batch deletion of records,
                            and not have the offset outgrow the record stack halfway through the run
                        Default: false

        :method_klass - Usage: :method_klass => 'MyClass'
                          Instead of calling a method on each record, you can instead send the record to a Class method
                        Default: won't be used (no method_klass if not provided)

        :run_klass_method   - Usage: :run_klass_method => true # or any of ['true','false',false]
                          Should method passed to run be called as a class method (:method_klass) or as an instance method on each individual records
                        Default: true if not provided and send_batch is true, otherwise false (runs as an instance method on each record)
                        Requires :method_klass to be provided

        :before_klass_method - Usage: :before_klass_method => 'somemethod'
                          a method (no params allowed) to call on the :method_klass before each batch is run
                        Default: won't be used (no before_klass_method if not provided)
                        Requires :method_klass to be provided

        :after_klass_method - Usage: :after_klass_method => 'somemethod'
                          a method (no params allowed) to call on the :method_klass after each batch is run
                        Default: won't be used (no after_klass_method if not provided)
                        Requires :method_klass to be provided

        :send_batch   - Usage: :send_batch => true # or any of ['true','false',false]
                          This will cause the entire batch to be sent to the method (when using a method_klass), instead of individual records
                        Default: false
                        Requires :method_klass to be provided

        :before_instance_method - Usage: :before_instance_method => 'somemethod'
                          a method (no params allowed) to call on each record of each batch
                        Default: won't be used (no before_instance_method if not provided)

        :after_instance_method - Usage: :after_instance_method => 'somemethod'
                          a method (no params allowed) to call on each record of each batch
                        Default: won't be used (no after_instance_method if not provided)

        :error_notification - Usage: :error_notification => {:mailer => 'MailerClass', :delivery_method => 'deliver_notification', :recipients => 'asdf@example.com', :subject_prefix => '[BFB]'}
                          Will be called as follows: MailerClass.deliver_notification('asdf@example.com', '[BFB]' + subject, error_message)

        :skip_errors  - Usage: :skip_errors => true # or any of ['true','false',false]
                          Will cause the batch procedure to continue with the next iteration in the batch if an error occurs by rescuing the error
                        Default: false

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
          { x / x / x } means { batch# / total batches / limit [P] or length [C] of records in batch)
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
      #Accommodate verbose whether passed in as as a Boolean, String or Integer
      @verbose = case args.first[:verbose]
                   when nil then 2
                   when 'false' then 0
                   when false then 0
                   when true then 2
                   when 'true' then 2
                   else args.first[:verbose]
                 end
      @backwards = args.first[:backwards].nil? ? false : !(args.first[:backwards] == 'false' || args.first[:backwards] == false)
      @skip_errors = args.first[:skip_errors].nil? ? false : !(args.first[:skip_errors] == 'false' || args.first[:skip_errors] == false)
      @error_notification = args.first[:error_notification].is_a?(Hash) ? args.first[:error_notification] : {}
      @method_klass = args.first[:method_klass].blank? ? nil : Kernel.const_get(args.first[:method_klass])
      @send_batch = args.first[:method_klass].nil? || args.first[:send_batch].nil? ? false : !(args.first[:send_batch] == 'false' || args.first[:send_batch] == false)
      @run_klass_method = args.first[:method_klass].nil? ? nil : args.first[:run_klass_method].blank? ? args.first[:send_batch] : args.first[:run_klass_method]
      @before_klass_method = args.first[:method_klass].nil? || args.first[:before_klass_method].blank? ? nil : args.first[:before_klass_method]
      @after_klass_method = args.first[:method_klass].nil? || args.first[:after_klass_method].blank? ? nil : args.first[:after_klass_method]
      @before_instance_method = args.first[:before_instance_method].blank? ? nil : args.first[:before_instance_method]
      @after_instance_method = args.first[:after_instance_method].blank? ? nil : args.first[:after_instance_method]
      @batch_size = args.first[:batch_size] ? args.first[:batch_size].is_a?(Integer) ? args.first[:batch_size] : args.first[:batch_size].to_i : 50
      @last_batch = args.first[:last_batch] ? args.first[:last_batch].is_a?(Integer) ? args.first[:last_batch] : args.first[:last_batch].to_i : false
      @first_batch = args.first[:first_batch] ? args.first[:first_batch].is_a?(Integer) ? args.first[:first_batch] : args.first[:first_batch].to_i : 0
      @total_time = 0
      @completion_times = []
      @skipped_batches = []

      puts "Counting Records..." if self.verbose
      @total_records = @klass.count(:all, :include => @include, :conditions => @conditions)
      @num_runs = @total_records / @batch_size
      @size_of_last_run = @total_records.modulo(@batch_size)

      if @size_of_last_run > 0
        @num_runs += 1
        @extra_run = true
      else
        @extra_run = false
      end

      puts "#{klass} Records: #{@total_records}, Batches: #{@num_runs}" if @verbose

      @last_batch = @num_runs - 1 unless @num_runs == 0 || @last_batch #because batch numbers start at 0 like array indexes, but only if it was not set in *args

      current_batch = 0
      @offset_array = Array.new
      if @verbose
        puts "Batch Numbering Begins With 0 (ZERO) and counts up"
        puts "First Batch # to run: #{@first_batch}" #This is the number of the first batch to run
        puts "Last Batch # to run: #{@last_batch}" # This is the number of the last batch to run
        puts "Batches Before First and After Last will be skipped."
        puts "Creating Batches:\n"
      end
      while current_batch < @num_runs
        @offset_array << (current_batch * @batch_size)
        print '.' if @verbose
        current_batch += 1
      end
      puts " #{@num_runs} Batches Created" if @verbose
      #in order to use batching for record deletion, the offsets need to start with largest first
      if @backwards
        @offset_array.reverse!
        puts "Backwards Mode:" if @verbose
      else
        puts "Normal Mode:" if @verbose
      end
      if @verbose
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
        puts "  Limit of all #{@extra_run ? 'other' : ''} runs: #{@batch_size}" #This is the SQL Limit
      end
    end

    def is_first_run?(current_batch)
      #if no batches have been completed then we are in a first run situation
      self.completion_times.empty?
    end

    def run(mname = nil, *args)
      self.run_around(mname) do |record|
        if self.before_instance_method
          if self.send_batch
            record.each do |rec|
              rec.send(self.before_instance_method.to_sym)
            end
          else
            record.send(self.before_instance_method.to_sym)
          end
        end
        self.method_klass.send(self.before_klass_method.to_sym) if self.before_klass_method
        if self.run_klass_method
          result = self.method_klass.send(self.method_name.to_sym, record, *args)
        else
          result = record.send(self.method_name.to_sym, *args)
        end
        self.method_klass.send(self.after_klass_method.to_sym) if self.after_klass_method
        if self.after_instance_method
          if self.send_batch
            record.each do |rec|
              rec.send(self.after_instance_method.to_sym)
            end
          else
            record.send(self.after_instance_method.to_sym)
          end
        end
        print result if self.verbose > 0 && result.is_a?(String)
      end
    end

    def run_around(mname = nil, &block)
      return false unless block_given?
      self.start_time = Time.now
      return false if mname.nil?
      puts 'There are no batches to run' and return false unless self.num_runs > 0
      self.method_name = mname.is_a?(Symbol) ? mname : mname.to_s.to_sym
      self.offset_array.each_with_index do |offset, current_batch|
        if self.backwards && self.is_first_run?(current_batch)
          limite = self.size_of_last_run
        else
          limite = self.batch_size
        end

        if self.first_batch > current_batch
          puts "[O] #{show_status(current_batch, limite)} skipped" if self.verbose > 1
          self.skipped_batches << current_batch
        elsif self.last_batch && self.last_batch < current_batch
          puts "[L] #{show_status(current_batch, limite)} skipped" if self.verbose > 1
          self.skipped_batches << current_batch
        else
          #start the timer
          beg_time = Time.now
          puts "[P] #{show_status(current_batch, limite)}" if self.verbose > 1

          if self.send_batch
            recs = self.do_query(current_batch, offset, limite)
            len = recs.length
            self.rescuer(current_batch, limite) do
              yield recs
            end
          else
            len = self.do_query(current_batch, offset, limite).each_with_index do |x, index|
              self.rescuer(current_batch, limite, index) do
                yield x
              end
            end.length
          end

          #stop the timer
          fin_time = Time.now

          this_time = fin_time.to_i - beg_time.to_i
          self.total_time += this_time unless extra_run && current_batch == self.num_runs
          puts "[C] #{show_status(current_batch, len)} in #{this_time} seconds" if self.verbose
          self.completion_times << [current_batch, {:elapsed => this_time, :begin_time => beg_time, :end_time => fin_time}]
        end
      end
      self.num_runs -= 1 if self.extra_run
      self.end_time = Time.now
      self.elapsed_time = (self.end_time.to_i - self.start_time.to_i)
      self.overhead_time = self.elapsed_time - self.total_time
    end

    def show_status(current_batch, limite)
      "{#{current_batch} / #{self.last_batch} / #{limite}}"
    end

    def do_query(current_batch, offset, limite)
      self.rescuer(current_batch, limite, 'ActiveRecord Query') do
        self.klass.find(:all, :offset => offset, :select => self.select, :limit => limite, :include => self.include, :conditions => self.conditions, :order => self.order)
      end
    end

    def rescuer(current_batch, limite, position = nil, &block)
      if self.error_notification || self.skip_errors
        begin
          yield
        rescue
          error = $!
          subject = "[F] {#{current_batch} / #{self.last_batch} / #{limite}#{position.nil? ? '' : ' / ' + position.to_s}} #{error}"
          puts subject
          Rails.logger.error subject
          Rails.logger.error error.backtrace
          self.notify(subject, error.backtrace) if self.notify_on_errors?
        end
      else
        yield
      end
    end

    def notify_on_errors?
      !self.error_notification.blank?
    end

    def notify(subject, error)
      Kernel.const_get(self.error_notification[:mailer]).send(self.error_notification[:delivery_method],
                                                              self.error_notification[:recipients],
                                                              self.error_notification[:subject_prefix] + subject,
                                                              error)
    end

    def print_results(verbose = false)
      printf "Average time per complete batch was %.1f seconds\n", (self.total_time/Float(self.num_runs)) unless self.num_runs < 1
      printf "Total time elapsed was %.1f seconds (about #{pluralize(self.elapsed_time/60, 'minute')})\n", (self.elapsed_time)
      printf "Total time spent inside batched method (#{self.klass}##{self.method_name}) was %.1f seconds (about #{pluralize(self.total_time/60, 'minute')})\n", (self.total_time)
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

# Copyright ©2008-2015 Peter H. Boling, released under the MIT license

