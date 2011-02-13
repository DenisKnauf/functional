
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
	def to_fun meth = nil
		Functional.new self, meth
	end
end

class Counter
	include Enumerable
	attr_reader :c

	def initialize first = nil, step = nil
		@c, @step = first || 0, step || 1
	end

	def next; @c += @step end
	def to_i; c.to_i end 
	def to_f; c.to_f end

	def + i
		@c += @step*i
	end

	def each &e
		loop { e.call self; self.next }
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

		def clean
			@next.clean
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

	class Tap <Base
		def call *a
			@exe.call *a
			@next.call *a
		end
	end

	class Select <Base
		def call *a
			@next.call *a  if @exe.call *a
		end
	end

	class Filter <Base
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
		alias :clean :end
	end

	class P <Each
		def initialize *a
			super *a, &Kernel.method( :p)
		end
	end

	class Inject <Base
		attr_reader :it
		alias :end :it

		def initialize start, *a, &e
			super *a, &e
			@it = start
		end

		def call *a
			@it = @exe.call @it, *a
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
		def call *a
			a.each &@next.method( :call)
		end
	end

	class Inject <Base
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

	class Slice <Base
		def initialize n
			@buf, @n = [], n
		end

		def call *a
			@buf.push a
			unless @n > @buf.size
				@next.call @buf
				@buf.clear
			end
		end

		def end
			@next.call @buf
			@next.end
		end
	end

	class Cons <Base
		def initialize n
			@buf, @n = [], n
		end

		def call *a
			@buf.push a
		 	unless @n > @buf.size
				class <<self
					def call *a
						@buf.push a
						@next.call @buf
						@buf.shift
					end
				end
				@next.call @buf
				@buf.shift
			end
		end

		def end
			@next.call @buf  unless @n > @buf.size
			@next.end
		end
	end

	class Pager <Base
		def initialize *opts
			@pager = IO.popen ENV['PAGER'] || 'less', 'w'
			opts.each do |opt|
				case opt.to_s
				when *%w[inspect i] then alias call call_inspect
				else raise ArgumentError, "Unknown opt: #{opt}"
				end
			end
		end

		def call_inspect *a
			@pager.puts a.inspect
		end

		def call *a
			@pager.puts a
		end

		def clean
			@pager.close
		end

		def end
			clean
			nil
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

	def inject iv, &exe
		push Inject.new( iv, &exe)
	end
	alias reduce inject

	def select &exe
		push Select.new( &exe)
	end

	def grep re
		push Select.new( &re.method( :match))
	end

	def filter &exe
		push Filter.new( &exe)
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

	def flatten &exe
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
	rescue Object
		@next.clean
		raise $!
	end

	def p
		each &Kernel.method( :p)
	end

	def pager *opts
		push Pager.new( *opts)
		run
	end

	def sort &exe
		to_a.sort &exe
	end

	def sort_by &exe
		to_a.sort_by &exe
	end

	# [ _A, _B, ..., _C, ..., _D ] ==> [ [0, _A], [1, _B], ..., [_I, _C], ..., [_N, _D]]
	# [ [_A|_As], [_B|_Bs], ..., [_C|_Cs], ..., [_D|_Ds] ] ==> [ [0,_A|_As], [1,_B|_Bs], ..., [_I,_C|_Cs], ..., [_N,_D|_Ds] ]
	def with_index &exe
		i = 0
		exe ||= Array.method :[]
		push Collect.new {|*a| exe.call i, *a }
	end

	def slice n, &e
		push Slice.new( n)
		push Collect.new( &e)  if e
		self
	end

	def cons n, &e
		push Cons.new( n)
		push Collect.new( &e)  if e
		self
	end

	class Save < Base
		attr_reader :db

		def initialize db
			@db = db
		end

		def call k, *v
			@db[ k] = v.length == 1 ? v.first : v
		end
	end

	def save db
		push Save.new( db)
	end
end
