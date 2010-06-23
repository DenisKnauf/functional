Install
=======

	gem install functional

Usage
=====

	require 'functional'
	
	# To demonstrate Functional, we create a Class with a infinite loop:
	class Sequence
		include Enumerable
		def initialize first = 0, step = 1
			@i, @step = first, step
		end
		def each
			# Our infinite loop:
			loop do
				yield @i
				@i += @step
			end
		end
  end
	
	Functional.new( Sequence.new).
		select {|i| i.even? }.
		collect {|i| i/3 }.
		select {|i| i.even?}.
		collect {|i| [[[[[[i.even?, i.odd?]]], i, [[[[[[i.class]]]]]]]]] }.
		flatten. # It flattens everything! Not like: collect {|i| i.flatten }.
		p
	
	# Without Functional... Bye bye.
	Sequence.new.
		select {|i| i.even? }.
		collect {|i| i/3 }.
		select {|i| i.even?}.
		collect {|i| [[[[[[i.even?, i.odd?]]], i, [[[[[[i.class]]]]]]]]] }.
		flatten. # It flattens everything! Not like: collect {|i| i.flatten }.
		p

It will never realize, that #p doesn't exists, because the first select runs endless.
Functional#p prints everything to stdout.

	(0..100000).to_fun.
		collect {|i| i*3 }.
		select {|i| i%5 == 2 }.
		to_a

What's with _#map_?
=================

Do you know MapReduce?  In future #map will be used for MapReduce.  Use #collect.
