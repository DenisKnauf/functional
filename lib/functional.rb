
class ::Regexp
	class NegRegexp
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

	def -@
		NegRegexp.new self
	end
end

class ::Object
	def functional meth = nil
		Functional.new self, meth
	end
	alias to_fun functional
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

		def to_proc
			method( :call).to_proc
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

	class Map <Collect
		def call *a
			@exe.call *a, &@next
		end
	end

	class Flatten <Base
		def call a
			Array === a ? a.each( &method( :call)) : @next.call( a)
		end
	end

	class Reduce <Base
		def initialize iv, *a, &e
			super *a, &e
			@buf = {}
			@buf.default = iv
		end

		def call *a
			@buf[ a[0]] = @exe.call @buf[ a[0]], *a[1..-1]
		end

		def end
			@buf.each {|i| @next.call *i}
			@next.end
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

	def map &exe
		push Map.new( &exe)
	end

	def reduce iv, &exe
		push Reduce.new( iv, &exe)
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

	def flatten
		push Flatten.new
	end

	def each &exe
		return self  unless exe
		push Each.new
		push exe
		run
	end

	def join deli
		push Inject.new('') {|i,j|i+deli+j}
		run
	end

	def run
		@obj.send @func||:each, *@args, &@next #.method(:call)
		@next.end
	end

	def p
		each {|*a|Kernel.p a}
	end
end

begin
	require 'tokyocabinet'

	class Functional
		class Map <Base
			class Emit < TokyoCabinet::BDB
				alias emit putdup
				alias call emit
			end

			def call *a
				@exe.call( *a).each &@next
			end
		end

		def map name, &e
			push Map.new( name, &e)
		end

		def Reduce name, &e
			push Reduce.new( name, &e)
		end
	end

rescue MissingSourceFile
	# TokyoCabinet not installed?
end  if false
