module WCSLIB

export pscard,
       pvcard,
       wcsprm

export wcsbchk,
       #wcsbdx,
       wcsbth,
       wcserr_enable,
       wcserr_prt,
       wcsfree,
       wcshdo,
       #wcsidx,
       wcsini,
       #wcsmix,
       wcsmodify,
       wcsnps,
       wcsnpv,
       wcsp2s,
       wcsperr,
       wcspih,
       wcsprt,
       wcss2p,
       wcsset,
       #wcssptr,
       #wcssub,
       wcstab

using BinDeps
@BinDeps.load_dependencies

include("libwcs_common.jl")
include("libwcs_h.jl")

function unsafe_store_vec!{T}(p::Ptr{T}, v::Vector{T})
    for i = 1:length(v)
        unsafe_store!(p, v[i], i)
    end
end

function Base.convert(::Type{Array_72_Uint8}, s::ASCIIString)
    @assert length(s) < 72
    v = zeros(Uint8, 72)
    for i = 1:length(s)
        v[i] = s[i]
    end
    Array_72_Uint8(v...)
end

function wcsmodify(w::wcsprm; kvs...)
    @assert w.flag != -1
    w.flag = 0
    naxis = w.naxis
    for (k,v) in kvs

        # double[naxis]
        if k in (:cdelt,:crder,:crota,:crpix,:crval,:csyer)
            @assert isa(v, Vector{Float64})
            @assert length(v) == naxis
            unsafe_store_vec!(w.(k), v)

        # char[72,naxis]
        elseif k in (:cname,:ctype,:cunit)
            @assert isa(v, Vector{ASCIIString})
            @assert length(v) == naxis
            p = convert(Ptr{Array_72_Uint8}, w.(k))
            x = [convert(Array_72_Uint8,s) for s in v]
            unsafe_store_vec!(p, x)

        # pvcard[]
        elseif k === :pv
            npv = length(v)
            @assert isa(v, Vector{pvcard})
            @assert npv <= w.npvmax
            unsafe_store_vec!(w.pv, v)
            w.npv = npv

        # pscard[]
        elseif k === :ps
            nps = length(v)
            @assert isa(v, Vector{pscard})
            @assert nps <= w.npsmax
            unsafe_store_vec!(w.ps, v)
            w.nps = nps

        # double[naxis,naxis]
        elseif k in (:cd,:pc)
            @assert isa(v, Matrix{Float64})
            @assert size(v) == (naxis,naxis)
            unsafe_store_vec!(w.(k), vec(v'))

        # double
        elseif k in (:equinox,:latpole,:lonpole,:mjdavg,:mjdobs,
                     :restfrq,:restwav,:velangl,:velosys,:zsource)
            w.(k) = convert(Float64, v)

        # int
        elseif k in (:colnum,)
            w.(k) = convert(Cint, v)

        # char[72]
        elseif k in (:dateavg,:dateobs,:radesys,:specsys,:ssysobs,:ssyssrc,
                     :wcsname)
            w.(k) = convert(Array_72_Uint8, v)

        # double[3]
        elseif k in (:obsgeo,)
            @assert isa(v, Vector{Float64}) && length(v) == 3
            w.obsgeo = Array_3_Cdouble(v[1], v[2], v[3])

        # char[4], but only uses first
        elseif k in (:alt,)
            @assert isa(v, Char)
            @assert ('A' <= v <= 'Z') || v == ' '
            x = 0x0
            w.alt = Array_4_Uint8(uint8(v), x, x, x)

        else
            error("unrecognized keyword argument \"$k\"")
        end
    end
end

function wcsprm(naxis::Integer; kvs...)
    w = wcsprm()
    stat = wcsini(1, naxis, w)
    @assert stat == 0
    finalizer(w, wcsfree)
    wcsmodify(w; kvs...)
    w
end

macro same_size(a, b)
    :(size($(esc(a))) == size($(esc(b))) || error($(string(a))," must have the same dimensions as ",$(string(b))))
end

function wcsp2s(wcs::wcsprm, pixcrd::Matrix{Float64};
                imgcrd::Matrix{Float64}=similar(pixcrd),
                phi::Matrix{Float64}=similar(pixcrd),
                theta::Matrix{Float64}=similar(pixcrd),
                world::Matrix{Float64}=similar(pixcrd),
                stat::Matrix{Cint}=similar(pixcrd,Cint))
    @same_size imgcrd pixcrd
    @same_size phi pixcrd
    @same_size theta pixcrd
    @same_size world pixcrd
    @same_size stat pixcrd
    (nelem, ncoord) = size(pixcrd)
    nelem >= wcs.naxis || error("number of rows must be greater than or equal to naxis")
    wcsp2s(wcs, ncoord, nelem, pointer(pixcrd), pointer(imgcrd),
           pointer(phi), pointer(theta), pointer(world), pointer(stat))
    world
end

function wcss2p(wcs::wcsprm, world::Matrix{Float64};
                phi::Matrix{Float64}=similar(world),
                theta::Matrix{Float64}=similar(world),
                imgcrd::Matrix{Float64}=similar(world),
                pixcrd::Matrix{Float64}=similar(world),
                stat::Matrix{Cint}=similar(world,Cint))
    @same_size phi world
    @same_size theta world
    @same_size imgcrd world
    @same_size pixcrd world
    @same_size stat world
    (nelem, ncoord) = size(world)
    nelem >= wcs.naxis || error("number of rows must be greater than or equal to naxis")
    wcss2p(wcs, ncoord, nelem, pointer(world), pointer(phi), pointer(theta),
           pointer(imgcrd), pointer(pixcrd), pointer(stat))
    pixcrd
end

function wcspih(header::ASCIIString; nkeyrec::Integer=div(length(header),80),
                                     relax::Integer=0, ctrl::Integer=0)
    @assert ctrl >= 0 # < 0 modifies the header
    nreject = Cint[0]
    nwcs = Cint[0]
    wcs = Ptr{wcsprm}[0]
    stat = wcspih(pointer(header), nkeyrec, relax, ctrl,
                  pointer(nreject), pointer(nwcs), pointer(wcs))
    @assert stat == 0
    p = wcs[1]
    a = wcsprm[unsafe_load(p,i) for i = 1:nwcs[1]]
    c_free(p)
    (a, int(nreject[1]))
end

function wcsbth(header::ASCIIString; nkeyrec::Integer=div(length(header),80),
                                     relax::Integer=0, ctrl::Integer=0,
                                     keysel::Integer=0)
    @assert ctrl >= 0 # < 0 modifies the header
    nreject = Cint[0]
    nwcs = Cint[0]
    wcs = Ptr{wcsprm}[0]
    stat = wcsbth(pointer(header), nkeyrec, relax, ctrl, keysel, C_NULL,
                  pointer(nreject), pointer(nwcs), pointer(wcs))
    @assert stat == 0
    p = wcs[1]
    a = wcsprm[unsafe_load(p,i) for i = 1:nwcs[1]]
    c_free(p)
    (a, int(nreject[1]))
end

function wcshdo(w::wcsprm; relax::Integer=0)
    nkeyrec = Cint[0]
    header = Ptr{Uint8}[0]
    stat = wcshdo(relax, w, pointer(nkeyrec), pointer(header))
    @assert stat == 0
    p = header[1]
    s = bytestring(p)
    c_free(p)
    s
end

end # module
