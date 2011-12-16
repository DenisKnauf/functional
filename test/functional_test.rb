require 'test/unit'
require 'functional'

class FunTest < Test::Unit::TestCase
	M = 0..100

	def doit_fun m, &exe
		f = m.to_fun
		yield f
		f.to_a
	end

	def test_to_fun_exists
		assert_respond_to Object, :to_fun
	end

	def test_to_a
		assert_equal M.to_a, doit_fun( M) {|x| x }
	end

	def test_collect
		l = lambda {|x| x*2}
		assert_equal M.collect( &l), doit_fun( M) {|x| x.collect( &l) }
	end

	def test_inject
		assert_equal M.inject( 0) {|i,j| i+j }, M.to_fun.inject( 0) {|i,j| i+j }
	end
end
