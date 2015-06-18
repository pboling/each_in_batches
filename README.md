# EachInBatches (Originally EachInBatches)

### NOTE:
I am resurrecting this code because I still have this recurring need, and Rail's native batching doesn't cut mustard.  
It is some of my most ancient code, and it isn't pretty, but I hope to improve it over time.

I often need to execute really large computations on really large data sets.
I usually end up writing a rake task to do it, which calls methods in my models.
But something about the process bugged me.  Each time I had to re-implement my
'batching code' that allowed me to not chew up GB after GB of memory due to
klass.find(:all, :include => [:everything_under_the_sun]). Re-implementation of
the same logic over and over across many projects is not very DRY, so I got out
my blow torch and lit it up.  The difficulty was that the part that was different
each time I batched was at the center of the code, right in the middle of the
batch loop.  But I didn't let that stop me!

## Why this plugin is way better than standard Rails batching
1. I've been doing batching in Rails a lot longer than Rails has.
2. Metrics.  I measure stuff.
3. I can batch from the top down (a.k.a backwards), making it possible to DELETE things in batches.
		A. If you've never tried using the built-in rails batching for deleting millions of records... don't start now.  Use this gem instead.
4. Exception Handling.  Exceptions occurring within the batching can be rescued, in a customizable fashion, which means that the process doesn't need to die on batch 309,675 of 402,540.
5. Merged in the EachInBatches fork (from Brian Kidd):
    I needed to iterate over the results and perform more actions than a single
    method would provide.  I didn't want to write a method in my app that performed
    the needed functionality as I felt the plugin should support this directly.
    I modified the original plugin so that it takes a block instead of a method.
    It will pass the object instance to the block.  It works pretty much the same
    as Class.find(:all).each {|x| do something}, except in batches n that you
    specify with :batch_size.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'each_in_batches'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install each_in_batches

## Usage

To create a new Batch, call `Batch#new` pass it the class and any additional arguments (all as a hash).

    batch = EachInBatches::Batch.new(:arel => Payment.canceled.order("transaction_id ASC"), :batch_size => 50)

To process the batched data, pass a block to `Batch#run` the same way you would to an object in a block like `Klass.all.each {|x| x.do_something }`.
`Batch#run` will pass the data to your block, one at a time, in batches set by the :batch_size argument.

    batch.run {|x| puts x.id; puts x.transaction_id}

Print the results!

    batch.print_results

Or...

Consolidate your code if you prefer

    EachInBatches::Batch.new(:arel => Payment.canceled.order("transaction_id ASC"), batch_size => 50, :show_results => true).run{|x| puts x.id; puts x.transaction_id}

## Configuration

Arguements for the initializer (Batch.new) method are:

    Required:

      :arel          - Usage: :arel => Payment.canceled.order("transaction_id ASC")
                        Required, as this is the class that will be batched

    Optional:

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

## Output

Interpreting the output:

    '[O]' means the batch was skipped due to an offset.
    '[L]' means the batch was skipped due to a limit.
    '[P]' means the batch is processing.
    '[C]' means the batch is complete.
    and yes... it was a coincidence.  This class is not affiliated with 'one laptop per child'

## License

Copyright ©2008-2015 Peter H. Boling, Brian Kidd, released under the MIT license

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Maintenance

To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Versioning

This library aims to adhere to [Semantic Versioning 2.0.0](http://semver.org/).
Violations of this scheme should be reported as bugs. Specifically,
if a minor or patch version is released that breaks backward
compatibility, a new version should be immediately released that
restores compatibility. Breaking changes to the public API will
only be introduced with new major versions.

As a result of this policy, you can (and should) specify a
dependency on this gem using the [Pessimistic Version Constraint](http://docs.rubygems.org/read/chapter/16#page74) with two digits of precision.

For example:

    spec.add_dependency 'each_in_batches', '~> 0.0'

## Contributing

1. Fork it ( https://github.com/[my-github-username]/each_in_batches/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Make sure to add tests!
6. Create a new Pull Request

## Contributors

See the [Network View](https://github.com/pboling/each_in_batches/network)
