
class Functional
	include Enumerable

	def self.method_missing meth, *args, &exe
		self.new.send meth, *args, &exe
	end

	def push_method code, *args, &exe
		name = "__meth_#{exe.object_id}"
		define_singleton_method name, &exe
		@stack.push code % name
		self
	end

	def initialize obj = nil, func = nil, *args
		@stack, @obj, @func, @args = [], obj, func, args
	end

	def collect &exe
		push_method "value=%s(value)", &exe
	end

	# map/reduce?
	def map &exe
		raise "Reserved for MapReduce."
	end

	# map/reduce?
	def reduce &exe
		raise "Reserved for MapReduce."
	end

	def select &exe
		push_method "%s(value)||next", &exe
	end

	def delete_if &exe
		push_method "%s(value)&&next", &exe
	end

	def each &exe
		return self  unless exe
		@obj.send @func||:each, *@args, &eval( "lambda{|value|#{@stack.join ";"};exe.call(value)}")
	end
end
