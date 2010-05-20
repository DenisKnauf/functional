
class NotRegexp
	def initialize r
		@rx = r
	end
	def match l
		! @rx.match( l)
	end
	def =~ l
		! @rx =~ l
	end
	def -@
		@rx
	end
end

class Regexp
	def -@
		NotRegexp.new self
	end
end

class Functional
	include Enumerable

	class Base
		attr_reader :exe
		attr_accessor :next
		def initialize &e
			@exe = e
		end

		def call *a
			@next.call *a
		end

		def end
			@next.end
		end
	end

	class Collect <Base
		def call *a
			@next.call *@exe.call( *a)
		end
	end

	class Select <Base
		def call *a
			@next.call *a  if @exe.call *a
		end
	end

	class DeleteIf <Base
		def call *a
			@next.call *a  unless @exe.call *a
		end
	end

	class Compact <Base
		def call *a
			@next.call *a  unless a.empty? || [nil] == a
		end
	end

	class BottomUp <Base
		def initialize start, *a, &e
			@next.call *a, &e
			@buffer, @start = nil, start
		end

		def call a
			if @exe.call a
				@next.call @buffer+a
				@buffer = @start.dup
			else
				@buffer += a
			end
		end

		def end
			@next.call @buffer
			@next.end
		end
	end

	class TopDown <Base
		def initialize start, *a, &e
			@next.call *a, &e
			@buffer, @start = nil, start
		end

		def call a
			if @exe.call a
				@next.call @buffer
				@buffer = @start.dup+a
			else
				@buffer += a
			end
		end

		def end
			@next.call @buffer
			@next.end
		end
	end

	class Each <Base
		def end
			nil
		end
	end

	class P <Each
		def initialize *a
			super *a, &Kernel.method( :p)
		end
	end

	class Inject <Base
		attr_reader :it
		def initialize start, *a, &e
			super *a, &e
			@it = start
		end
		def call *a
			@it = @exe.call @it, *a
		end
		def end
			@it
		end
	end

	class To_a <Inject
		def initialize *a, &e
			super [], *a, &e
		end
	end

	attr_accessor :next, :stack, :obj, :func, :args

	def initialize obj = nil, func = nil, *args
		@next, @stack, @obj, @func, @args = self, self, obj, func, args
	end

	def push a
		@stack = @stack.next = a
		self
	end

	def collect &exe
		push Collect.new( &exe)
	end

	# map/reduce?
	def map &exe
		push Map.new( &exe)
	end

	# map/reduce?
	def reduce &exe
		raise "Reserved for MapReduce."
	end

	def select &exe
		push Select.new( &exe)
	end

	def grep re
		push Select.new( &re.method( :match))
	end

	def delete_if &exe
		push DeleteIf.new( &exe)
	end

	def compact
		push Compact.new
	end

	def updown init, &exe
		push UpDown.new( init, &exe)
	end

	def topdown init, &exe
		push TopDown.new( init, &exe)
	end

	def each &exe
		push Each.new
		push exe
		run
	end

	def run
		@obj.send @func||:each, *@args, &@next.method(:call)
		@next.end
	end

	def p
		each &Kernel.method( :p)
	end
end
