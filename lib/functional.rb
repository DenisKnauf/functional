
class Functional
	include Enumerable

	def self.method_missing meth, *args, &exe
		self.new.send meth, *args, &exe
	end

	def push_method meth, *args, &exe
		@stack.push [meth, exe]+args
		self
	end

	def initialize obj = nil, func = nil, *args
		@stack, @obj, @func, @args = [], obj, func, args
	end

	def collect &exe
		push_method :collect, &exe
	end

	# map/reduce?
	def map &exe
		push_method :map, &exe
	end

	# map/reduce?
	def reduce &exe
		raise "Reserved for MapReduce."
	end

	def select &exe
		push_method :select, &exe
	end

	def delete_if &exe
		push_method :delete_if, &exe
	end

	def compact
		push_method :compact
	end

	def together init, &exe
		push_method :together, init, &exe
	end

	def each &exe
		return self  unless exe
		callstack = exe
		@stack.reverse.each do |a|
			m, e = *a[0..1]
			pre = callstack
			callstack = case m
				when :collect   then lambda {|val| pre.call e.call( val) }
				when :select    then lambda {|val| pre.call val  if e.call val }
				when :delete_if then lambda {|val| pre.call val  unless e.call val }
				when :compact   then lambda {|val| pre.call val  if val }
				when :map       then lambda {|val| e.call( val).each &pre }
				when :reduce
					buf = {}
					lambda {|val| buf[ val.first] = e.call( *val) }
				when :together
					buf = a[2].dup
					lambda {|val| if e.call val then pre.call buf; buf = a[2].dup+val else buf += val end }
				else
					$stderr.puts "Whats that? #{m.inspect}"
					callstack
				end
		end
		@obj.send @func||:each, *@args, &callstack
	end

	def p
		each &Kernel.method( :p)
	end
end
