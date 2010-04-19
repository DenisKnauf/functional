Install
=======

	gem install functional

Usage
=====

	require 'functional'
	
	obj = 0 .. 10**12
	Functional.new( obj).select {|i| i.even? }.collect {|i| i/3 }.select {|i| i.even? }.each &method( :puts)

What's with _#map_?
=================

Do you know MapReduce?  In future #map will be used for MapReduce.  Use #collect.
