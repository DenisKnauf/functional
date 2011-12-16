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
	def self.__version__() '0.1.4' end
	include Enumerable

	class DEFAULT
	end

	class Base
		attr_reader :exe
		attr_accessor :next
		attr_reader :caller

		def initialize &e
			@caller = Kernel.caller.first
			@exe = e
		end

		def base_fun *a
			@next.call *a
		end
		alias call base_fun

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
		def collect_fun *a
			@next.call *@exe.call( *a)
		end
		alias call collect_fun
	end

	class Tap <Base
		def tap_fun *a
			@exe.call *a
			@next.call *a
		end
		alias call tap_fun
	end

	class Select <Base
		def select_fun *a
			@next.call *a  if @exe.call *a
		end
		alias call select_fun
	end

	class Filter <Base
		def filter_fun *a
			@next.call *a  unless @exe.call *a
		end
		alias call filter_fun
	end

	class Compact <Base
		def compact_fun *a
			@next.call *a  unless a.empty? || [nil] == a
		end
		alias call compact_fun
	end

	class BottomUp <Base
		def initialize start, *a, &e
			@next.call *a, &e
			@buffer, @start = nil, start
		end

		def bottom_up_fun a
			if @exe.call a
				@next.call @buffer+a
				@buffer = @start.dup
			else
				@buffer += a
			end
		end
		alias call bottom_up_fun

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

		def top_down_fun a
			if @exe.call a
				@next.call @buffer
				@buffer = @start.dup+a
			else
				@buffer += a
			end
		end
		alias call top_down_fun

		def end
			@next.call @buffer
			@next.end
		end
	end

	class Each <Base
		def each_fun *a
			@exe.call *a
		end
		alias call each_fun

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

		def inject_fun *a
			@it = @exe.call @it, *a
		end
		alias call inject_fun
	end

	class To_a <Inject
		def initialize *a, &e
			super [], *a, &e
		end
	end

	class Map <Collect
		def map_fun *a
			@exe.call *a, &@next
		end
		alias call map_fun
	end

	class Flatten <Base
		def flatten_fun *a
			a.each &@next.method( :call)
		end
		alias call flatten_fun
	end

	class Reduce <Base
		def initialize iv = ::Functional::DEFAULT, *a, &exe
			super *a, &exe
			iv = Array.method :new  if ::Functional::DEFAULT == iv
			@buf = if iv.kind_of?( ::Proc) || iv.kind_of?( ::Method)
					Hash.new {|h,k| h[k] = iv.call }
				else
					{}.tap {|h| h.default = iv }
				end
		end

		def reduce_fun k, *a
			@buf[ k] = @exe.call k, @buf[ k], *a
		end
		alias call reduce_fun

		def end
			@buf.each &@next.method( :call)
			@next.end
		end
	end

	class ToHash <Base
		def initialize
			super
			@buf = {}
		end

		def to_hash_fun k, *a
			@buf[k] = a
		end
		alias call to_hash_fun

		def end
			@buf
		end

		def clean
		end
	end

	class Slice <Base
		def initialize n
			@buf, @n = [], n
		end

		def slice_fun *a
			@buf.push a
			unless @n > @buf.size
				@next.call @buf
				@buf.clear
			end
		end
		alias call slice_fun

		def end
			@next.call @buf
			@next.end
		end
	end

	class Cons <Base
		def initialize n
			@buf, @n = [], n
		end

		def cons_fun *a
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
		alias call cons_fun

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

		def pager_fun *a
			@pager.puts a
		end
		alias call pager_fun

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

	def reduce iv = ::Functional::DEFAULT, &exe
		push Reduce.new( iv, &exe)
	end

	def select &exe
		push Select.new( &exe)
	end

	def grep re
		push Select.new( &re.method( :match))
	end

	def filter &exe
		push Filter.new( &exe)
	end
	alias reject filter

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
		push Each.new( &exe)
		run
	end

	def to_hash
		push ToHash.new
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
		push Collect.new {|*a| exe.call i, *a; i += 1 }
	end

	def slice n, &exe
		push Slice.new( n)
		block_given? ? self.collect( &exe) : self
	end

	def cons n, &exe
		push Cons.new( n)
		block_given? ? self.collect( &exe) : self
	end

	def tap &exe
		push Tap.new( &exe)
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
