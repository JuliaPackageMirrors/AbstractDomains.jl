ConcreteReal = Union(Float64,Int64)

immutable Interval <: Domain{Float64}
  l::Float64
  u::Float64
  Interval(l,u) =  if u > l new(l, u) else new(u,l) end
end

Interval(v::Vector) = Interval(v[1],v[2])
unitinterval() = Interval(0.,1.)

## Conversions
## ===========
function convert(::Type{HyperBox}, i::Vector{Interval})
  intervals = Array(Float64,2,length(i))
  for j in 1:length(i)
    intervals[:,j] = [i[j].l i[j].u]
  end
  HyperBox(intervals)
end
convert(::Type{Vector{Interval}}, b::HyperBox) = [Interval(b.intervals[:,i]) for i = 1:ndims(b)]

# A concrete number can be concerted to an interval with no width
convert(::Type{Interval}, c::ConcreteReal) = Interval(c, c)
promote_rule{T<:ConcreteReal}(::Type{T}, ::Type{Interval}) = Interval

## Print
## =====
string(x::Interval) = "[$(x.l) $(x.u)]"
print(io::IO, x::Interval) = print(io, string(x))
show(io::IO, x::Interval) = print(io, string(x))
showcompact(io::IO, x::Interval) = print(io, string(x))

## Set operations
## ==============
ndims(i::Interval) = 1
subsumes(x::Interval, y::Interval) = y.l >= x.l && y.u <= x.u
overlap(x::Interval, y::Interval) = y.l <= x.u && x.l <= y.u
domaineq(x::Interval, y::Interval) = x.u == y.u && x.l == y.l
isequal(x::Interval,y::Interval) = domaineq(x,y)

## Interval Arithmetic and Inequalities
## ====================================

# ==, != return values in AbstractBool
function ==(x::Interval, y::Interval)
  if x.u == y.u == x.l == y.l T
  elseif overlap(x,y) TF
  else F end
end

!=(x::Interval,y::Interval) = !(==(x,y))

==(x::Interval,y::ConcreteReal) = ==(promote(x,y)...)
==(y::ConcreteReal,x::Interval) = ==(promote(y,x)...)

!=(x::Interval, y::ConcreteReal) = !==(x,y)
!=(y::ConcreteReal, x::Interval) = !==(y,x)

>(x::Interval, y::Interval) = if x.l > y.u T elseif x.u <= y.l F else TF end
>(x::Interval, y::ConcreteReal) = if x.l > y T elseif x.u <= y F else TF end
>(y::ConcreteReal, x::Interval) =  if y > x.u T elseif y <= x.l F else TF end

<(x::Interval, y::Interval) = y > x
<(x::Interval, y::ConcreteReal) = y > x
<(y::ConcreteReal, x::Interval) = x > y

<=(x::Interval, y::Interval) = !(x > y)
>=(x::Interval, y::Interval) = !(x < y)
<=(x::Interval, y::ConcreteReal) = !(x > y)
<=(y::ConcreteReal, x::Interval) = !(y > x)

>=(x::Interval, y::ConcreteReal) = !(x < y)
>=(y::ConcreteReal, x::Interval) = !(x < y)
+(x::Interval, y::Interval) = Interval(x.l + y.l, x.u + y.u)
-(x::Interval, y::Interval) = Interval(x.l - y.u, x.u - y.l)
+(x::Interval, y::ConcreteReal) = Interval(x.l + y, x.u + y)
+(y::ConcreteReal, x::Interval) = x + y
-(x::Interval, y::ConcreteReal) = Interval(x.l - y, x.u - y)
-(y::ConcreteReal, x::Interval) = Interval(y - x.l, y - x.u)

*(x::Interval, y::ConcreteReal) = Interval(x.l * y, x.u * y)
*(y::ConcreteReal, x::Interval) = x * y

sqrt(x::Interval) = Interval(sqrt(x.l), sqrt(x.u))

# CODEREVIEW: Generalise to even powers
function sqr(x::Interval)
  a,b,c,d = x.l * x.l, x.l * x.u, x.u * x.l, x.u * x.u
  Interval(max(min(a,b,c,d),0),max(a,b,c,d,0))
end

function *(x::Interval, y::Interval)
  a,b,c,d = x.l * y.l, x.l * y.u, x.u * y.l, x.u * y.u
  Interval(min(a,b,c,d),max(a,b,c,d))
end

# is c inside the interval
# CODREVIEW: TESTME
in(c::ConcreteReal, y::Interval) = y.l <= c <= y.u

# CODREVIEW: TESTME
inv(x::Interval) = Interval(1/x.u,1/x.l)

# Ratz Interval Division
# CODREVIEW: TESTME
function /(x::Interval, y::Interval)
  a,b,c,d = x.l,x.u,y.l,y.u
  if !(0 ∈ y)
    x * inv(y)
  elseif (0 ∈ x)
    Interval(-Inf,Inf)
  elseif b < 0 && c < d == 0
    Interval(b/c,Inf)
  elseif b < 0 && c < 0 < d
    Interval(-Inf,Inf)
  elseif b < 0 && 0 == c < d
    Interval(-Inf,b/d)
  elseif 0 < a && c < d == 0
    Interval(-Inf,a/c)
  elseif 0 < a && c < 0 < d
    Interval(-Inf,Inf)
  elseif 0 < a && 0 == c < d
    Interval(a/d, Inf)
  else
    Inf
  end
end

/(c::ConcreteReal, x::Interval) = convert(Interval,c) / x
/(x::Interval, c::ConcreteReal) = x / convert(Interval,c)

## Functions on interval abstraction itself
## =======================================
reflect(x::Interval) = Interval(-x.l,-x.u)
makepos(x::Interval) = Interval(max(x.l,0), max(x.u,0))
mid(x::Interval) = (x.u - x.l) / 2 + x.l

## Non primitive functions
## =======================
function abs(x::Interval)
  if x.l >= 0.0 && x.u >= 0.0 x
  elseif x.u >= 0.0 Interval(0,max(abs(x.l), abs(x.u)))
  else makepos(reflect(x))
  end
end

round(x::Interval) = Interval(round(x.l), round(x.u))

function isinf(x::Interval)
  if isinf(x.l) || isinf(x.u)
    x.u == x.l ? T : TF
  else
    F
  end
end

function isapprox(x::Interval, y::Interval; epsilon::Real = 1E-5)
  ifelse(isinf(x) | isinf(y), x == y, abs(x - y) <= epsilon)
end

isapprox(x::Interval, y::Real) = isapprox(promote(x,y)...)
isapprox(x::Real, y::Interval) = isapprox(promote(x,y)...)

## Merging
## =======
function ⊔(a::Interval, b::Interval)
  l = min(a.l,b.l)
  u = max(a.u, b.u)
  Interval(l,u)
end

⊔(a::Interval, b::ConcreteReal) = ⊔(promote(a,b)...)
⊔(b::ConcreteReal, a::Interval) = ⊔(promote(b,a)...)
⊔(a::Interval) = a
⊔(a::Vector{Interval}) = reduce(⊔,a)

## Vector Interop
## ==============
l{T<:Real}(v::Vector{T}) = v[1]
u{T<:Real}(v::Vector{T}) = v[2]
l(x::Interval) = x.l
u(x::Interval) = x.u
pair(T::Type{Interval},low,up) = Interval(low,up)
pair(T::Type{Vector{Float64}},low,up) = [low,up]
Pair = Union(Vector{Float64},Interval)

## Splitting
## =========
function split_box{P<:Pair}(i::P, split_point::Float64)
  @assert l(i) <= split_point <= u(i) "Split point must be within interval"
  # @assert l(i) != u(i) "Can't split a single point interval into disjoint sets"

  if l(i) == u(i)  #Degenrate case
    P[pair(P, l(i), u(i)), pair(P, l(i), u(i))]
  elseif split_point < u(i)
    P[pair(P, l(i), split_point), pair(P, nextfloat(split_point), u(i))]
  else
    P[pair(P, l(i), prevfloat(split_point)), pair(P, split_point, u(i))]
  end
end

mid_split(i::Interval) = split_box(i,mid(i))

# Split along the middle n times
function mid_split(i::Interval, n::Int64)
  A = [i]
  for i = 1:n
    res = Interval[]
    for a in A
      splitted = mid_split(a)
      push!(res,splitted[1],splitted[2])
    end
    A = res
  end
  A
end