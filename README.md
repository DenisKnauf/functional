Install
=======

	gem install functional

Usage
=====

	require 'functional'
	
	obj = 0 .. 10**12
	Functional.new( obj).select {|i| i.even? }.map {|i| i/3 }.select {|i| i.even? }.each &method( :puts)
