require 'test/unit'
require 'functional'

class FunTest < Test::Unit::TestCase
	def test_to_fun_exists
		assert_respond_to Object, :to_fun
	end

	def test_to_fun_to_a
		assert_equal (0..100).to_a, (0..100).to_fun.to_a
	end

	
end
